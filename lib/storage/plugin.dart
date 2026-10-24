import 'settings.dart';

/// Which saved extensions the user switched off.
abstract interface class PluginStore {
  /// Extension names the user switched off. Survives a restart.
  Set<String> disabledScriptIds();

  void setScriptDisabled(String name, bool disabled);
}

class PluginSettings implements PluginStore {
  PluginSettings(this._store);

  final SettingsStore _store;

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

  static const String _scriptsDisabledKey = 'scripts.disabled';
}
