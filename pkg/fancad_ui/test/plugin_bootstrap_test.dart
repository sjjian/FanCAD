import 'dart:convert';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

JsEngineFactory capturingEngine(List<({String kind, String id})> events) =>
    ({required int memoryLimit, required int stackSize}) {
      final engine = ScriptedJsEngine();
      engine.globals[BootstrapGlobals.registered] = () =>
          jsonEncode({'commands': <String>[]});
      engine.globals[BootstrapGlobals.deactivate] = () =>
          jsonEncode({'result': null});
      engine.globals[BootstrapGlobals.dispatch] =
          (String kind, String id, String payload) async {
            events.add((kind: kind, id: id));
            return jsonEncode({'result': null});
          };
      return engine;
    };

Future<void> writePlugin(String root, String id, {bool startup = false}) async {
  final directory = Directory(p.join(root, id));
  await directory.create(recursive: true);
  await File(p.join(directory.path, PluginManifest.fileName)).writeAsString(
    jsonEncode({
      'id': id,
      'name': id,
      'version': '0.1.0',
      'main': 'main.js',
      if (startup) 'activationEvents': ['onStartup'],
    }),
  );
  await File(p.join(directory.path, 'main.js')).writeAsString('');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start is a no-op when this session has no extension host', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(SettingsStore.inMemory()),
        pluginsDirectoryProvider.overrideWithValue(''),
      ],
    );
    addTearDown(container.dispose);

    final bootstrap = container.read(pluginBootstrapProvider);
    await bootstrap.start();
    expect(bootstrap.isStarted, isFalse);
    expect(container.read(pluginHostProvider), isNull);
  });

  test(
    'start discovers bundled then user plugins once, and forwards document events',
    () async {
      final bundled = await Directory.systemTemp.createTemp('fancad-bundled-');
      final user = await Directory.systemTemp.createTemp('fancad-user-');
      addTearDown(() async {
        if (bundled.existsSync()) await bundled.delete(recursive: true);
        if (user.existsSync()) await user.delete(recursive: true);
      });

      await writePlugin(bundled.path, 'shipped.tools', startup: true);
      await writePlugin(user.path, 'user.tools');

      final events = <({String kind, String id})>[];
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          importerProvider.overrideWithValue(
            DrawingImporter(backend: MemoryDrawingBackend()),
          ),
          pluginsDirectoryProvider.overrideWithValue(user.path),
          bundledPluginDirectoriesProvider.overrideWithValue([bundled.path]),
          pluginTransportProvider.overrideWithValue(
            LocalTransport(engineFactory: capturingEngine(events)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final bootstrap = container.read(pluginBootstrapProvider);
      final host = container.read(pluginHostProvider)!;
      await bootstrap.start();
      expect(bootstrap.isStarted, isTrue);
      expect(host.plugin('shipped.tools')!.state, PluginState.active);
      expect(host.plugin('user.tools')!.state, PluginState.installed);

      await writePlugin(bundled.path, 'late.tools', startup: true);
      await bootstrap.start();
      expect(host.plugin('late.tools'), isNull);

      final workspace = container.read(workspaceProvider);
      workspace.newDocument();
      expect(
        events.where((event) => event.id == 'document.opened'),
        isNotEmpty,
      );

      final drawn = await workspace.runHeadless(
        'draw.line',
        args: {
          'start': [0, 0],
          'end': [1, 0],
        },
      );
      expect(drawn.status, CommandStatus.ok, reason: drawn.message);
      expect(
        events.where((event) => event.id == 'document.changed'),
        isNotEmpty,
      );

      workspace.newDocument();
      expect(
        events.where((event) => event.id == 'document.opened').length,
        greaterThanOrEqualTo(2),
      );
    },
  );
}
