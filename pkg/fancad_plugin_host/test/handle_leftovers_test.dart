import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifest = PluginManifest(
    id: 'acme.safe',
    name: 'Safe',
    version: '1.2.0',
    entryPoint: 'main.js',
    commands: [CommandContribution(id: 'acme.safe.run', title: 'Run')],
  );

  test('toJson omits a missing error and lists contributed commands', () {
    final handle = PluginHandle(
      manifest: manifest,
      state: PluginState.installed,
    );
    expect(handle.isActive, isFalse);
    expect(handle.id, 'acme.safe');
    expect(handle.toJson(), {
      'id': 'acme.safe',
      'name': 'Safe',
      'version': '1.2.0',
      'state': 'installed',
      'commands': ['acme.safe.run'],
    });
  });

  test('a failed handle keeps the error on the wire and is not active', () {
    final handle = PluginHandle(
      manifest: manifest,
      state: PluginState.failed,
      error: 'entry point not found',
    );
    expect(handle.isActive, isFalse);
    expect(handle.toJson()['error'], 'entry point not found');
    expect(handle.toJson()['state'], 'failed');

    handle.state = PluginState.active;
    expect(handle.isActive, isTrue);
    expect(handle.toJson()['state'], 'active');
  });
}
