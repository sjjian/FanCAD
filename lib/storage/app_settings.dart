import 'assistant.dart';
import 'extension.dart';
import 'layout.dart';
import 'settings.dart';
import 'workspace.dart';

/// One `settings.json` bag, split into the views each service asks for.
class AppSettings {
  AppSettings(SettingsStore store)
    : workspace = WorkspaceSettings(store),
      assistant = AssistantSettings(store),
      layout = LayoutSettings(store),
      appearance = AppearanceSettings(store),
      extensions = ExtensionSettings(store),
      mcp = McpSettings(store),
      updates = UpdatesSettings(store);

  final WorkspaceStore workspace;
  final AssistantStore assistant;
  final LayoutStore layout;
  final AppearanceStore appearance;
  final ExtensionStore extensions;
  final McpStore mcp;
  final UpdatesStore updates;
}
