import 'dart:async';
import 'dart:convert';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../commands/extension/commands.dart';
import '../commands/plugin/commands.dart';
import '../models/plugin.dart';
import '../storage/plugin.dart';
import 'providers.dart';
import 'workspace.dart';

part 'plugin.g.dart';

/// Connects the extension host to the running application.
///
/// Everything a plugin can reach passes through here, and every method routes
/// into machinery the user already drives: commands run through
/// [Workspace.runHeadless], so a plugin cannot reach a code path the command
/// line cannot, and every edit lands in the same undo stack.
class AppPluginDelegate implements PluginDelegate {
  AppPluginDelegate({
    required Workspace Function() workspace,
    required PluginStore plugins,
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

  final PluginStore _plugins;

  /// Called with each log line so the host records it and the store republishes.
  void Function(String pluginId, String level, String message)? onLog;

  /// Set by the shell so a plugin can ask the user something. Null means there
  /// is no one to ask, and prompts resolve to null rather than hanging.
  Future<Object?> Function(String pluginId, Map<String, Object?> spec)?
  promptHandler;

  /// Replaces a contributed panel's view tree.
  void Function(String pluginId, String viewId, Map<String, Object?> tree)?
  renderHandler;

  /// Shows a plugin dialog. Null resolves the dialog to null.
  Future<Object?> Function(String pluginId, Map<String, Object?> spec)?
  dialogHandler;

  /// Replaces the open dialog body. False when this plugin has no dialog up.
  bool Function(String pluginId, Map<String, Object?> tree)?
  dialogUpdateHandler;

  DocumentSession Function(String pluginId, String canvasId)? openViewerHandler;

  void Function(String pluginId, String canvasId)? closeViewerHandler;

  void Function(String pluginId, String canvasId)? fitViewerHandler;

  /// Registers a runtime keybinding on the host.
  void Function(String pluginId, String command, String key, String? when)?
  keybindingHandler;

  /// Dialogs opened by the current scratch run. [sandbox.run] gets one.
  int scratchDialogs = 0;

  static const scratchRunId = 'fancad.scratch.run';

  @override
  DocumentSession? get session => workspace.active?.session;

  @override
  DocumentSession? sessionFor(String? selector) =>
      workspace.findDrawing(selector)?.session;

  DocumentTab? _tab(DocumentSession session) {
    for (final tab in workspace.tabs) {
      if (tab.session.id == session.id) return tab;
    }
    return null;
  }

  @override
  Map<String, Object?> describeView(DocumentSession session) {
    final tab = _tab(session);
    if (tab == null) return const {};
    return workspace.describeTabView(tab);
  }

  @override
  void zoomTo(DocumentSession session, Bounds2? bounds) {
    final tab = _tab(session);
    if (tab == null) return;
    workspace.zoomTabTo(tab, bounds);
  }

  @override
  void zoomBy(DocumentSession session, double factor) {
    final tab = _tab(session);
    if (tab == null) return;
    workspace.zoomTabBy(tab, factor);
  }

  @override
  void panTo(DocumentSession session, Vec2 center) {
    final tab = _tab(session);
    if (tab == null) return;
    workspace.panTabTo(tab, center);
  }

  @override
  void setPreview(DocumentSession session, List<OverlayShape> shapes) {
    _tab(session)?.tools.setPluginChrome(shapes: shapes);
  }

  @override
  void setMarkers(DocumentSession session, List<Vec2> points) {
    _tab(session)?.tools.setPluginChrome(markers: points);
  }

  @override
  Future<Map<String, Object?>?> pick(
    DocumentSession session,
    String kind,
    String message,
  ) async {
    final tab = _tab(session);
    if (tab == null) return null;
    return workspace.acquirePluginPick(tab: tab, kind: kind, message: message);
  }

  @override
  void hold(DocumentSession session, List<int> ids) {
    workspace.holdHighlightsOn(session.id, ids);
  }

  @override
  void flash(DocumentSession session, List<int> ids) {
    workspace.flashHighlightsOn(session.id, ids);
  }

  @override
  void renderView(String pluginId, String viewId, Map<String, Object?> tree) {
    renderHandler?.call(pluginId, viewId, tree);
  }

  @override
  bool updateDialog(String pluginId, Map<String, Object?> tree) {
    return dialogUpdateHandler?.call(pluginId, tree) ?? false;
  }

  @override
  DocumentSession openViewer(String pluginId, String canvasId) {
    final open = openViewerHandler;
    if (open == null) throw StateError('this host has no plugin canvas');
    return open(pluginId, canvasId);
  }

  @override
  void closeViewer(String pluginId, String canvasId) {
    closeViewerHandler?.call(pluginId, canvasId);
  }

  @override
  void fitViewer(String pluginId, String canvasId) {
    fitViewerHandler?.call(pluginId, canvasId);
  }

  @override
  Future<Object?> showDialog(String pluginId, Map<String, Object?> spec) async {
    if (pluginId == scratchRunId) {
      if (scratchDialogs >= 1) {
        throw const RpcException(
          RpcErrorCode.permissionDenied,
          'sandbox.run can open one dialog',
        );
      }
      scratchDialogs += 1;
    }
    final handler = dialogHandler;
    if (handler == null) return null;
    return handler(pluginId, spec);
  }

  @override
  void registerKeybinding(
    String pluginId,
    String command,
    String key,
    String? when,
  ) {
    keybindingHandler?.call(pluginId, command, key, when);
  }

  @override
  Iterable<CommandDescriptor> get commands => workspace.commands.all;

  @override
  Future<CommandResult> runCommand(
    String commandId,
    Map<String, Object?> args, {
    required String pluginId,
    DocumentSession? session,
    String? tab,
  }) {
    // `exec` and `extension.<name>` are the shell. A snippet that reached either
    // through commands.execute would start another sandbox while this worker
    // is still waiting on the host.
    final found = workspace.commands.find(commandId);
    if (commandId == 'exec' || found?.id == 'exec') {
      return Future.value(
        const CommandResult.failed(
          'exec cannot be called from inside a script.',
        ),
      );
    }
    if (found != null && found.id.startsWith('extension.')) {
      return Future.value(
        const CommandResult.failed(
          'script cannot be called from inside a script.',
        ),
      );
    }
    // Plugin-initiated commands are non-interactive by construction: there is
    // no user at the crosshair when a plugin runs LINE, so an unanswered prompt
    // has to be an error rather than a wait.
    return workspace.runHeadless(
      commandId,
      args: args,
      source: ChangeSource.plugin,
      session: session,
      tab: tab,
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
    onLog?.call(pluginId, level, message);
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

/// A document a plugin owns, separate from every drawing tab.
///
/// [watchers] is how many viewer widgets are painting it. Closing the canvas
/// while a widget still holds the camera waits for that widget to unbind, so
/// the controller is not disposed out from under a listener.
class PluginViewer {
  PluginViewer({required this.session, required this.viewport});

  final DocumentSession session;
  final ViewportController viewport;
  int watchers = 0;
  bool closed = false;
  bool _disposed = false;

  void retain() => watchers += 1;

  void release() {
    watchers -= 1;
    if (closed && watchers <= 0) _dispose();
  }

  void close() {
    closed = true;
    if (watchers <= 0) _dispose();
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    session.dispose();
    viewport.dispose();
  }
}

/// Discovered extensions and the manager that loads them.
///
/// The pkg [PluginManager] stays on this notifier. [PluginModel] is the snapshot
/// the extensions panel selects.
@Riverpod(keepAlive: true)
class PluginNotifier extends _$PluginNotifier {
  late AppPluginDelegate delegate;
  PluginManager? _manager;
  PluginCommands? _commands;
  ScriptCommands? _scripts;
  DisposableBag? _commandScope;
  PluginWatcher? _watcher;
  StreamSubscription<PluginManager>? _managerChanges;
  StreamSubscription<void>? _contributionChanges;
  PluginManager? _eventManager;
  Object? _watchedSession;
  final List<StreamSubscription<void>> _sessionSubscriptions = [];
  final Map<String, String> _viewTrees = {};

  /// Private canvases, keyed by plugin id and canvas id. Absent from
  /// [PluginModel]: the camera and the document are not snapshots.
  final Map<String, PluginViewer> _viewers = {};
  Completer<Object?>? _dialog;
  int _dialogToken = 0;
  Timer? _viewportTimer;
  DocumentTab? _viewportTab;
  String _layerSignature = '';
  ScratchSession? scratch;
  bool _starting = false;

  PluginManager? get manager => _manager;
  PluginCommands? get commands => _commands;
  bool get isStarted => state.started;

  @override
  PluginModel build() {
    _disposeRuntime();
    final directory = ref.watch(pluginsDirectoryProvider);
    delegate = AppPluginDelegate(
      workspace: () => ref.read(workspaceNotifierProvider.notifier),
      plugins: ref.watch(appSettingsProvider).plugins,
      onLog: _recordLog,
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
    _manager = PluginManager(
      registry: ref.watch(commandRegistryProvider),
      delegate: delegate,
      transport: ref.watch(pluginTransportProvider),
      createPluginCall: createFanCadPluginCall,
    );
    delegate.renderHandler = _renderView;
    delegate.dialogHandler = _showDialog;
    delegate.dialogUpdateHandler = _updateDialog;
    delegate.openViewerHandler = _openViewer;
    delegate.closeViewerHandler = _closeViewer;
    delegate.fitViewerHandler = _fitViewer;
    delegate.promptHandler = _showPrompt;
    delegate.keybindingHandler = (pluginId, command, key, when) {
      _manager?.registerKeybinding(
        pluginId,
        KeybindingContribution(commandId: command, key: key, when: when),
      );
    };
    _manager!.onEnabledChanged = (id, enabled) {
      ref.read(appSettingsProvider).plugins.setDisabled(id, !enabled);
    };
    scratch = ScratchSession(
      delegate: delegate,
      openTransport: _openScratchTransport,
    );
    _managerChanges = _manager!.changes.listen((_) => _publish());
    _contributionChanges = _manager!.contributions.changes.listen(
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
    if (state.started || _starting) return;
    final host = _manager;
    if (host == null) return;
    _starting = true;
    try {
      await host.start();

      // Scripts replaced installed extensions. Folders already on disk stay
      // there; this host no longer discovers or activates them.
      _eventManager = host;
      onActiveSession(ref.read(workspaceNotifierProvider).activeSessionId);
      state = state.copyWith(started: true);
      _publish();
    } finally {
      _starting = false;
    }
  }

  /// Bridges workspace activity to plugin event handlers.
  ///
  /// Events are notifications, so a plugin that is slow to handle one cannot
  /// delay the edit that produced it. Listens to
  /// [WorkspaceModel.activeSessionId].
  void onActiveSession(String? sessionId) {
    final host = _eventManager;
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
      session.transactions.listen((transaction) {
        host.broadcast('document.changed', {
          'label': transaction.label,
          'source': transaction.source.name,
          'added': transaction.change.added,
          'removed': transaction.change.removed,
          'modified': transaction.change.modified,
        });
        final signature = _layersOf(session.document);
        if (signature != _layerSignature) {
          _layerSignature = signature;
          host.broadcast('layer.changed', {
            'current': session.document.currentLayer,
          });
        }
      }),
    );
    _sessionSubscriptions.add(
      session.selection.changes.listen((ids) {
        host.broadcast('selection.changed', {'ids': ids.toList()});
      }),
    );
    _layerSignature = _layersOf(session.document);
    _bindViewport(workspace.active);
    host.broadcast('document.opened', {
      'title': session.title,
      'path': session.filePath,
    });
  }

  void _bindViewport(DocumentTab? tab) {
    _viewportTab?.removeListener(_onViewport);
    _viewportTimer?.cancel();
    _viewportTimer = null;
    _viewportTab = tab;
    tab?.addListener(_onViewport);
  }

  void _onViewport() {
    if (_viewportTimer != null) return;
    _viewportTimer = Timer(const Duration(milliseconds: 100), () {
      _viewportTimer = null;
      final tab = _viewportTab;
      final host = _eventManager;
      if (tab == null || host == null) return;
      host.broadcast(
        'viewport.changed',
        ref.read(workspaceNotifierProvider.notifier).describeTabView(tab),
      );
    });
  }

  static String _layersOf(CadDocument document) => [
    document.currentLayer,
    for (final layer in document.layers.values)
      '${layer.name}:${layer.visible}:${layer.locked}:${layer.frozen}',
  ].join('|');

  void _renderView(String pluginId, String viewId, Map<String, Object?> tree) {
    final owner = _manager?.contributions.ownerOfPanel(viewId);
    if (owner != pluginId) {
      throw RpcException(
        RpcErrorCode.permissionDenied,
        '$pluginId cannot render "$viewId"',
      );
    }
    _viewTrees[viewId] = jsonEncode(tree);
    _publish();
  }

  Future<Object?> _showPrompt(String pluginId, Map<String, Object?> spec) {
    final message = spec['message'] ?? spec['prompt'] ?? '';
    final tree = parseViewTree({
      'type': 'column',
      'id': 'prompt',
      'children': [
        {'type': 'text', 'id': 'message', 'text': '$message'},
        {
          'type': 'textField',
          'id': 'value',
          'value': spec['value'] ?? spec['default'] ?? '',
        },
      ],
    });
    return _openDialog(
      pluginId: pluginId,
      title: spec['title'] is String ? spec['title'] as String : '$message',
      body: tree,
      buttons: const ['OK', 'Cancel'],
      prompt: true,
    );
  }

  Future<Object?> _showDialog(String pluginId, Map<String, Object?> spec) {
    Map<String, Object?> tree;
    try {
      tree = parseViewTree(spec['body']);
    } on ViewTreeException catch (error) {
      throw RpcException(RpcErrorCode.invalidParams, error.message);
    }
    final buttons = <String>[
      if (spec['buttons'] is List)
        for (final value in spec['buttons'] as List) '$value',
    ];
    return _openDialog(
      pluginId: pluginId,
      title: spec['title'] is String ? spec['title'] as String : '',
      body: tree,
      buttons: buttons.isEmpty ? const ['OK'] : buttons,
      prompt: false,
    );
  }

  Future<Object?> _openDialog({
    required String pluginId,
    required String title,
    required Map<String, Object?> body,
    required List<String> buttons,
    required bool prompt,
  }) {
    final previous = _dialog;
    if (previous != null && !previous.isCompleted) previous.complete(null);
    final pending = Completer<Object?>();
    _dialog = pending;
    final token = ++_dialogToken;
    state = state.copyWith(
      dialog: PluginDialogModel(
        token: token,
        pluginId: pluginId,
        title: title,
        bodyJson: jsonEncode(body),
        buttons: buttons,
        prompt: prompt,
      ),
      epoch: state.epoch + 1,
    );
    return pending.future.whenComplete(() {
      if (!identical(_dialog, pending)) return;
      _dialog = null;
      if (state.dialog?.token == token) {
        state = state.copyWith(dialog: null, epoch: state.epoch + 1);
      }
    });
  }

  /// Swaps the body of the dialog [pluginId] is waiting on. The token stays,
  /// so the same future keeps waiting and text fields keep their focus.
  bool _updateDialog(String pluginId, Map<String, Object?> tree) {
    final dialog = state.dialog;
    if (dialog == null || dialog.pluginId != pluginId) return false;
    state = state.copyWith(
      dialog: dialog.copyWith(bodyJson: jsonEncode(tree)),
      epoch: state.epoch + 1,
    );
    return true;
  }

  /// Forwards a view event to the plugin that rendered [pluginId].
  void dispatchUi(String pluginId, Map<String, Object?> payload) {
    _manager?.emit(pluginId, 'ui.event', payload);
  }

  /// Completes the dialog the shell is showing. [value] is a button id, the
  /// prompt text, or null when the user dismisses it.
  void completeDialog(Object? value) {
    final pending = _dialog;
    if (pending == null || pending.isCompleted) return;
    pending.complete(value);
  }

  PluginTransport _openScratchTransport() {
    final current = ref.read(pluginTransportProvider);
    if (current is LocalTransport) {
      return LocalTransport(
        engineFactory: current.engineFactory,
        hostVersion: current.hostVersion,
      );
    }
    return IsolateTransport(debugName: 'fancad.sandbox');
  }

  void _registerCommands(String directory) {
    if (_manager == null || directory.isEmpty) return;
    _scripts?.release();
    _commandScope?.dispose();
    final settings = ref.read(appSettingsProvider).plugins;
    final scripts = ScriptCommands(
      directory: directory,
      disabled: settings.disabledScriptIds(),
      runScript: (source, {required args}) async {
        final session = scratch;
        if (session == null) {
          return const CommandResult.failed('extensions are unavailable');
        }
        return session.run(source, args: args);
      },
      onChanged: () {
        state = state.copyWith(epoch: state.epoch + 1);
      },
      onEnabled: (name, enabled) {
        ref.read(appSettingsProvider).plugins.setScriptDisabled(name, !enabled);
      },
    );
    _scripts = scripts;
    final registry = ref.read(commandRegistryProvider);
    final scope = DisposableBag(debugLabel: 'script-commands');
    for (final descriptor in scripts.descriptors()) {
      scope.add(registry.register(descriptor));
    }
    scripts.watch(registry);
    _commandScope = scope;
  }

  /// Turns one saved script on or off. A disabled script stays in the list and
  /// leaves the command line until it is enabled again.
  void setScriptEnabled(String name, bool enabled) {
    _scripts?.setEnabled(name, enabled);
  }

  /// Evaluates [source] on the QuickJS worker. Chat and MCP call this
  /// directly. It is not a [CommandRegistry] entry, so a script cannot
  /// `commands.execute` it back into another sandbox.
  Future<Map<String, Object?>> execScript(String source) async {
    final session = scratch;
    if (session == null) {
      return {'status': 'failed', 'message': 'sandbox is unavailable'};
    }
    final result = await session.run(source);
    if (!result.isOk) {
      return {'status': 'failed', 'message': result.message};
    }
    return {'status': 'ok', 'value': result.data?['value']};
  }

  void _recordLog(String pluginId, String level, String message) {
    _manager?.appendLog(pluginId, level, message);
    _publish();
  }

  void _publish() {
    final host = _manager;
    final panels = [
      for (final panel
          in host?.contributions.panels ?? const <PanelContribution>[])
        PluginPanelModel(
          id: panel.id,
          pluginId: host?.contributions.ownerOfPanel(panel.id) ?? '',
          title: panel.title,
          location: panel.location.name,
          icon: panel.icon ?? '',
        ),
    ];
    final live = {for (final panel in panels) panel.id};
    _viewTrees.removeWhere((id, _) => !live.contains(id));
    final activePlugins = {
      for (final handle in host?.plugins ?? const <PluginHandle>[])
        if (handle.state == PluginState.active ||
            handle.state == PluginState.activating)
          handle.id,
    };
    _closeViewersWhere((pluginId) => !activePlugins.contains(pluginId));
    state = state.copyWith(
      started: state.started,
      directory: ref.read(pluginsDirectoryProvider),
      panels: panels,
      viewTrees: Map<String, String>.of(_viewTrees),
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
      epoch: state.epoch + 1,
    );
  }

  /// The private canvas [canvasId] of [pluginId], or null when it is not open.
  PluginViewer? viewerFor(String pluginId, String canvasId) {
    final viewer = _viewers[_viewerKey(pluginId, canvasId)];
    if (viewer == null || viewer.closed) return null;
    return viewer;
  }

  DocumentSession _openViewer(String pluginId, String canvasId) {
    final key = _viewerKey(pluginId, canvasId);
    final existing = _viewers[key];
    if (existing != null && !existing.closed) return existing.session;
    final created = PluginViewer(
      session: DocumentSession(
        id: 'viewer:$pluginId:$canvasId',
        document: CadDocument(),
        title: canvasId,
      ),
      viewport: ViewportController(),
    );
    _viewers[key] = created;
    return created.session;
  }

  void _closeViewer(String pluginId, String canvasId) {
    _viewers.remove(_viewerKey(pluginId, canvasId))?.close();
    state = state.copyWith(epoch: state.epoch + 1);
  }

  void _fitViewer(String pluginId, String canvasId) {
    final viewer = _viewers[_viewerKey(pluginId, canvasId)];
    if (viewer == null || viewer.closed) return;
    viewer.viewport.zoomToExtents(viewer.session.document);
  }

  void _closeViewersWhere(bool Function(String pluginId) drop) {
    final doomed = [
      for (final entry in _viewers.entries)
        if (drop(entry.key.split('\n').first)) entry.key,
    ];
    for (final key in doomed) {
      _viewers.remove(key)?.close();
    }
  }

  String _viewerKey(String pluginId, String canvasId) => '$pluginId\n$canvasId';

  void _disposeRuntime() {
    for (final subscription in _sessionSubscriptions) {
      unawaited(subscription.cancel());
    }
    _sessionSubscriptions.clear();
    _viewportTab?.removeListener(_onViewport);
    _viewportTab = null;
    _viewportTimer?.cancel();
    _viewportTimer = null;
    _closeViewersWhere((_) => true);
    final pending = _dialog;
    _dialog = null;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    unawaited(scratch?.dispose());
    scratch = null;
    unawaited(_managerChanges?.cancel());
    _managerChanges = null;
    unawaited(_contributionChanges?.cancel());
    _contributionChanges = null;
    unawaited(_watcher?.dispose());
    _watcher = null;
    _scripts?.release();
    _scripts = null;
    _commandScope?.dispose();
    _commandScope = null;
    _commands = null;
    _manager?.dispose();
    _manager = null;
    _eventManager = null;
    _watchedSession = null;
  }
}

/// FanCAD's implementation of the `fancad.*` calls a plugin makes.
///
/// [PluginManager] accepts this factory so the product API is wired here
/// instead of being hard-coded inside `fancad_extension`.
PluginCallHandler createFanCadPluginCall({
  required PluginDelegate delegate,
  required PluginManifest? Function(String pluginId) manifests,
}) {
  return PluginApi(delegate: delegate, manifests: manifests).call;
}

/// Folders of extensions shipped with the application.
@Riverpod(keepAlive: true)
List<String> bundledPluginDirectories(Ref ref) => const [];

/// A disposable script runtime for one-shot work from the assistant or MCP.
///
/// It is not an installed extension: no panels, no palette entries, and its
/// worker is separate so abandoning a wedged script does not take the
/// installed plugins with it. QuickJS still cannot interrupt a tight loop;
/// the timeout drops this worker and the next call starts another.
class ScratchSession {
  ScratchSession({required this.delegate, required this.openTransport});

  final AppPluginDelegate delegate;

  /// Builds a worker that is not the installed-plugin isolate.
  final PluginTransport Function() openTransport;

  PluginManager? _manager;
  CommandRegistry? _private;

  Future<CommandResult> query(String source) =>
      _run(source, id: PluginApi.scratchQueryId, write: false);

  Future<CommandResult> run(
    String source, {
    Map<String, Object?> args = const {},
  }) =>
      _run(source, id: AppPluginDelegate.scratchRunId, write: true, args: args);

  Future<CommandResult> _run(
    String source, {
    required String id,
    required bool write,
    Map<String, Object?> args = const {},
  }) async {
    delegate.scratchDialogs = 0;
    final host = await _ensure();
    for (final existing in [
      PluginApi.scratchQueryId,
      AppPluginDelegate.scratchRunId,
    ]) {
      if (host.plugin(existing) != null) await host.uninstall(existing);
    }
    host.registerManifest(
      PluginManifest(
        id: id,
        name: id,
        version: '0.0.0',
        entryPoint: 'scratch.js',
        permissions: {
          PluginPermission.documentRead,
          PluginPermission.commands,
          if (write) PluginPermission.documentWrite,
        },
      ),
    );
    host.setSource(id, 'void 0;\n');
    if (!await host.activate(id)) {
      final error = host.plugin(id)?.error ?? 'the sandbox failed to start';
      return CommandResult.failed(error);
    }
    try {
      // Args stay a separate evaluation so the file's own line numbers stay
      // put. The file itself is tried as an async function: see
      // [extensionPrograms].
      await host.evaluate(id, 'fancad.args = ${jsonEncode(args)};');
      final programs = extensionPrograms(source);
      Object? value;
      for (var i = 0; i < programs.length; i++) {
        try {
          value = await host.evaluate(id, programs[i]);
        } on RpcException catch (error) {
          final retry =
              i + 1 < programs.length &&
              error.message.startsWith('SyntaxError');
          if (retry) continue;
          if (error.code == RpcErrorCode.timeout) await _reset();
          return CommandResult.failed(error.message);
        }
        final failure = extensionFailure(value);
        if (failure != null) return CommandResult.failed(failure);
        value = extensionValue(value);
        break;
      }
      return CommandResult.ok(data: {'value': value});
    } on RpcException catch (error) {
      if (error.code == RpcErrorCode.timeout) await _reset();
      return CommandResult.failed(error.message);
    } finally {
      final live = _manager;
      if (live != null && live.plugin(id) != null) {
        await live.uninstall(id);
      }
    }
  }

  Future<PluginManager> _ensure() async {
    final existing = _manager;
    if (existing != null && existing.transport.isAlive) return existing;
    await _reset();
    final registry = CommandRegistry();
    _private = registry;
    final host = PluginManager(
      registry: registry,
      delegate: delegate,
      transport: openTransport(),
      createPluginCall: createFanCadPluginCall,
    );
    await host.start();
    _manager = host;
    return host;
  }

  Future<void> _reset() async {
    final host = _manager;
    _manager = null;
    if (host != null) await host.dispose();
    _private?.dispose();
    _private = null;
  }

  Future<void> dispose() => _reset();
}
