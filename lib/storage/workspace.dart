import '../models/settings.dart';
import 'settings.dart';

/// Recent files and drafting toggles — the workspace's slice of settings.
abstract interface class WorkspaceStore {
  DrawingModel load();

  void save(DrawingModel value);
}

class WorkspaceSettings implements WorkspaceStore {
  WorkspaceSettings(this._store);

  final SettingsStore _store;

  @override
  DrawingModel load() {
    return DrawingModel(
      recentFiles: _store.getStringList(SettingsKeys.recentFiles),
      showGrid: _store.getBool(SettingsKeys.showGrid, fallback: true),
      snapEnabled: _store.getBool(SettingsKeys.snapEnabled, fallback: true),
      snapModes: _store.getStringList(SettingsKeys.snapModes),
      ortho: _store.getBool(SettingsKeys.orthoMode),
      polar: _store.getBool(SettingsKeys.polarMode, fallback: true),
      polarIncrement: _store.getDouble(
        SettingsKeys.polarIncrement,
        fallback: 0.7853981633974483,
      ),
    );
  }

  @override
  void save(DrawingModel value) {
    _store.set(SettingsKeys.recentFiles, value.recentFiles);
    _store.set(SettingsKeys.showGrid, value.showGrid);
    _store.set(SettingsKeys.snapEnabled, value.snapEnabled);
    _store.set(SettingsKeys.snapModes, value.snapModes);
    _store.set(SettingsKeys.orthoMode, value.ortho);
    _store.set(SettingsKeys.polarMode, value.polar);
    _store.set(SettingsKeys.polarIncrement, value.polarIncrement);
  }
}
