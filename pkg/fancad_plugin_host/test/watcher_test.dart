import 'dart:convert';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class SilentDelegate implements PluginHostDelegate {
  @override
  DocumentSession? get session => null;

  @override
  Iterable<CommandDescriptor> get commands => const [];

  @override
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String pluginId,
  }) async => const CommandResult.failed('unused');

  @override
  void showMessage(String pluginId, String message, {bool isError = false}) {}

  @override
  void log(String pluginId, String level, String message) {}

  @override
  Future<Object?> prompt(String pluginId, Map<String, Object?> spec) async =>
      null;

  @override
  Future<Object?> readStorage(String pluginId, String key) async => null;

  @override
  Future<void> writeStorage(String pluginId, String key, Object? value) async {}
}

JsEngineFactory silentEngine() =>
    ({required int memoryLimit, required int stackSize}) {
      final engine = ScriptedJsEngine();
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
  late Directory root;
  late PluginHost host;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fancad-watch-');
    host = PluginHost(
      registry: CommandRegistry(),
      delegate: SilentDelegate(),
      transport: LocalTransport(engineFactory: silentEngine()),
    );
    await host.start();
  });

  tearDown(() async {
    await host.dispose();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> writePlugin(String id) async {
    final directory = Directory(p.join(root.path, id));
    await directory.create(recursive: true);
    await File(p.join(directory.path, PluginManifest.fileName)).writeAsString(
      jsonEncode({
        'id': id,
        'name': id,
        'contributes': {
          'commands': [
            {'id': '$id.run', 'title': 'Run'},
          ],
        },
      }),
    );
    await File(p.join(directory.path, 'main.js')).writeAsString('// nothing');
  }

  test('watching the same root twice does not double-subscribe', () async {
    final watcher = PluginWatcher(host: host);
    addTearDown(watcher.dispose);
    await watcher.watch(root.path);
    await watcher.watch(root.path);
    expect(watcher.isWatching, isTrue);
  });

  test(
    'a hidden folder or leftover cache file cannot trigger a reload',
    () async {
      await writePlugin('alpha');
      await host.discover(root.path);
      final watcher = PluginWatcher(
        host: host,
        debounce: const Duration(milliseconds: 20),
      );
      addTearDown(watcher.dispose);
      await watcher.watch(root.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      var reloads = 0;
      watcher.reloads.listen((_) => reloads++);

      await Directory(p.join(root.path, '.cache')).create();
      await File(
        p.join(root.path, '.cache', 'main.js'),
      ).writeAsString('// hide');
      await File(
        p.join(root.path, 'alpha', 'notes.txt'),
      ).writeAsString('scratch');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(reloads, 0);
    },
  );

  test('a .mjs change reloads the owning plugin', () async {
    await writePlugin('alpha');
    await host.discover(root.path);
    final watcher = PluginWatcher(
      host: host,
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(watcher.dispose);
    await watcher.watch(root.path);

    final reloaded = watcher.reloads.first;
    await File(
      p.join(root.path, 'alpha', 'extra.mjs'),
    ).writeAsString('export {}');
    await expectLater(
      reloaded.timeout(const Duration(seconds: 5)),
      completion('alpha'),
    );
  });
}
