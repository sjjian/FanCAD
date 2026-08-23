import 'dart:io';

import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an empty plugins folder does not spawn a host', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(SettingsStore.inMemory()),
        pluginsDirectoryProvider.overrideWithValue(''),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(pluginHostProvider), isNull);
    expect(container.read(pluginCommandsProvider), isNull);
  });

  test(
    'a plugins folder wires a host without starting the isolate transport',
    () async {
      final root = await Directory.systemTemp.createTemp('fancad-plugins-');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(SettingsStore.inMemory()),
          pluginsDirectoryProvider.overrideWithValue(root.path),
          pluginTransportProvider.overrideWithValue(LocalTransport()),
        ],
      );
      addTearDown(container.dispose);

      final host = container.read(pluginHostProvider);
      expect(host, isNotNull);
      expect(container.read(pluginCommandsProvider), isNotNull);
      expect(
        container.read(pluginCommandsProvider)!.pluginsDirectory,
        root.path,
      );
    },
  );
}
