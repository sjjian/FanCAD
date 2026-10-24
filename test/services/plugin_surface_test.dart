import 'dart:convert';
import 'dart:io';

import 'package:fancad/commands/plugin/export.dart';
import 'package:fancad/commands/plugin/import.dart';
import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unknown runtime fails before the script runs', () async {
    final app = Headless();
    final host = PluginManager(
      registry: app.workspace.commands,
      delegate: AppPluginDelegate(
        workspace: () => app.workspace,
        plugins: PluginSettings(SettingsStore.inMemory()),
      ),
      transport: LocalTransport(),
    );
    addTearDown(host.dispose);
    await host.start();
    host.registerManifest(
      const PluginManifest(
        id: 'demo',
        name: 'demo',
        version: '0.0.0',
        entryPoint: 'main.js',
        runtime: 'lua',
      ),
    );
    host.setSource('demo', '1');
    expect(await host.activate('demo'), isFalse);
    expect(host.plugin('demo')!.error, contains('unknown runtime'));
  });

  test('a host version outside engines.fancad is not evaluated', () async {
    final app = Headless();
    final host = PluginManager(
      registry: app.workspace.commands,
      delegate: AppPluginDelegate(
        workspace: () => app.workspace,
        plugins: PluginSettings(SettingsStore.inMemory()),
      ),
      transport: LocalTransport(),
      hostVersion: '0.1.0',
    );
    addTearDown(host.dispose);
    await host.start();
    host.registerManifest(
      const PluginManifest(
        id: 'demo',
        name: 'demo',
        version: '0.0.0',
        entryPoint: 'main.js',
        hostConstraint: '^9.0.0',
      ),
    );
    host.setSource('demo', 'throw new Error("ran")');
    expect(await host.activate('demo'), isFalse);
    expect(host.plugin('demo')!.state, PluginState.failed);
    expect(host.plugin('demo')!.error, contains('9.0.0'));
  });

  test('file.read and network are not grantable permissions', () {
    expect(
      () => PluginManifest.parse('{"id":"a","permissions":["file.read"]}'),
      throwsA(isA<ManifestException>()),
    );
    expect(
      () => PluginManifest.parse('{"id":"a","permissions":["network"]}'),
      throwsA(isA<ManifestException>()),
    );
  });

  test('view trees keep stable ids and reject unknown nodes', () {
    final tree = parseViewTree({
      'type': 'column',
      'id': 'root',
      'children': [
        {'type': 'button', 'id': 'go', 'label': 'Go'},
      ],
    });
    expect(tree['id'], 'root');
    expect(
      parseViewTree({
        'type': 'preview',
        'id': 'picture',
        'shapes': [
          {
            'type': 'line',
            'start': [0, 0],
            'end': [1, 1],
          },
        ],
      })['type'],
      'preview',
    );
    expect(
      () => parseViewTree({'type': 'webview', 'id': 'x'}),
      throwsA(isA<ViewTreeException>()),
    );
    expect(
      parseViewTree({
        'type': 'viewer',
        'id': 'picture',
        'canvas': 'polar',
      })['type'],
      'viewer',
    );
    expect(
      () => parseViewTree({'type': 'viewer', 'id': 'picture'}),
      throwsA(isA<ViewTreeException>()),
    );
    expect(
      () => parseViewTree({
        'type': 'image',
        'id': 'pic',
        'asset': '../secret.png',
      }),
      throwsA(isA<ViewTreeException>()),
    );
    expect(
      () => parseViewTree({
        'type': 'button',
        'id': 'go',
        'children': [
          {'type': 'text', 'id': 'inner', 'text': 'no'},
        ],
      }),
      throwsA(isA<ViewTreeException>()),
    );
  });

  test('a stored view tree parses again', () {
    final tree = parseViewTree({
      'type': 'column',
      'id': 'root',
      'children': [
        {'type': 'button', 'id': 'go', 'label': '打开预览'},
        {'type': 'text', 'id': 'status', 'text': 'ready'},
        {'type': 'viewer', 'id': 'picture', 'canvas': 'polar', 'height': 240},
      ],
    });
    final again = parseViewTree(jsonDecode(jsonEncode(tree)));
    final children = again['children'] as List;
    expect(children, hasLength(3));
    expect((children[2] as Map)['type'], 'viewer');
  });

  test('when clauses only understand hasSelection and commandIdle', () {
    expect(
      contributionWhen(
        'hasSelection && commandIdle',
        hasSelection: true,
        commandIdle: true,
      ),
      isTrue,
    );
    expect(
      contributionWhen('!hasSelection', hasSelection: true, commandIdle: true),
      isFalse,
    );
    expect(
      contributionWhen('editorFocus', hasSelection: true, commandIdle: true),
      isFalse,
    );
  });

  test('sandbox.query evaluates in a disposable runtime', () async {
    final app = Headless();
    final delegate = AppPluginDelegate(
      workspace: () => app.workspace,
      plugins: PluginSettings(SettingsStore.inMemory()),
    );
    final scratch = ScratchSession(
      delegate: delegate,
      openTransport: () => LocalTransport(
        engineFactory: ({required int memoryLimit, required int stackSize}) {
          final engine = ScriptedJsEngine(
            onEvaluate: (source, name) => source.contains('1+1') ? 2 : null,
          );
          engine.globals[BootstrapGlobals.registered] = () => '{"commands":[]}';
          engine.globals[BootstrapGlobals.deactivate] = () => '{"result":null}';
          engine.globals[BootstrapGlobals.dispatch] =
              (String kind, String id, String payload) async =>
                  '{"result":null}';
          return engine;
        },
      ),
    );
    addTearDown(scratch.dispose);
    final result = await scratch.query('1+1');
    expect(result.status, CommandStatus.ok, reason: result.message);
    expect(result.data!['value'], 2);
  });

  test('import then export round-trips a plugin folder', () async {
    final root = tempDir(prefix: 'fancad-plugin-pack');
    final app = Headless();
    final host = PluginManager(
      registry: app.workspace.commands,
      delegate: AppPluginDelegate(
        workspace: () => app.workspace,
        plugins: PluginSettings(SettingsStore.inMemory()),
      ),
      transport: LocalTransport(),
    );
    addTearDown(host.dispose);
    await host.start();
    final source = Directory('${root.path}/src')..createSync();
    File('${source.path}/fancad.plugin.json').writeAsStringSync(
      '{"id":"acme.pack","name":"Pack","version":"0.1.0","main":"main.js"}',
    );
    File('${source.path}/main.js').writeAsStringSync('/* pack */');
    final commands = PluginCommands(manager: host, pluginsDirectory: root.path);
    final imported = await PluginsImportCommand(
      commands,
    ).run(_args(app.workspace, {'path': source.path}));
    expect(imported.status, CommandStatus.ok, reason: imported.message);
    expect(host.plugin('acme.pack')!.state, PluginState.installed);
    expect(
      File('${root.path}/acme.pack/main.js').readAsStringSync(),
      '/* pack */',
    );

    final exported = await PluginsExportCommand(commands).run(
      _args(app.workspace, {
        'id': 'acme.pack',
        'path': '${root.path}/acme.pack.fancadplugin',
      }),
    );
    expect(exported.status, CommandStatus.ok, reason: exported.message);
    expect(File('${root.path}/acme.pack.fancadplugin').existsSync(), isTrue);
  });
}

CommandContext _args(Workspace workspace, Map<String, Object?> args) {
  return CommandContext(
    session:
        workspace.active?.session ??
        DocumentSession(id: 't', document: CadDocument()),
    input: ArgsCommandInput(args: CommandArgs(args), params: const []),
    services: workspace,
    args: CommandArgs(args),
  );
}
