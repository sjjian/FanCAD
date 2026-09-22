import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../commands/plugin/commands.dart';
import '../models/plugin.dart';
import '../storage/plugin_settings.dart';
import 'plugin_editor.dart';
import 'providers.dart';
import 'workspace.dart';

part 'plugin.g.dart';

/// Connects the extension host to the running application.
///
/// Everything a plugin can reach passes through here, and every method routes
/// into machinery the user already drives: commands run through
/// [Workspace.runHeadless], so a plugin cannot reach a code path the command
/// line cannot, and every edit lands in the same undo stack.
class WorkspacePluginDelegate implements PluginHostDelegate {
  WorkspacePluginDelegate({
    required Workspace Function() workspace,
    required PluginSettings plugins,
    this.onLog,
  }) : _workspace = workspace,
       _plugins = plugins;

  /// Resolved on demand rather than injected.
  ///
  /// The workspace registers the extension management commands, which need the
  /// host, which needs this delegate. Looking the workspace up at call time
  /// rather than at construction is what keeps that chain from being a cycle.
  final Workspace Function() _workspace;

  Workspace get workspace => _workspace();

  final PluginSettings _plugins;

  /// Called after a log line is stored, so the plugin store can republish.
  VoidCallback? onLog;

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
    onLog?.call();
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
      _plugins.read(pluginId, key);

  @override
  Future<void> writeStorage(String pluginId, String key, Object? value) async {
    _plugins.write(pluginId, key, value);
  }
}

/// A callback with no arguments. Local so this file does not import Flutter.
typedef VoidCallback = void Function();

/// Discovered extensions and the host that loads them.
///
/// The pkg [PluginHost] stays on this notifier. [PluginModel] is the snapshot
/// the extensions panel selects.
@Riverpod(keepAlive: true)
class PluginNotifier extends _$PluginNotifier {
  late WorkspacePluginDelegate delegate;
  PluginHost? _host;
  PluginCommands? _commands;
  DisposableBag? _commandScope;
  PluginWatcher? _watcher;
  StreamSubscription<PluginHost>? _hostChanges;
  StreamSubscription<void>? _contributionChanges;
  bool _started = false;
  PluginHost? _eventHost;
  Object? _watchedSession;
  final List<StreamSubscription<void>> _sessionSubscriptions = [];

  PluginHost? get host => _host;
  PluginCommands? get commands => _commands;
  bool get isStarted => _started;

  @override
  PluginModel build() {
    _disposeRuntime();
    final directory = ref.watch(pluginsDirectoryProvider);
    delegate = WorkspacePluginDelegate(
      workspace: () => ref.read(workspaceNotifierProvider.notifier),
      plugins: ref.watch(appSettingsProvider).plugins,
      onLog: _publish,
    );
    ref.listen(
      workspaceNotifierProvider.select((s) => s.activeSessionId),
      (_, id) => onActiveSession(id),
    );
    ref.onDispose(_disposeRuntime);
    if (directory.isEmpty) {
      return PluginModel(directory: directory);
    }

    /// The extension host, or null when this session has no extensions folder.
    ///
    /// Null rather than a host with nowhere to load from: it keeps a test run
    /// from spawning a worker isolate, and it gives the extensions panel
    /// something honest to say instead of showing an empty list that will
    /// never fill.
    _host = PluginHost(
      registry: ref.watch(commandRegistryProvider),
      delegate: delegate,
      transport: ref.watch(pluginTransportProvider),
      createHostCall: createFanCadHostCall,
    );
    _hostChanges = _host!.changes.listen((_) => _publish());
    _contributionChanges = _host!.contributions.changes.listen(
      (_) => _publish(),
    );
    _registerCommands(directory);
    return PluginModel(directory: directory);
  }

  /// Brings the extension host up after the shell is on screen.
  ///
  /// Deliberately not part of application startup. Spawning the worker isolate
  /// and reading plugin folders is work that third-party code influences, and
  /// none of it should sit between the user launching the application and
  /// seeing a window.
  Future<void> start() async {
    if (_started) return;
    final host = _host;
    if (host == null) return;
    _started = true;
    _publish();

    await host.start();

    for (final directory in ref.read(bundledPluginDirectoriesProvider)) {
      await host.discover(directory);
    }
    final userDirectory = ref.read(pluginsDirectoryProvider);
    if (userDirectory.isNotEmpty) {
      await host.discover(userDirectory);
      // Watching only the user folder: reloading a bundled extension on a file
      // change would be reacting to an installer, not to an author.
      final watcher = PluginWatcher(host: host);
      _watcher = watcher;
      await watcher.watch(userDirectory);
    }

    await host.activateStartupPlugins();
    _eventHost = host;
    onActiveSession(ref.read(workspaceNotifierProvider).activeSessionId);
    _publish();
  }

  /// Bridges workspace activity to plugin event handlers.
  ///
  /// Events are notifications, so a plugin that is slow to handle one cannot
  /// delay the edit that produced it. Listens to
  /// [WorkspaceModel.activeSessionId].
  void onActiveSession(String? sessionId) {
    final host = _eventHost;
    if (host == null) return;
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    final session = sessionId == null ? null : workspace.session(sessionId);
    if (session == null) return;
    if (identical(session, _watchedSession)) return;
    _watchedSession = session;
    _sessionSubscriptions
      ..forEach((subscription) => subscription.cancel())
      ..clear();
    _sessionSubscriptions.add(
      session.transactions.listen(
        (transaction) => host.broadcast('document.changed', {
          'label': transaction.label,
          'source': transaction.source.name,
          'added': transaction.change.added,
          'removed': transaction.change.removed,
          'modified': transaction.change.modified,
        }),
      ),
    );
    host.broadcast('document.opened', {
      'title': session.title,
      'path': session.filePath,
    });
  }

  void _registerCommands(String directory) {
    final host = _host;
    if (host == null || directory.isEmpty) return;
    _commandScope?.dispose();
    _commands = PluginCommands(
      host: host,
      pluginsDirectory: directory,
      openEditor: ref.read(pluginEditorNotifierProvider.notifier).open,
    );
    final scope = DisposableBag(debugLabel: 'plugin-commands');
    for (final descriptor in _commands!.descriptors()) {
      scope.add(ref.read(commandRegistryProvider).register(descriptor));
    }
    _commandScope = scope;
  }

  void _publish() {
    final host = _host;
    state = state.copyWith(
      started: _started,
      directory: ref.read(pluginsDirectoryProvider),
      plugins: [
        for (final handle in host?.plugins ?? const <PluginHandle>[])
          PluginRefModel(
            id: handle.id,
            name: handle.manifest.name,
            version: handle.manifest.version,
            state: handle.state.name,
            error: handle.error,
            description: handle.manifest.description,
            directory: handle.manifest.directory,
            entryPoint: handle.manifest.entryPoint,
            permissions: [
              for (final permission in handle.manifest.permissions)
                permission.wireName,
            ],
            commands: [
              for (final command in handle.manifest.commands)
                PluginCommandRefModel(id: command.id, title: command.title),
            ],
            log: List<String>.of(handle.log),
          ),
      ],
      logs: {
        for (final entry in delegate.logs.entries)
          entry.key: List<String>.of(entry.value),
      },
      epoch: state.epoch + 1,
    );
  }

  void _disposeRuntime() {
    for (final subscription in _sessionSubscriptions) {
      unawaited(subscription.cancel());
    }
    _sessionSubscriptions.clear();
    unawaited(_hostChanges?.cancel());
    _hostChanges = null;
    unawaited(_contributionChanges?.cancel());
    _contributionChanges = null;
    unawaited(_watcher?.dispose());
    _watcher = null;
    _commandScope?.dispose();
    _commandScope = null;
    _commands = null;
    _host?.dispose();
    _host = null;
    _eventHost = null;
    _watchedSession = null;
    _started = false;
  }
}

/// FanCAD's `fancad.*` host-call implementation.
///
/// [PluginHost] accepts this factory so the product-named bridge is wired
/// here instead of being hard-coded inside `fancad_plugin_host`.
HostCallHandler createFanCadHostCall({
  required PluginHostDelegate delegate,
  required PluginManifest? Function(String pluginId) manifests,
}) {
  return HostBridge(delegate: delegate, manifests: manifests).call;
}

/// Folders of extensions shipped with the application.
@Riverpod(keepAlive: true)
List<String> bundledPluginDirectories(Ref ref) => const [];
