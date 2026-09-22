import 'package:fancad/fancad.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mcp settings default on, local, and can be turned off', () {
    final store = SettingsStore.inMemory();
    final settings = McpSettings(store);
    final loaded = settings.load();
    expect(loaded.bind.enabled, isTrue);
    expect(loaded.bind.local, isTrue);
    expect(loaded.bind.port, defaultMcpPort);
    expect(loaded.bind.allowlist, isEmpty);
    settings.save(
      loaded.copyWith(
        bind: loaded.bind.copyWith(
          enabled: false,
          local: false,
          port: 19000,
          allowlist: ['10.0.0.2'],
        ),
      ),
    );
    final saved = settings.load();
    expect(saved.bind.enabled, isFalse);
    expect(saved.bind.local, isFalse);
    expect(saved.bind.port, 19000);
    expect(saved.bind.allowlist, ['10.0.0.2']);
    expect(store.getBool(SettingsKeys.mcpEnabled), isFalse);

    final leftover = McpSettings(
      SettingsStore.inMemory({SettingsKeys.mcpAllowlist: '8.8.8.8 1.1.1.1'}),
    );
    expect(leftover.load().bind.allowlist, ['8.8.8.8', '1.1.1.1']);
  });
}
