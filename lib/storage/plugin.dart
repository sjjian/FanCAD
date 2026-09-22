import 'settings.dart';

/// Per-plugin key/value rows, namespaced inside the same settings file.
///
/// An extension defines its own values, so this is not a FanCAD model.
abstract interface class PluginStore {
  Object? read(String pluginId, String key);

  void write(String pluginId, String key, Object? value);

  void delete(String pluginId, String key);
}

class PluginSettings implements PluginStore {
  PluginSettings(this._store);

  final SettingsStore _store;

  @override
  Object? read(String pluginId, String key) =>
      _store.values[_storageKey(pluginId, key)];

  @override
  void write(String pluginId, String key, Object? value) =>
      _store.set(_storageKey(pluginId, key), value);

  @override
  void delete(String pluginId, String key) => write(pluginId, key, null);

  String _storageKey(String pluginId, String key) =>
      'plugins.storage.$pluginId.$key';
}
