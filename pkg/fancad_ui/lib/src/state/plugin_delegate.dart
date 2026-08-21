import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';

import 'settings.dart';
import 'workspace.dart';

/// Connects the extension host to the running application.
///
/// Everything a plugin can reach passes through here, and every method routes
/// into machinery the user already drives: commands run through
/// [Workspace.runHeadless], so a plugin cannot reach a code path the command
/// line cannot, and every edit lands in the same undo stack.
class WorkspacePluginDelegate implements PluginHostDelegate {
  WorkspacePluginDelegate({
    required Workspace Function() workspace,
    required this.settings,
  }) : _workspace = workspace;

  /// Resolved on demand rather than injected.
  ///
  /// The workspace registers the extension management commands, which need the
  /// host, which needs this delegate. Looking the workspace up at call time
  /// rather than at construction is what keeps that chain from being a cycle.
  final Workspace Function() _workspace;

  Workspace get workspace => _workspace();

  final SettingsStore settings;

  /// Log lines, newest last, keyed by plugin id. Read by the extensions panel.
  final Map<String, List<String>> logs = {};

  /// Set by the shell so a plugin can ask the user something. Null means there
  /// is no one to ask, and prompts resolve to null rather than hanging.
  Future<Object?> Function(String pluginId, Map<String, Object?> spec)?
      promptHandler;

  @override
  DocumentSession? get session => workspace.active?.session;

  @override
  Iterable<CommandDescriptor> get commands => workspace.commands.all;

  @override
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String pluginId,
  }) {
    // Plugin-initiated commands are non-interactive by construction: there is
    // no user at the crosshair when a plugin runs LINE, so an unanswered prompt
    // has to be an error rather than a wait.
    return workspace.runHeadless(
      commandId,
      args: args,
      source: ChangeSource.plugin,
      log: (message) => log(pluginId, 'info', message),
    );
  }

  @override
  void showMessage(String pluginId, String message, {bool isError = false}) {
    workspace.notify(message, isError: isError);
    log(pluginId, isError ? 'error' : 'info', message);
  }

  @override
  void log(String pluginId, String level, String message) {
    final lines = logs.putIfAbsent(pluginId, () => <String>[]);
    lines.add('[$level] $message');
    if (lines.length > 500) {
      lines.removeRange(0, lines.length - 500);
    }
  }

  @override
  Future<Object?> prompt(String pluginId, Map<String, Object?> spec) async {
    final handler = promptHandler;
    if (handler == null) return null;
    return handler(pluginId, spec);
  }

  // Plugin storage shares the settings file, namespaced by plugin id. One less
  // file to keep consistent, and it means uninstalling a plugin leaves its
  // preferences visible rather than orphaned in a directory nobody reads.
  @override
  Future<Object?> readStorage(String pluginId, String key) async =>
      settings.values[_storageKey(pluginId, key)];

  @override
  Future<void> writeStorage(String pluginId, String key, Object? value) async {
    settings.set(_storageKey(pluginId, key), value);
  }

  String _storageKey(String pluginId, String key) =>
      'plugins.storage.$pluginId.$key';
}
