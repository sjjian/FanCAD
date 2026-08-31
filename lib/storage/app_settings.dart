import 'assistant_settings.dart';
import 'drawing_settings.dart';
import 'mcp_settings.dart';
import 'plugin_settings.dart';
import 'settings.dart';
import 'shell_settings.dart';

/// One `settings.json` bag, split into the views each service asks for.
class AppSettings {
  AppSettings(this.store)
    : drawing = DrawingSettings(store),
      assistant = AssistantSettings(store),
      shell = ShellSettings(store),
      plugins = PluginSettings(store),
      mcp = McpSettings(store);

  final SettingsStore store;
  final DrawingSettings drawing;
  final AssistantSettings assistant;
  final ShellSettings shell;
  final PluginSettings plugins;
  final McpSettings mcp;
}
