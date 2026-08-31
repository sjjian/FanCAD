import 'package:fancad_ops/fancad_ops.dart';

import 'settings.dart';

/// Whether this process listens for an MCP stdio proxy.
///
/// The HTTP URL Cursor copies from settings uses [port] and [ensureToken].
class McpSettings {
  McpSettings(this._store);

  final SettingsStore _store;

  bool get enabled => _store.getBool(SettingsKeys.mcpEnabled, fallback: true);

  void setEnabled(bool value) => _store.set(SettingsKeys.mcpEnabled, value);

  int get port => _store.getInt(SettingsKeys.mcpPort, fallback: defaultMcpPort);

  void setPort(int value) => _store.set(SettingsKeys.mcpPort, value);

  /// Bind 127.0.0.1 only. Off means all interfaces, then [allowlist] applies.
  bool get local => _store.getBool(SettingsKeys.mcpLocal, fallback: true);

  void setLocal(bool value) => _store.set(SettingsKeys.mcpLocal, value);

  List<String> get allowlist {
    final raw = _store.values[SettingsKeys.mcpAllowlist];
    if (raw is String) return parseMcpAllowlist(raw);
    return parseMcpAllowlist(
      _store.getStringList(SettingsKeys.mcpAllowlist).join(','),
    );
  }

  void setAllowlist(List<String> value) =>
      _store.set(SettingsKeys.mcpAllowlist, value);

  String get token => _store.getString(SettingsKeys.mcpToken);

  void setToken(String value) => _store.set(SettingsKeys.mcpToken, value);

  String ensureToken() {
    final existing = token;
    if (existing.isNotEmpty) return existing;
    final next = randomMcpToken();
    setToken(next);
    return next;
  }
}
