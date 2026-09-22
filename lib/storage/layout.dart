import '../models/assistant.dart';
import '../models/command_line.dart';
import '../models/layout.dart';
import '../models/sidebar.dart';
import 'settings.dart';

/// Workbench chrome in `settings.json`: open panes, the sidebar view, and
/// the three sizes.
///
/// Command-line expansion and the palette stay on the command-line notifier.
abstract interface class LayoutStore {
  LayoutModel load();

  void save(LayoutModel value);
}

class LayoutSettings implements LayoutStore {
  LayoutSettings(this._store);

  final SettingsStore _store;

  @override
  LayoutModel load() {
    return LayoutModel(
      sidebarView: _store.getString(
        SettingsKeys.sidebarView,
        fallback: 'layers',
      ),
      sidebarOpen: _store.getBool(SettingsKeys.sidebarOpen, fallback: true),
      assistantOpen: _store.getBool(SettingsKeys.assistantOpen),
      sidebarWidth: _store.getDouble(
        SettingsKeys.sidebarWidth,
        fallback: SidebarLayout.defaultWidth,
      ),
      assistantWidth: _store.getDouble(
        SettingsKeys.assistantWidth,
        fallback: AssistantPaneLayout.defaultWidth,
      ),
      commandHeight: _store.getDouble(
        SettingsKeys.commandPaneHeight,
        fallback: CommandLineLayout.defaultHeight,
      ),
    );
  }

  @override
  void save(LayoutModel value) {
    _store.set(SettingsKeys.sidebarView, value.sidebarView);
    _store.set(SettingsKeys.sidebarOpen, value.sidebarOpen);
    _store.set(SettingsKeys.assistantOpen, value.assistantOpen);
    _store.set(SettingsKeys.sidebarWidth, value.sidebarWidth);
    _store.set(SettingsKeys.assistantWidth, value.assistantWidth);
    _store.set(SettingsKeys.commandPaneHeight, value.commandHeight);
  }
}
