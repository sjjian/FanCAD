import 'dart:convert';
import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

JsEngineFactory scriptedEngine() =>
    ({required int memoryLimit, required int stackSize}) {
      final engine = ScriptedJsEngine(
        onEvaluate: (source, name) => source == '1+1' ? 2 : null,
      );
      engine.globals[BootstrapGlobals.registered] = () =>
          jsonEncode({'commands': <String>[]});
      engine.globals[BootstrapGlobals.deactivate] = () =>
          jsonEncode({'result': null});
      engine.globals[BootstrapGlobals.dispatch] =
          (String kind, String id, String payload) async =>
              jsonEncode({'result': null});
      return engine;
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Workspace workspace;
  late PluginHost host;

  setUp(() async {
    root = tempDir(prefix: 'fancad-plugins');
    workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    final delegate = WorkspacePluginDelegate(
      workspace: () => workspace,
      plugins: PluginSettings(SettingsStore.inMemory()),
    );
    host = PluginHost(
      registry: workspace.commands,
      delegate: delegate,
      transport: LocalTransport(engineFactory: scriptedEngine()),
    );
    await host.start();
    for (final descriptor in PluginCommands(
      host: host,
      pluginsDirectory: root.path,
    ).descriptors()) {
      workspace.commands.register(descriptor);
    }
    workspace.newDocument();
  });

  tearDown(() async {
    await host.dispose();
    workspace.dispose();
  });

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

  test('list and reload stay quiet when nothing is installed', () async {
    final listed = await run('plugins.list');
    expect(listed.status, CommandStatus.ok);
    expect(listed.data!['plugins'], isEmpty);

    final reloaded = await run('plugins.reload');
    expect(reloaded.status, CommandStatus.failed);
    expect(reloaded.message, contains('No extensions'));
  });

  test('unknown ids are refused instead of creating folders', () async {
    expect(
      (await run('plugins.reload', {'id': 'ghost'})).data!['failed'],
      containsPair('ghost', 'not installed'),
    );
    expect(
      (await run('plugins.enable', {'id': 'ghost'})).status,
      CommandStatus.failed,
    );
    expect(
      (await run('plugins.logs', {'id': 'ghost'})).message,
      contains('not installed'),
    );
  });

  test('scaffold refuses an empty or escaping id', () async {
    expect(
      (await run('plugins.scaffold', const {})).status,
      CommandStatus.cancelled,
    );
    expect(
      (await run('plugins.scaffold', {'id': '../escape'})).message,
      contains('letters'),
    );
    expect(Directory(p.join(root.path, '..', 'escape')).existsSync(), isFalse);
  });

  test(
    'write and read refuse a path that leaves the extension folder',
    () async {
      final created = await run('plugins.scaffold', {'id': 'acme.safe'});
      expect(created.status, CommandStatus.ok, reason: created.message);

      final write = await run('plugins.write', {
        'id': 'acme.safe',
        'path': '../outside.js',
        'content': 'stolen',
      });
      expect(write.status, CommandStatus.failed);
      expect(write.message, contains('outside'));

      final read = await run('plugins.read', {
        'id': 'acme.safe',
        'path': '/etc/passwd',
      });
      expect(read.status, CommandStatus.failed);
      expect(read.message, contains('outside'));
    },
  );

  test(
    'typings, edit, logs and a missing file stay inside the extension',
    () async {
      final created = await run('plugins.scaffold', {'id': 'acme.safe'});
      expect(created.status, CommandStatus.ok, reason: created.message);

      final types = await run('plugins.typings');
      expect(types.status, CommandStatus.ok);
      expect(File(p.join(root.path, 'fancad.d.ts')).existsSync(), isTrue);
      expect(types.data!['path'], p.join(root.path, 'fancad.d.ts'));

      final revealed = workspace.panelReveals.first;
      final edit = await run('plugins.edit', {'id': 'acme.safe'});
      expect(edit.status, CommandStatus.ok);
      expect(await revealed, 'editor');

      final logs = await run('plugins.logs', {'id': 'acme.safe'});
      expect(logs.status, CommandStatus.ok);
      expect(logs.data!['id'], 'acme.safe');
      expect(
        (await run('plugins.read', {
          'id': 'acme.safe',
          'path': 'missing.js',
        })).status,
        CommandStatus.failed,
      );
      expect(
        (await run('plugins.eval', {'id': 'ghost', 'source': '1'})).status,
        CommandStatus.failed,
      );
    },
  );

  test(
    'disable unloads a scaffolded extension until it is enabled again',
    () async {
      expect(
        (await run('plugins.scaffold', {'id': 'acme.safe'})).status,
        CommandStatus.ok,
      );
      expect(host.plugin('acme.safe')!.state, isNot(PluginState.disabled));

      final disabled = await run('plugins.disable', {'id': 'acme.safe'});
      expect(disabled.status, CommandStatus.ok);
      expect(disabled.data!['enabled'], isFalse);
      expect(host.plugin('acme.safe')!.state, PluginState.disabled);

      final enabled = await run('plugins.enable', {'id': 'acme.safe'});
      expect(enabled.status, CommandStatus.ok);
      expect(enabled.data!['enabled'], isTrue);
      expect(host.plugin('acme.safe')!.state, PluginState.installed);
    },
  );

  test('read and eval stay inside a live extension folder', () async {
    expect(
      (await run('plugins.scaffold', {'id': 'acme.safe'})).status,
      CommandStatus.ok,
    );

    final read = await run('plugins.read', {
      'id': 'acme.safe',
      'path': 'main.js',
    });
    expect(read.status, CommandStatus.ok, reason: read.message);
    expect(read.data!['content'], contains('fancad.commands.register'));

    final eval = await run('plugins.eval', {
      'id': 'acme.safe',
      'source': '1+1',
    });
    expect(eval.status, CommandStatus.ok, reason: eval.message);
    expect(eval.data!['value'], 2);
  });
}
