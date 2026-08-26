import 'dart:convert';
import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

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
    root = await Directory.systemTemp.createTemp('fancad-plugins-rt-');
    workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    host = PluginHost(
      registry: workspace.commands,
      delegate: WorkspacePluginDelegate(
        workspace: () => workspace,
        plugins: PluginSettings(SettingsStore.inMemory()),
      ),
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
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => workspace.runHeadless(id, args: args);

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
