import 'settings.dart';

/// Left sidebar view, open state, and width in `settings.json`.
class SidebarSettings {
  SidebarSettings(this._store);

  final SettingsStore _store;

  String view({String fallback = 'layers'}) =>
      _store.getString(SettingsKeys.sidebarView, fallback: fallback);

  void setView(String value) => _store.set(SettingsKeys.sidebarView, value);

  bool isOpen({bool fallback = true}) =>
      _store.getBool(SettingsKeys.sidebarOpen, fallback: fallback);

  void setOpen(bool value) => _store.set(SettingsKeys.sidebarOpen, value);

  double width({double fallback = 0}) =>
      _store.getDouble(SettingsKeys.sidebarWidth, fallback: fallback);

  void setWidth(double value) => _store.set(SettingsKeys.sidebarWidth, value);
}
