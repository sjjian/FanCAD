import 'package:fancad/fancad.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mcp settings default on, local, and can be turned off', () {
    final store = SettingsStore.inMemory();
    final settings = McpSettings(store);
    expect(settings.enabled, isTrue);
    expect(settings.local, isTrue);
    expect(settings.port, defaultMcpPort);
    expect(settings.allowlist, isEmpty);
    settings.setEnabled(false);
    settings.setLocal(false);
    settings.setPort(19000);
    settings.setAllowlist(['10.0.0.2']);
    expect(settings.enabled, isFalse);
    expect(settings.local, isFalse);
    expect(settings.port, 19000);
    expect(settings.allowlist, ['10.0.0.2']);
    expect(store.getBool(SettingsKeys.mcpEnabled), isFalse);

    final leftover = McpSettings(
      SettingsStore.inMemory({SettingsKeys.mcpAllowlist: '8.8.8.8 1.1.1.1'}),
    );
    expect(leftover.allowlist, ['8.8.8.8', '1.1.1.1']);
  });
}
