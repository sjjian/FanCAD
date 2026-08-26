import 'settings.dart';

/// Recent files and drafting toggles — the workspace's slice of settings.
class DrawingSettings {
  DrawingSettings(this._store);

  final SettingsStore _store;

  List<String> get recentFiles => _store.getStringList(SettingsKeys.recentFiles);

  void setRecentFiles(List<String> paths) =>
      _store.set(SettingsKeys.recentFiles, paths);

  void pushRecent(String path) =>
      _store.pushRecent(SettingsKeys.recentFiles, path);

  bool get showGrid =>
      _store.getBool(SettingsKeys.showGrid, fallback: true);

  void setShowGrid(bool value) => _store.set(SettingsKeys.showGrid, value);

  bool get snapEnabled =>
      _store.getBool(SettingsKeys.snapEnabled, fallback: true);

  void setSnapEnabled(bool value) =>
      _store.set(SettingsKeys.snapEnabled, value);

  List<String> get snapModes => _store.getStringList(SettingsKeys.snapModes);

  void setSnapModes(List<String> names) =>
      _store.set(SettingsKeys.snapModes, names);

  bool get ortho => _store.getBool(SettingsKeys.orthoMode);

  void setOrtho(bool value) => _store.set(SettingsKeys.orthoMode, value);

  bool get polar => _store.getBool(SettingsKeys.polarMode, fallback: true);

  void setPolar(bool value) => _store.set(SettingsKeys.polarMode, value);

  double polarIncrement({double fallback = 0.7853981633974483}) =>
      _store.getDouble(SettingsKeys.polarIncrement, fallback: fallback);

  void setPolarIncrement(double radians) =>
      _store.set(SettingsKeys.polarIncrement, radians);
}
