import 'settings.dart';

/// Per-plugin key/value rows, namespaced inside the same settings file.
class PluginSettings {
  PluginSettings(this._store);

  final SettingsStore _store;

  Object? read(String pluginId, String key) =>
      _store.values[_storageKey(pluginId, key)];

  void write(String pluginId, String key, Object? value) =>
      _store.set(_storageKey(pluginId, key), value);

  String _storageKey(String pluginId, String key) =>
      'plugins.storage.$pluginId.$key';
}
