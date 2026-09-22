import 'settings.dart';

/// Theme and language in `settings.json`.
class AppearanceSettings {
  AppearanceSettings(this._store);

  final SettingsStore _store;

  String themeBrightness({String fallback = 'dark'}) =>
      _store.getString(SettingsKeys.themeBrightness, fallback: fallback);

  void setThemeBrightness(String value) =>
      _store.set(SettingsKeys.themeBrightness, value);

  String language({String fallback = ''}) =>
      _store.getString(SettingsKeys.language, fallback: fallback);

  void setLanguage(String value) => _store.set(SettingsKeys.language, value);
}
