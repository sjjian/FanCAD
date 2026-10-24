import 'settings.dart';

/// Which saved extensions the user switched off.
abstract interface class ExtensionStore {
  /// Extension names the user switched off. Survives a restart.
  Set<String> disabledIds();

  void setDisabled(String name, bool disabled);
}

class ExtensionSettings implements ExtensionStore {
  ExtensionSettings(this._store);

  final SettingsStore _store;

  @override
  Set<String> disabledIds() {
    final raw = _store.values[_disabledKey] ?? _store.values[_legacyKey];
    if (raw is! List) return {};
    return {
      for (final value in raw)
        if (value is String) value,
    };
  }

  @override
  void setDisabled(String name, bool disabled) {
    final next = disabledIds();
    if (disabled) {
      next.add(name);
    } else {
      next.remove(name);
    }
    _store.set(_disabledKey, next.toList()..sort());
    _store.set(_legacyKey, null);
  }

  static const String _disabledKey = 'extensions.disabled';

  /// Written before saved scripts were called extensions.
  static const String _legacyKey = 'scripts.disabled';
}
