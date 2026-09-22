import 'appearance_settings.dart';
import 'assistant_settings.dart';
import 'command_line_settings.dart';
import 'drawing_settings.dart';
import 'mcp_settings.dart';
import 'plugin_settings.dart';
import 'settings.dart';
import 'sidebar_settings.dart';

/// One `settings.json` bag, split into the views each service asks for.
class AppSettings {
  AppSettings(this.store)
    : drawing = DrawingSettings(store),
      assistant = AssistantSettings(store),
      sidebar = SidebarSettings(store),
      commandLine = CommandLineSettings(store),
      appearance = AppearanceSettings(store),
      plugins = PluginSettings(store),
      mcp = McpSettings(store);

  final SettingsStore store;
  final DrawingSettings drawing;
  final AssistantSettings assistant;
  final SidebarSettings sidebar;
  final CommandLineSettings commandLine;
  final AppearanceSettings appearance;
  final PluginSettings plugins;
  final McpSettings mcp;
}
