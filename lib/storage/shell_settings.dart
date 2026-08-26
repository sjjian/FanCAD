import 'settings.dart';

/// Sidebar, assistant pane, command line and appearance.
///
/// These keys are shared by several shell controllers, but they are still one
/// view: layout chrome, not drawings or the assistant transcript.
class ShellSettings {
  ShellSettings(this._store);

  final SettingsStore _store;

  String sidebarView({String fallback = 'layers'}) =>
      _store.getString(SettingsKeys.sidebarView, fallback: fallback);

  void setSidebarView(String value) =>
      _store.set(SettingsKeys.sidebarView, value);

  bool sidebarOpen({bool fallback = true}) =>
      _store.getBool(SettingsKeys.sidebarOpen, fallback: fallback);

  void setSidebarOpen(bool value) =>
      _store.set(SettingsKeys.sidebarOpen, value);

  double sidebarWidth({double fallback = 0}) =>
      _store.getDouble(SettingsKeys.sidebarWidth, fallback: fallback);

  void setSidebarWidth(double value) =>
      _store.set(SettingsKeys.sidebarWidth, value);

  double commandPaneHeight({double fallback = 0}) =>
      _store.getDouble(SettingsKeys.commandPaneHeight, fallback: fallback);

  void setCommandPaneHeight(double value) =>
      _store.set(SettingsKeys.commandPaneHeight, value);

  bool assistantOpen({bool fallback = false}) =>
      _store.getBool(SettingsKeys.assistantOpen, fallback: fallback);

  void setAssistantOpen(bool value) =>
      _store.set(SettingsKeys.assistantOpen, value);

  double assistantWidth({double fallback = 0}) =>
      _store.getDouble(SettingsKeys.assistantWidth, fallback: fallback);

  void setAssistantWidth(double value) =>
      _store.set(SettingsKeys.assistantWidth, value);

  String themeBrightness({String fallback = 'dark'}) =>
      _store.getString(SettingsKeys.themeBrightness, fallback: fallback);

  void setThemeBrightness(String value) =>
      _store.set(SettingsKeys.themeBrightness, value);

  String language({String fallback = ''}) =>
      _store.getString(SettingsKeys.language, fallback: fallback);

  void setLanguage(String value) => _store.set(SettingsKeys.language, value);
}
