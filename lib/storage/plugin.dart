import 'settings.dart';

/// Per-plugin key/value rows, namespaced inside the same settings file.
///
/// An extension defines its own values, so this is not a FanCAD model.
abstract interface class PluginStore {
  Object? read(String pluginId, String key);

  void write(String pluginId, String key, Object? value);

  void delete(String pluginId, String key);

  /// Plugin ids the user switched off. Survives a restart.
  Set<String> disabledIds();

  void setDisabled(String pluginId, bool disabled);

  /// Script names the user switched off. Survives a restart.
  Set<String> disabledScriptIds();

  void setScriptDisabled(String name, bool disabled);
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

  @override
  Set<String> disabledIds() {
    final raw = _store.values[_disabledKey];
    if (raw is! List) return {};
    return {
      for (final value in raw)
        if (value is String) value,
    };
  }

  @override
  void setDisabled(String pluginId, bool disabled) {
    final next = disabledIds();
    if (disabled) {
      next.add(pluginId);
    } else {
      next.remove(pluginId);
    }
    _store.set(_disabledKey, next.toList()..sort());
  }

  @override
  Set<String> disabledScriptIds() {
    final raw = _store.values[_scriptsDisabledKey];
    if (raw is! List) return {};
    return {
      for (final value in raw)
        if (value is String) value,
    };
  }

  @override
  void setScriptDisabled(String name, bool disabled) {
    final next = disabledScriptIds();
    if (disabled) {
      next.add(name);
    } else {
      next.remove(name);
    }
    _store.set(_scriptsDisabledKey, next.toList()..sort());
  }

  String _storageKey(String pluginId, String key) =>
      'plugins.storage.$pluginId.$key';

  static const String _disabledKey = 'plugins.disabled';
  static const String _scriptsDisabledKey = 'scripts.disabled';
}
