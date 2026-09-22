import 'assistant.dart';
import 'layout.dart';
import 'plugin.dart';
import 'settings.dart';
import 'workspace.dart';

/// One `settings.json` bag, split into the views each service asks for.
class AppSettings {
  AppSettings(SettingsStore store)
    : workspace = WorkspaceSettings(store),
      assistant = AssistantSettings(store),
      layout = LayoutSettings(store),
      appearance = AppearanceSettings(store),
      plugins = PluginSettings(store),
      mcp = McpSettings(store);

  final WorkspaceStore workspace;
  final AssistantStore assistant;
  final LayoutStore layout;
  final AppearanceStore appearance;
  final PluginStore plugins;
  final McpStore mcp;
}
