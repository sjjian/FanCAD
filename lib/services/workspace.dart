import 'dart:async';
import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../commands/builtins.dart';
import '../commands/file/commands.dart';
import '../l10n/l10n.dart';
import '../models/command_line.dart';
import '../models/workspace.dart';
import '../storage/drawing_settings.dart';
import 'appearance.dart';
import 'command_line.dart';
import 'providers.dart';

part 'workspace.g.dart';

/// One-shot reply for an [ApprovalRequestModel].
///
/// [approve] / [reject] complete the handshake; this is not persisted.
class PendingApproval {
  PendingApproval(this.request);

  final ApprovalRequestModel request;
  final Completer<bool> _completer = Completer<bool>();

  Future<bool> get decision => _completer.future;

  void approve() {
    if (!_completer.isCompleted) _completer.complete(true);
  }

  void reject() {
    if (!_completer.isCompleted) _completer.complete(false);
  }
}

/// Builds [FileCommands] for a workspace. Tests override this instead of
/// constructing the notifier by hand.
typedef WorkspaceFileCommandsFactory =
    FileCommands Function(WorkspaceNotifier workspace);

/// Optional [FileCommands] used by headless tests that stub open / save.
@Riverpod(keepAlive: true)
WorkspaceFileCommandsFactory? workspaceFileCommandsOverride(Ref ref) => null;

/// The application state: open documents, the command registry, and the wiring
/// that lets a command reach the UI.
///
/// This is the object that owns the "one write path" guarantee. Every mutation —
/// from a toolbar button, a typed command, a plugin, or the model — is a
/// [CommandRegistry.run] call routed through here, so there is exactly one place
/// where a change can be observed, logged, undone or refused.
@Riverpod(keepAlive: true)
class WorkspaceNotifier extends _$WorkspaceNotifier implements CommandServices {
  @override
  WorkspaceModel build() {
    commands = ref.read(commandRegistryProvider);
    importer = ref.read(importerProvider);
    _drawing = ref.read(appSettingsProvider).drawing;
    snapEngine = SnapEngine(
      enabled: _drawing.snapEnabled,
      snapToGrid: _drawing.showGrid,
      modes: _restoreSnapModes(),
      tracking: TrackingSettings(
        ortho: _drawing.ortho,
        polar: _drawing.polar,
        polarIncrement: _drawing.polarIncrement(),
      ),
    );
    final fileCommands =
        ref.read(workspaceFileCommandsOverrideProvider)?.call(this) ??
        FileCommands(
          openFile: (path) async => await openFile(path) != null,
          newDocument: newDocument,
          closeActive: (session, {bool force = false}) =>
              closeSession(session, force: force),
          saveActive: (session, path) => saveSession(session, path),
          recentFiles: () => _drawing.recentFiles,
          listSessions: () => [for (final id in sessionIds) ?session(id)],
          activeSessionId: () => activeSession?.id,
          activateDrawing: activateDrawing,
        );
    final registration = registerBuiltinCommands(
      commands,
      fileCommands: fileCommands,
      pluginCommands: null,
      clipboard: clipboard,
    );
    ref.onDispose(() {
      registration.dispose();
      _teardown();
    });
    // File-backed settings only: an in-memory store must not walk the disk.
    if (ref.read(settingsProvider).file != null) {
      unawaited(reloadShxFonts());
    }
    return WorkspaceModel(
      snapEnabled: snapEngine.enabled,
      ortho: snapEngine.tracking.ortho,
      polar: snapEngine.tracking.polar,
      snapModes: [for (final mode in snapEngine.modes) mode.name],
      recentFiles: _drawing.recentFiles,
    );
  }

  late CommandRegistry commands;
  late DrawingImporter importer;
  late DrawingSettings _drawing;
  CommandLineNotifier get commandLine =>
      ref.read(commandLineNotifierProvider.notifier);

  @override
  String get locale {
    final value = ref.read(appearanceNotifierProvider).language.trim();
    return value.isEmpty ? 'en' : value;
  }

  List<String> get recentFiles => state.recentFiles;

  /// Snapping is application-wide rather than per-tab, because the toggles live
  /// on the canvas HUD and users expect them to stay put when switching tabs.
  late final SnapEngine snapEngine;

  /// Geometry clipboard shared by every open tab. COPYCLIP writes here;
  /// PASTECLIP in another drawing reads it. Not the OS clipboard.
  final DrawingClipboard clipboard = DrawingClipboard();

  ShxFontTable _shxFonts = const ShxFontTable();
  bool _disposed = false;

  WorkspaceModel get _store => state;
  final Map<String, DocumentTab> _hosts = {};
  int _nextSessionId = 1;
  final Map<DocumentTab, StreamSubscription<Set<int>>> _selectionReveals = {};

  final StreamController<PendingApproval> _approvals =
      StreamController<PendingApproval>.broadcast();
  final StreamController<String> _panelReveals =
      StreamController<String>.broadcast();

  /// The interactive input of the in-flight [run], when there is one.
  InteractiveCommandInput? _activeInput;

  Timer? _flashTimer;

  /// Last geometry the human or the assistant created or changed.

  List<DocumentTab> get tabs => List.unmodifiable([
    for (final session in _store.sessions) ?_hosts[session.id],
  ]);
  int get activeIndex => _store.activeIndex;

  DocumentTab? get active {
    final session = _store.active;
    if (session == null) return null;
    return _hosts[session.id];
  }

  /// The active tab when it is a real drawing, not the start screen.
  DocumentTab? get activeDrawing {
    final tab = active;
    if (tab == null || tab.isStartPage) return null;
    return tab;
  }

  bool get hasDocument => activeDrawing != null;

  /// Open drawing sessions, skipping start pages.
  List<String> get sessionIds => _store.sessionIds;

  DocumentSession? session(String id) {
    final key = id.trim();
    if (key.isEmpty) return null;
    for (final record in _store.sessions) {
      if (record.isStartPage) continue;
      if (record.id != key) continue;
      return _hosts[record.id]?.session;
    }
    return null;
  }

  DocumentSession? get activeSession => activeDrawing?.session;

  List<NoticeModel> get notices => _store.notices;

  /// Fires when something asks the user to approve a change.
  Stream<PendingApproval> get approvals => _approvals.stream;

  /// Fires when a command asks for a panel to be brought forward.
  Stream<String> get panelReveals => _panelReveals.stream;

  String? get runningCommand => _store.runningCommand;
  bool get isBusy => _store.runningCommand != null;
  bool get assistantBusy => _store.assistantBusy;

  List<int> get lastCreatedIds => _store.lastCreatedIds;
  List<int> get lastModifiedIds => _store.lastModifiedIds;

  /// Points collected by the in-flight interactive command.
  int get collectedPointCount =>
      _activeInput?.collectedPointCount ?? _store.collectedPointCount;

  /// Entities the canvas should highlight while an approval is pending.
  ///
  /// Approval ids stay on [WorkspaceModel.approval]. Held / flash / hover live
  /// on the active session.
  List<int> get pendingHighlightIds => _store.highlightIds;

  /// Holds [ids] on the active session until the caller clears them.
  ///
  /// Used by the assistant while a change set is waiting in chat. Command
  /// approval highlights stay on [WorkspaceModel.approval].
  void setPendingHighlights(List<int> ids) {
    final session = _store.active;
    if (session == null) return;
    if (_sameIds(session.heldIds, ids)) return;
    _replaceSession(
      session.id,
      (record) => record.copyWith(heldIds: List<int>.unmodifiable(ids)),
    );
  }

  /// Pulses [ids] on the canvas, then clears them so they do not stick.
  void flashHighlights(List<int> ids) {
    _flashTimer?.cancel();
    final session = _store.active;
    if (session == null) return;
    final id = session.id;
    _replaceSession(id, (record) => record.copyWith(flashIds: ids));
    if (ids.isEmpty) return;
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      _replaceSession(id, (record) => record.copyWith(flashIds: const []));
    });
  }

  /// Holds [ids] while the pointer is over a chip or `#id` in chat.
  void setHoverHighlights(List<int> ids) {
    final session = _store.active;
    if (session == null) return;
    if (_sameIds(session.hoverIds, ids)) return;
    _replaceSession(session.id, (record) => record.copyWith(hoverIds: ids));
  }

  static bool _sameIds(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void setAssistantBusy(bool value) {
    if (_store.assistantBusy == value) return;
    if (value) {
      for (final tab in _hosts.values) {
        tab.tools.cancelGesture();
      }
    }
    _setStore(_store.copyWith(assistantBusy: value));
  }

  /// Feeds a value into the command line prompt the human is sitting in.
  Map<String, Object?> supplyInteractive(Map<String, Object?> args) {
    final pending = commandLine.pending;
    if (pending == null) {
      return {
        'status': 'failed',
        'message': 'No command is waiting for input.',
      };
    }
    final point = CommandArgs.parsePoint(args['point']);
    if (point != null) {
      commandLine.supplyFromPointer(point);
      return {
        'status': 'ok',
        'supplied': 'point',
        'point': [point.x, point.y],
      };
    }
    final keyword = '${args['keyword'] ?? ''}'.trim();
    if (keyword.isNotEmpty) {
      commandLine.supplyFromPointer(keyword);
      return {'status': 'ok', 'supplied': 'keyword', 'keyword': keyword};
    }
    final number = args['number'];
    if (number is num) {
      commandLine.supplyFromPointer(number.toDouble());
      return {'status': 'ok', 'supplied': 'number', 'number': number};
    }
    final ids = CommandArgs(args).ids('ids');
    if (ids != null && ids.isNotEmpty) {
      commandLine.supplyFromPointer(ids);
      return {'status': 'ok', 'supplied': 'ids', 'ids': ids};
    }
    return {
      'status': 'failed',
      'message':
          'session.supply needs a point, number, keyword or ids matching '
          'the current prompt.',
    };
  }

  // -------------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------------

  /// Creates an empty drawing and makes it active.
  ///
  /// A start tab already on screen is reused so plus-then-New does not leave
  /// an extra blank tab behind.
  DocumentTab newDocument({String? title, CadDocument? document}) {
    final current = active;
    if (current != null && current.isStartPage && document == null) {
      current.promoteToDrawing(title: title);
      return current;
    }
    final session = DocumentSession(
      id: '${_nextSessionId++}',
      document: document ?? CadDocument(),
      title: title,
    );
    final tab = _adopt(_createTab(session), _openRecord(session));
    _discardIdleStartPages();
    return tab;
  }

  /// Opens the start screen in a tab, or brings an existing one forward.
  DocumentTab openStartTab() {
    for (var i = 0; i < _store.sessions.length; i++) {
      if (!_store.sessions[i].isStartPage) continue;
      activate(i);
      return _hosts[_store.sessions[i].id]!;
    }
    final session = DocumentSession(
      id: '${_nextSessionId++}',
      document: CadDocument(),
    );
    return _adopt(_createTab(session), _openRecord(session, isStartPage: true));
  }

  /// Opens [path], reporting failures as notices rather than exceptions.
  Future<DocumentTab?> openFile(String path) async {
    final target = path.trim();
    if (target.isEmpty) {
      notify('There is no file to open.', isError: true);
      return null;
    }
    // An already-open file is activated rather than opened twice; two tabs onto
    // one file with independent undo stacks is a data-loss trap. Compare the
    // resolved file, so a symlink or a `./` in the path is not a second tab.
    // Do this before the exists check: a tab whose path vanished on disk
    // should still come to the front.
    for (var i = 0; i < _store.sessions.length; i++) {
      final tab = _hosts[_store.sessions[i].id];
      if (tab == null || !_sameDrawingFile(tab.filePath, target)) continue;
      activate(i);
      _discardIdleStartPages();
      return tab;
    }
    if (!File(target).existsSync()) {
      _dropRecent(target);
      notify('$target is missing and was removed from Recent.', isError: true);
      return null;
    }
    try {
      commandLine.write('Opening $target ...');
      final result = await importer.open(target);
      final stored = _fileIdentity(target);
      final session = DocumentSession(
        id: '${_nextSessionId++}',
        document: result.document,
        filePath: stored,
      );
      final tab = _adopt(
        _createTab(session),
        _openRecord(session, diagnostics: result.diagnostics),
      );
      tab.viewport.zoomToExtents(result.document);
      _drawing.pushRecent(stored);
      _syncRecent();
      unawaited(reloadShxFonts(drawingPath: stored));
      commandLine.writeSuccess(
        'Opened ${result.entityCount} entities in '
        '${result.totalTime.inMilliseconds} ms.',
      );
      for (final diagnostic in result.diagnostics.take(20)) {
        commandLine.write(diagnostic, level: HistoryLevel.warning);
      }
      if (result.diagnostics.length > 20) {
        commandLine.write(
          '... and ${result.diagnostics.length - 20} more warnings.',
          level: HistoryLevel.warning,
        );
      }
      _discardIdleStartPages();
      return tab;
    } on ImportException catch (error) {
      notify(error.message, isError: true);
      return null;
    } catch (error) {
      notify('Could not open $target: $error', isError: true);
      return null;
    }
  }

  /// Writes the active document, returning the path written or null.
  ///
  /// DWG writing is not in this build yet, so rather than silently doing
  /// nothing or silently writing a file the user cannot reopen elsewhere, a save
  /// to an unwritable format falls back to FanCAD's own `.fcb` alongside it and
  /// says so. Losing work is not an acceptable failure mode; a clearly named
  /// sidecar file is.
  Future<String?> saveActive([String? path]) async {
    final tab = activeDrawing;
    if (tab == null) {
      notify('There is no drawing to save.', isError: true);
      return null;
    }
    return saveTab(tab, path);
  }

  /// Writes [session]'s tab, used by `file.save` when MCP targets a background
  /// drawing.
  Future<String?> saveSession(DocumentSession session, [String? path]) async {
    final tab = tabForSession(session);
    if (tab == null) {
      notify('There is no drawing to save.', isError: true);
      return null;
    }
    return saveTab(tab, path);
  }

  Future<String?> saveTab(DocumentTab tab, [String? path]) async {
    final target = (path ?? tab.filePath)?.trim();
    if (target == null || target.isEmpty) {
      notify('There is no path to save to.', isError: true);
      return null;
    }

    try {
      final outcome = await importer.save(target, tab.document);
      final written = _fileIdentity(outcome.path);
      tab.markSaved(written);
      _drawing.pushRecent(written);
      if (outcome.usedFallback && outcome.plan.reason.isNotEmpty) {
        notify(outcome.plan.reason);
      }
      _syncRecent();
      return written;
    } catch (error) {
      notify('Could not save $target: $error', isError: true);
      return null;
    }
  }

  DocumentTab _createTab(DocumentSession session) {
    final tab = ref.read(documentTabNotifierProvider(session.id).notifier);
    tab.attach(
      session: session,
      snapEngine: snapEngine,
      selectionTool: _selectionTool(),
    );
    return tab;
  }

  DocumentTab _adopt(DocumentTab tab, WorkspaceSessionModel record) {
    _hosts[record.id] = tab;
    tab.bindStore(
      read: () => _sessionRecord(record.id),
      write: (update) => _replaceSession(record.id, update),
    );
    tab.addListener(_onHostTick);
    // A pick that names objects brings Properties forward so the left pane
    // matches what is on the canvas, instead of staying on Layers.
    _selectionReveals[tab] = tab.session.selection.changes.listen((ids) {
      if (ids.isEmpty || !identical(tab, active)) return;
      revealPanel('properties');
    });
    _setStore(
      _store.copyWith(
        sessions: [..._store.sessions, record],
        activeIndex: _store.sessions.length,
      ),
    );
    return tab;
  }

  WorkspaceSessionModel _sessionRecord(String id) {
    for (final session in _store.sessions) {
      if (session.id == id) return session;
    }
    throw StateError('Workspace session $id is not open');
  }

  void _setStore(WorkspaceModel next) {
    if (_disposed) return;
    state = next;
  }

  WorkspaceSessionModel _openRecord(
    DocumentSession session, {
    bool isStartPage = false,
    List<String> diagnostics = const [],
  }) {
    return WorkspaceSessionModel(
      id: session.id,
      isStartPage: isStartPage,
      showGrid: _drawing.showGrid,
      diagnostics: diagnostics,
      title: session.title,
      isDirty: session.isDirty,
    );
  }

  /// Viewport / tools also notify the tab. Only title and dirty tick the store.
  void _onHostTick() => _syncTabStripChrome();

  void _syncTabStripChrome() {
    if (_disposed) return;
    var changed = false;
    final sessions = <WorkspaceSessionModel>[];
    for (final session in _store.sessions) {
      final tab = _hosts[session.id];
      if (tab == null ||
          (session.title == tab.title && session.isDirty == tab.isDirty)) {
        sessions.add(session);
        continue;
      }
      changed = true;
      sessions.add(session.copyWith(title: tab.title, isDirty: tab.isDirty));
    }
    if (changed) _setStore(_store.copyWith(sessions: sessions));
  }

  bool _replaceSession(
    String id,
    WorkspaceSessionModel Function(WorkspaceSessionModel) update,
  ) {
    final sessions = <WorkspaceSessionModel>[];
    var found = false;
    for (final session in _store.sessions) {
      if (session.id == id) {
        sessions.add(update(session));
        found = true;
      } else {
        sessions.add(session);
      }
    }
    if (!found) return false;
    _setStore(_store.copyWith(sessions: sessions));
    return true;
  }

  void activate(int index) {
    if (index < 0 ||
        index >= _store.sessions.length ||
        index == _store.activeIndex) {
      return;
    }
    _setStore(_store.copyWith(activeIndex: index));
    snapEngine.snapToGrid = _store.sessions[index].showGrid;
  }

  void activateTab(DocumentTab tab) {
    for (var i = 0; i < _store.sessions.length; i++) {
      if (_store.sessions[i].id == tab.session.id) {
        activate(i);
        return;
      }
    }
  }

  /// Open drawing for [selector], or the active tab when [selector] is empty.
  ///
  /// Matches session id, then file path, then a unique title. Duplicate titles
  /// are not a match — use an id from [sessionIds].
  DocumentTab? findDrawing(String? selector) {
    final key = selector?.trim() ?? '';
    if (key.isEmpty) return activeDrawing;

    for (final tab in tabs) {
      if (tab.isStartPage) continue;
      if (tab.session.id == key) return tab;
    }
    for (final tab in tabs) {
      if (tab.isStartPage) continue;
      if (_sameDrawingFile(tab.filePath, key)) return tab;
    }
    DocumentTab? titled;
    var matches = 0;
    for (final tab in tabs) {
      if (tab.isStartPage) continue;
      if (tab.title != key) continue;
      titled = tab;
      matches += 1;
    }
    if (matches == 1) return titled;
    return null;
  }

  /// Error for a [findDrawing] miss, including duplicate-title candidates.
  String drawingNotFoundMessage(String selector) {
    final key = selector.trim();
    final ids = [
      for (final tab in tabs)
        if (tab.title == key) tab.session.id,
    ];
    if (ids.length > 1) {
      return 'Title "$key" matches more than one drawing (ids: ${ids.join(', ')}). '
          'Use an id from file.list.';
    }
    return 'No open drawing matches "$key".';
  }

  /// Brings [selector] to the front. Returns an error message, or null.
  String? activateDrawing(String selector) {
    final tab = findDrawing(selector);
    if (tab == null) return drawingNotFoundMessage(selector);
    activateTab(tab);
    return null;
  }

  DocumentTab? tabForSession(DocumentSession session) {
    final index = indexOfSession(session);
    if (index < 0) return null;
    return _hosts[_store.sessions[index].id];
  }

  int indexOfSession(DocumentSession session) {
    for (var i = 0; i < _store.sessions.length; i++) {
      final tab = _hosts[_store.sessions[i].id];
      if (tab != null && identical(tab.session, session)) return i;
    }
    for (var i = 0; i < _store.sessions.length; i++) {
      if (_store.sessions[i].id == session.id) return i;
    }
    return -1;
  }

  /// Closes the tab that owns [session]. Returns false when it is dirty and
  /// [force] is false.
  bool closeSession(DocumentSession session, {bool force = false}) {
    final index = indexOfSession(session);
    if (index < 0) return true;
    return closeTab(index, force: force);
  }

  /// Drops the recent-files list. Missing paths otherwise stay in the File
  /// menu and on the empty workspace until the user restarts.
  void _syncRecent() {
    _setStore(
      state.copyWith(recentFiles: List<String>.of(_drawing.recentFiles)),
    );
  }

  void clearRecentFiles() {
    _drawing.setRecentFiles(const []);
    _syncRecent();
  }

  /// Drops recent paths whose files are gone, so the File menu and empty
  /// workspace stop offering drawings that cannot be opened.
  int pruneMissingRecentFiles() {
    final recent = _drawing.recentFiles;
    final kept = [
      for (final path in recent)
        if (File(path).existsSync()) path,
    ];
    if (kept.length == recent.length) return 0;
    _drawing.setRecentFiles(kept);
    _syncRecent();
    return recent.length - kept.length;
  }

  void _dropRecent(String path) {
    final identity = _fileIdentity(path);
    final recent = _drawing.recentFiles;
    final kept = [
      for (final item in recent)
        if (_fileIdentity(item) != identity) item,
    ];
    if (kept.length == recent.length) return;
    _drawing.setRecentFiles(kept);
    _syncRecent();
  }

  /// Closes a tab. Returns false when the caller should ask about unsaved
  /// changes first.
  bool closeTab(int index, {bool force = false}) {
    if (index < 0 || index >= _store.sessions.length) return true;
    final record = _store.sessions[index];
    final tab = _hosts[record.id];
    if (tab != null && tab.isDirty && !force) return false;
    _hosts.remove(record.id);
    if (tab != null) {
      _selectionReveals.remove(tab)?.cancel();
      tab.removeListener(_onHostTick);
      ref.invalidate(documentTabNotifierProvider(record.id));
    }
    final sessions = [..._store.sessions]..removeAt(index);
    var nextActive = _store.activeIndex;
    if (sessions.isEmpty) {
      nextActive = -1;
    } else if (index < nextActive) {
      // A tab to the left disappeared; the active document did not move, so
      // its index has to follow it. Leaving the number alone would activate
      // whatever slid into this slot — usually the neighbour, not the drawing
      // the user was still looking at.
      nextActive -= 1;
    } else if (nextActive >= sessions.length) {
      nextActive = sessions.length - 1;
    }
    _setStore(_store.copyWith(sessions: sessions, activeIndex: nextActive));
    return true;
  }

  void _discardIdleStartPages() {
    final keep = activeDrawing;
    for (var i = _store.sessions.length - 1; i >= 0; i--) {
      final tab = _hosts[_store.sessions[i].id];
      if (tab == null || !tab.isStartPage) continue;
      if (identical(tab, keep)) continue;
      closeTab(i, force: true);
    }
  }

  /// Closes every drawing except [keep], using the same Save / Don't save /
  /// Cancel path a single tab close uses.
  Future<bool> closeOtherTabs(DocumentTab keep) async {
    while (true) {
      DocumentTab? next;
      for (final tab in tabs) {
        if (!identical(tab, keep)) {
          next = tab;
          break;
        }
      }
      if (next == null) {
        activateTab(keep);
        return true;
      }
      activateTab(next);
      final result = await run('file.close');
      if (!result.isOk) return false;
    }
  }

  /// Closes every drawing. Returns false if the user cancelled a dirty prompt.
  Future<bool> closeAllTabs() async {
    while (_store.sessions.isNotEmpty) {
      final result = await run('file.close');
      if (!result.isOk) return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Command execution
  // -------------------------------------------------------------------------

  /// Runs a command interactively, as a click or a typed verb does.
  ///
  /// Refuses to start while another command is running rather than interleaving
  /// two commands' prompts, which would make it ambiguous which one the next
  /// click belongs to.
  Future<CommandResult> run(
    String idOrAlias, {
    Map<String, Object?> args = const {},
    ChangeSource source = ChangeSource.user,
  }) async {
    final descriptor = commands.find(idOrAlias);
    if (descriptor == null) {
      commandLine.writeError('Unknown command: $idOrAlias');
      return CommandResult.failed('Unknown command: $idOrAlias');
    }
    if (_store.assistantBusy && !_isHostCommand(descriptor.id)) {
      final message =
          'The assistant is working. Stop it before starting a command.';
      commandLine.writeError(message);
      return CommandResult.failed(message);
    }
    if (_store.runningCommand != null) {
      // Starting a new command cancels the old one, which is the behaviour
      // every CAD user already has in their fingers.
      commandLine.cancelPending('Superseded by $idOrAlias');
      active?.tools.cancel();
    }
    if (activeDrawing == null) {
      final message = _missingDocumentMessage(descriptor.id);
      if (message != null &&
          !(descriptor.id == 'file.close' && active != null)) {
        commandLine.writeError(message);
        return CommandResult.failed(message);
      }
    }
    // Host commands that must not invent a leftover blank tab: file pickers
    // that the user can cancel, and settings, which has no document at all.
    // A start tab is reused for New, and promoted when a drawing command runs.
    final tab =
        activeDrawing ??
        (_isHostCommand(descriptor.id)
            ? (active ??
                  _createTab(
                    DocumentSession(id: 'transient', document: CadDocument()),
                  ))
            : newDocument(title: 'Drawing1'));
    _setStore(_store.copyWith(runningCommand: descriptor.id));

    InteractiveCommandInput? input;
    try {
      final result = await commands.run(
        descriptor.id,
        args: args,
        source: source,
        contextBuilder: (each) {
          input = InteractiveCommandInput(
            tools: tab.tools,
            commandLine: commandLine,
            args: CommandArgs(args),
            params: each.params,
            locale: locale,
          );
          _activeInput = input;
          return CommandContext(
            session: tab.session,
            args: CommandArgs(args),
            input: input!,
            services: this,
            source: source,
            commandId: each.id,
          );
        },
      );
      _report(descriptor, result);
      _rememberResult(result);
      return result;
    } finally {
      if (identical(_activeInput, input)) _activeInput = null;
      input?.cancel();
      _setStore(_store.copyWith(runningCommand: null));
    }
  }

  static bool _isHostCommand(String id) =>
      id == 'file.open' ||
      id == 'file.openRecent' ||
      id == 'file.new' ||
      id == 'file.list' ||
      id == 'file.activate' ||
      id == 'workbench.preferences';

  /// Save and close have nowhere to act when the last tab is already gone.
  /// Inventing a blank drawing just so the command can run would leave that
  /// tab behind — or, for close, create one only to destroy it.
  static String? _missingDocumentMessage(String id) {
    switch (id) {
      case 'file.save':
      case 'file.saveAs':
        return 'There is no drawing to save.';
      case 'file.close':
        return 'There is no drawing to close.';
      default:
        return null;
    }
  }

  /// Cancels whatever is running, as Escape does.
  ///
  /// Escape has to mean the same thing everywhere — abandon the current
  /// command, an in-flight grip or window drag, or the selection — so it is
  /// one method rather than a behaviour each widget reimplements. The window
  /// itself is never part of that: Escape must not restore a maximised frame.
  void cancelActive() {
    final tab = active;
    if (tab != null && tab.viewport.revertInteraction()) return;
    if (tab != null && tab.tools.cancelGesture()) return;
    if (commandLine.isAwaitingInput) {
      commandLine.cancelPending();
    } else {
      tab?.tools.cancel();
    }
  }

  /// Runs a command non-interactively from a supplied argument map.
  ///
  /// This is the path plugins and AI tool calls take: identical command
  /// implementations, but every prompt is answered from [args] and an
  /// unanswerable prompt is an error instead of a hang. Headless runs never
  /// fall back to the current selection. An AI write while a person is in a
  /// command is refused; a missing point on an AI run hands off to the
  /// crosshair instead of cancelling.
  Future<CommandResult> runHeadless(
    String idOrAlias, {
    Map<String, Object?> args = const {},
    ChangeSource source = ChangeSource.plugin,
    DocumentSession? session,
    String? tab,
    void Function(String message)? log,
  }) async {
    final descriptor = commands.find(idOrAlias);
    if (descriptor == null) {
      return CommandResult.failed('Unknown command: $idOrAlias');
    }
    if (source == ChangeSource.ai &&
        _store.runningCommand != null &&
        descriptor.risk != CommandRisk.readOnly) {
      return CommandResult.failed(
        '${_store.runningCommand} is running. Stop it or wait before changing '
        'the drawing.',
      );
    }
    if (tab != null && tab.trim().isNotEmpty) {
      final found = findDrawing(tab);
      if (found == null) {
        return CommandResult.failed(drawingNotFoundMessage(tab));
      }
      session = found.session;
    }
    if (session == null &&
        active?.isStartPage == true &&
        !_isHostCommand(descriptor.id)) {
      newDocument();
    }
    final target =
        session ??
        activeDrawing?.session ??
        (_isHostCommand(descriptor.id) ? active?.session : null);
    if (target == null) {
      if (descriptor.id == 'file.list' || descriptor.id == 'file.activate') {
        final result = await commands.run(
          descriptor.id,
          args: args,
          source: source,
          contextBuilder: (each) {
            final transient = DocumentSession(
              id: 'transient',
              document: CadDocument(),
            );
            return CommandContext(
              session: transient,
              args: CommandArgs(args),
              input: ArgsCommandInput(
                args: CommandArgs(args),
                params: each.params,
                log: log ?? commandLine.write,
              ),
              services: this,
              source: source,
              commandId: each.id,
            );
          },
        );
        _rememberResult(result);
        return result;
      }
      return CommandResult.failed('No drawing is open');
    }
    InteractiveCommandInput? handed;
    try {
      final result = await commands.run(
        descriptor.id,
        args: args,
        source: source,
        contextBuilder: (each) {
          final argsInput = ArgsCommandInput(
            args: CommandArgs(args),
            params: each.params,
            log: log ?? commandLine.write,
          );
          final CommandInput input;
          if (source == ChangeSource.ai) {
            input = FallbackCommandInput(
              primary: argsInput,
              fallbackOf: () {
                final host = _tabForSession(target);
                handed = InteractiveCommandInput(
                  tools: host.tools,
                  commandLine: commandLine,
                  args: CommandArgs(args),
                  params: each.params,
                  locale: locale,
                );
                _setStore(_store.copyWith(runningCommand: each.id));
                _activeInput = handed;
                return handed!;
              },
            );
          } else {
            input = argsInput;
          }
          return CommandContext(
            session: target,
            args: CommandArgs(args),
            input: input,
            services: this,
            source: source,
            commandId: each.id,
          );
        },
      );
      _rememberResult(result);
      return result;
    } finally {
      handed?.cancel();
      if (identical(_activeInput, handed)) _activeInput = null;
      if (handed != null && _store.runningCommand == descriptor.id) {
        _setStore(_store.copyWith(runningCommand: null));
      }
    }
  }

  DocumentTab _tabForSession(DocumentSession session) {
    for (final tab in _hosts.values) {
      if (identical(tab.session, session)) return tab;
    }
    return activeDrawing ?? active!;
  }

  void _rememberResult(CommandResult result) {
    final change = result.transaction?.change;
    var created = change?.added ?? const <int>[];
    final modified = change?.modified ?? const <int>[];
    if (created.isEmpty) {
      created = _idsFromData(result.data);
    }
    if (created.isEmpty && modified.isEmpty) return;
    _setStore(
      _store.copyWith(
        lastCreatedIds: created.isNotEmpty
            ? List<int>.unmodifiable(created)
            : _store.lastCreatedIds,
        lastModifiedIds: modified.isNotEmpty
            ? List<int>.unmodifiable(modified)
            : _store.lastModifiedIds,
      ),
    );
  }

  static List<int> _idsFromData(Map<String, Object?>? data) {
    final raw = data?['ids'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is int) item else if (item is num) item.toInt(),
    ];
  }

  /// Executes a line typed at the command line.
  Future<CommandResult?> submitCommandLine(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      // Enter on an empty line repeats the last command, as AutoCAD does.
      final last = commands.lastCommandId;
      if (last == null) return null;
      return run(last);
    }
    final parsed = commands.parseCommandLine(text);
    if (parsed == null) return null;
    if (!parsed.isResolved) {
      commandLine.writeError('Unknown command: ${parsed.verb}');
      return CommandResult.failed('Unknown command: ${parsed.verb}');
    }
    return run(parsed.descriptor!.id, args: parsed.args);
  }

  void _report(CommandDescriptor descriptor, CommandResult result) {
    switch (result.status) {
      case CommandStatus.ok:
        if (result.message.isNotEmpty) commandLine.writeSuccess(result.message);
      case CommandStatus.cancelled:
        commandLine.write('*Cancel*', level: HistoryLevel.warning);
      case CommandStatus.failed:
        commandLine.writeError('${descriptor.title}: ${result.message}');
        notify('${descriptor.title} failed: ${result.message}', isError: true);
    }
  }

  // -------------------------------------------------------------------------
  // Drafting settings
  // -------------------------------------------------------------------------

  Set<SnapMode> _restoreSnapModes() {
    final saved = _drawing.snapModes;
    if (saved.isEmpty) return {...SnapMode.defaults};
    return {for (final name in saved) ?SnapMode.parse(name)};
  }

  void toggleSnapMode(SnapMode mode) {
    if (!snapEngine.modes.remove(mode)) snapEngine.modes.add(mode);
    _persistSnapModes();
    _syncDrafting();
  }

  void resetSnapModes() {
    snapEngine.modes = {...SnapMode.defaults};
    _persistSnapModes();
    _syncDrafting();
  }

  void _persistSnapModes() {
    _drawing.setSnapModes([for (final each in snapEngine.modes) each.name]);
  }

  void _syncDrafting() {
    _setStore(
      state.copyWith(
        snapEnabled: snapEngine.enabled,
        ortho: snapEngine.tracking.ortho,
        polar: snapEngine.tracking.polar,
        snapModes: [for (final mode in snapEngine.modes) mode.name],
      ),
    );
  }

  void setSnapEnabled(bool value) {
    snapEngine.enabled = value;
    _drawing.setSnapEnabled(value);
    _syncDrafting();
  }

  void setOrtho(bool value) {
    snapEngine.tracking = snapEngine.tracking.copyWith(ortho: value);
    _drawing.setOrtho(value);
    _syncDrafting();
  }

  void setPolar(bool value) {
    snapEngine.tracking = snapEngine.tracking.copyWith(polar: value);
    _drawing.setPolar(value);
    _syncDrafting();
  }

  void setShowGrid(bool value) {
    _drawing.setShowGrid(value);
    snapEngine.snapToGrid = value;
    final session = _store.active;
    if (session != null && session.showGrid != value) {
      _replaceSession(session.id, (record) => record.copyWith(showGrid: value));
      return;
    }
  }

  void setPolarIncrement(double radians) {
    snapEngine.tracking = snapEngine.tracking.copyWith(polarIncrement: radians);
    _drawing.setPolarIncrement(radians);
  }

  SelectionTool _selectionTool() {
    return SelectionTool.localized(
      idlePromptOf: () => l10nForLanguage(locale).prompt_idle_select,
      stretchPromptOf: () =>
          l10nForLanguage(locale).prompt_specify_stretch_point,
      selectedViewportPromptOf: () =>
          l10nForLanguage(locale).prompt_selected_viewport,
      describeObject: (entity) => l10nForLanguage(
        locale,
      ).prompt_selected_object(entity.displayId, entity.props.layer),
      describeCount: (count) =>
          l10nForLanguage(locale).prompt_objects_selected(count),
    );
  }

  // -------------------------------------------------------------------------
  // CommandServices
  // -------------------------------------------------------------------------

  @override
  void notify(String message, {bool isError = false}) {
    final notices = [
      ..._store.notices,
      NoticeModel(message, isError: isError, at: DateTime.now()),
    ];
    while (notices.length > 32) {
      notices.removeAt(0);
    }
    commandLine.write(
      message,
      level: isError ? HistoryLevel.error : HistoryLevel.normal,
    );
    _setStore(_store.copyWith(notices: notices));
  }

  void dismissNotice(NoticeModel notice) {
    _setStore(
      _store.copyWith(
        notices: [
          for (final each in _store.notices)
            if (each != notice) each,
        ],
      ),
    );
  }

  @override
  void zoomTo(Bounds2? bounds) {
    final tab = active;
    if (tab == null) return;
    if (bounds == null) {
      tab.viewport.zoomToExtents(tab.document);
      return;
    }
    tab.viewport.zoomTo(bounds);
  }

  @override
  void zoomBy(double factor) => active?.viewport.zoomAtCenter(factor);

  @override
  void panTo(Vec2 center) => active?.viewport.centerOn(center);

  @override
  void invalidate() => active?.invalidateAll();

  @override
  void revealPanel(String panelId) {
    if (!_panelReveals.isClosed) _panelReveals.add(panelId);
  }

  @override
  ShxFontTable get shxFonts => _shxFonts;

  /// Loads SHX from `FANCAD_FONT_PATH` and the drawing directory.
  ///
  /// Not called from the constructor: headless tests must not walk the disk.
  /// [active] reads [state], which is uninitialized until [build] returns, so
  /// skip it when no tab has been opened yet.
  Future<void> reloadShxFonts({String? drawingPath}) async {
    if (_disposed) return;
    _shxFonts = ShxFontCatalog.load(
      drawingPath: drawingPath ?? (_hosts.isEmpty ? null : active?.filePath),
    );
    for (final tab in _hosts.values) {
      tab.invalidateAll();
    }
  }

  /// Collects [drawing], or the front tab, into a [SessionSnapshot].
  ///
  /// The assistant may be bound to a pinned drawing that is not on screen.
  /// Do not bring that tab forward just to describe it.
  SessionSnapshot collectSessionSnapshot({DocumentTab? drawing}) {
    final tab = drawing ?? active;
    final document = tab?.document;
    final ids = tab?.selection.ids.toList() ?? const <int>[];
    final listed = <SelectedObjectHint>[];
    if (document != null) {
      for (final id in ids.take(SessionSnapshot.maxListed)) {
        final entity = document.entity(id);
        if (entity == null) continue;
        final box = document.boundsOfEntity(entity);
        listed.add(
          SelectedObjectHint(
            id: id,
            kind: entity.kind.name,
            layer: entity.props.layer,
            bounds: box.isEmpty
                ? null
                : [box.minX, box.minY, box.maxX, box.maxY],
          ),
        );
      }
    }

    ViewportHint? viewport;
    if (tab != null) {
      final view = tab.viewport.viewport;
      final box = view.visibleBounds;
      viewport = ViewportHint(
        centerX: view.center.x,
        centerY: view.center.y,
        scale: view.scale,
        visible: box.isEmpty ? null : [box.minX, box.minY, box.maxX, box.maxY],
      );
    }

    final modes = [for (final mode in snapEngine.modes) mode.name]..sort();
    return SessionSnapshot(
      drawingId: tab?.session.id,
      drawingTitle: tab?.title,
      drawingPath: tab?.filePath,
      selectionCount: ids.length,
      selection: listed,
      viewport: viewport,
      snapEnabled: snapEngine.enabled,
      snapModes: modes,
      ortho: snapEngine.tracking.ortho,
      polar: snapEngine.tracking.polar,
      showGrid: tab?.showGrid ?? true,
      runningCommand: runningCommand,
      prompt: commandLine.pending?.message,
      collectedPointCount: collectedPointCount,
      lastCreatedIds: [...lastCreatedIds.take(SessionSnapshot.maxResultIds)],
      lastModifiedIds: [...lastModifiedIds.take(SessionSnapshot.maxResultIds)],
    );
  }

  @override
  Map<String, Object?> describeView() {
    final tab = active;
    if (tab == null) return const {};
    final view = tab.viewport.viewport;
    final box = view.visibleBounds;
    return {
      'center': [view.center.x, view.center.y],
      'scale': view.scale,
      'size': [view.size.width, view.size.height],
      if (box.isNotEmpty) 'visible': [box.minX, box.minY, box.maxX, box.maxY],
    };
  }

  @override
  Future<bool> requestApproval(String title, String details) =>
      requestApprovalFor(title, details, const []);

  /// Asks for approval with the affected entities highlighted.
  ///
  /// With nobody listening — a headless run, a test, a window that has not
  /// mounted yet — the answer is no. An unanswerable question must not hang the
  /// command that asked it, and defaulting a destructive operation to "yes"
  /// because no one was watching would be worse than refusing.
  Future<bool> requestApprovalFor(
    String title,
    String details,
    List<int> highlightIds,
  ) {
    if (_approvals.isClosed || !_approvals.hasListener) {
      commandLine.write(
        'Declined without asking (no approval UI): $title',
        level: HistoryLevel.warning,
      );
      return Future.value(false);
    }
    final request = ApprovalRequestModel(
      title: title,
      details: details,
      highlightIds: highlightIds,
    );
    _setStore(_store.copyWith(approval: request));
    final pending = PendingApproval(request);
    _approvals.add(pending);
    return pending.decision.whenComplete(() {
      if (identical(_store.approval, request)) {
        _setStore(_store.copyWith(approval: null));
      }
    });
  }

  void dispose() => _teardown();

  void _teardown() {
    if (_disposed) return;
    _flashTimer?.cancel();
    _disposed = true;
    for (final tab in _hosts.values) {
      tab.removeListener(_onHostTick);
      ref.invalidate(documentTabNotifierProvider(tab.session.id));
    }
    for (final sub in _selectionReveals.values) {
      sub.cancel();
    }
    _selectionReveals.clear();
    _hosts.clear();
    if (!_approvals.isClosed) _approvals.close();
    if (!_panelReveals.isClosed) _panelReveals.close();
  }

  static bool _sameDrawingFile(String? existing, String incoming) {
    if (existing == null || existing.isEmpty) return false;
    if (existing == incoming) return true;
    return _fileIdentity(existing) == _fileIdentity(incoming);
  }

  /// The on-disk identity of [path], so `/tmp/a.dxf` and a symlink to it match.
  static String _fileIdentity(String path) {
    final file = File(path);
    try {
      if (file.existsSync()) {
        return file.resolveSymbolicLinksSync();
      }
    } on FileSystemException {
      // Missing files and dangling links still need a stable comparison key.
    }
    return p.normalize(file.absolute.path);
  }
}

/// The workspace service. Prefer [WorkspaceNotifier] at new call sites.
typedef Workspace = WorkspaceNotifier;

/// One open drawing, with everything that is per-tab rather than per-app.
///
/// A tab bundles the three controllers that have to agree about which drawing
/// is being looked at: the document session (content and undo), the viewport
/// (camera) and the tool controller (interaction). Keeping them together is
/// what makes switching tabs a single assignment rather than a resynchronisation
/// of three independent pieces of state.
///
/// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
/// listeners and must not write Riverpod state.
@Riverpod(keepAlive: true)
class DocumentTabNotifier extends _$DocumentTabNotifier implements Listenable {
  @override
  DocumentTabModel build(String sessionId) {
    ref.onDispose(_teardown);
    return const DocumentTabModel();
  }

  DocumentSession? _session;
  ViewportController? _viewport;
  ToolController? _tools;
  bool _attached = false;
  bool _tornDown = false;

  final TessellationCache tessellation = TessellationCache();
  final _TabTicks _ticks = _TabTicks();

  WorkspaceSessionModel _unbound = const WorkspaceSessionModel(id: '');
  WorkspaceSessionModel Function()? _readRecord;
  void Function(WorkspaceSessionModel Function(WorkspaceSessionModel))?
  _writeRecord;

  StreamSubscription<DocumentChange>? _changeSubscription;
  StreamSubscription<Set<int>>? _selectionSubscription;

  final List<String> _history = [];

  /// Set by the workbench so a document change can drop the right cached geometry.
  ///
  /// Picture recordings live on the canvas widget; tessellation lives on the
  /// tab so hover pick can share it. This hook is how a session change reaches
  /// the widget's picture cache without the tab holding a State.
  void Function(DocumentChange change)? onGeometryInvalidated;

  /// The most recent scene, for the canvas zoom readout's draw-call tooltip.
  RenderScene? lastScene;

  DocumentSession get session => _session!;
  ViewportController get viewport => _viewport!;
  ToolController get tools => _tools!;

  WorkspaceSessionModel get _record => _readRecord?.call() ?? _unbound;

  /// Wires the drawing session onto this family member.
  void attach({
    required DocumentSession session,
    SnapEngine? snapEngine,
    SelectionTool? selectionTool,
  }) {
    if (_attached) return;
    _attached = true;
    _session = session;
    _unbound = WorkspaceSessionModel(id: session.id);
    _viewport = ViewportController();
    _tools = ToolController(
      session: session,
      viewportProvider: () => viewport.viewport,
      snapEngine: snapEngine,
      tessellation: tessellation,
      onWrite: _history.add,
      onPrompt: (message) {
        setPrompt(message);
      },
    )..defaultTool = selectionTool ?? SelectionTool();

    _changeSubscription = session.changes.listen(_onDocumentChange);
    _selectionSubscription = session.selection.changes.listen((_) {
      _tick();
    });
    viewport.addListener(_tick);
    tools.addListener(_tick);
  }

  /// Binds this host to the workspace store record for [session].
  void bindStore({
    required WorkspaceSessionModel Function() read,
    required void Function(
      WorkspaceSessionModel Function(WorkspaceSessionModel),
    )
    write,
  }) {
    _readRecord = read;
    _writeRecord = write;
  }

  /// The file this tab was opened from, if any.
  String? get filePath => session.filePath;

  /// Import warnings, kept so the user can review them after the fact.
  List<String> get diagnostics => _record.diagnostics;

  /// A tab that shows the start screen instead of a drawing.
  ///
  /// The tab strip plus control opens one of these so New / Open can be
  /// chosen without inventing a leftover Drawing1.
  bool get isStartPage => _record.isStartPage;

  CadDocument get document => session.document;
  SelectionSet get selection => session.selection;
  UndoStack get history => session.history;

  String get title => session.title;
  bool get isDirty => session.isDirty;

  /// Turns a start tab into an empty drawing, keeping this tab's place.
  void promoteToDrawing({String? title}) {
    if (!isStartPage) return;
    if (title != null) session.title = title;
    _patch(
      (record) => record.copyWith(
        isStartPage: false,
        title: session.title,
        isDirty: session.isDirty,
      ),
    );
  }

  /// The transient prompt for the command line.
  String get prompt => state.prompt;

  /// Which layers are drawn, or null for all of them. Set by LAYISO.
  Set<String>? get isolatedLayers => _record.isolatedLayers;

  /// Whether the reference grid is drawn.
  bool get showGrid => _record.showGrid;

  void setPrompt(String message) {
    if (state.prompt == message) return;
    state = state.copyWith(prompt: message);
    _tick();
  }

  void setIsolatedLayers(Set<String>? layers) {
    _patch((record) => record.copyWith(isolatedLayers: layers));
  }

  void setShowGrid(bool value) {
    if (showGrid == value) return;
    _patch((record) => record.copyWith(showGrid: value));
  }

  void _patch(WorkspaceSessionModel Function(WorkspaceSessionModel) update) {
    final write = _writeRecord;
    if (write != null) {
      write(update);
      return;
    }
    _unbound = update(_unbound);
    _tick();
  }

  void noteScene(RenderScene scene) {
    lastScene = scene;
  }

  /// Records that the document has been written to [path].
  void markSaved(String path) {
    session.markSaved(path);
    _tick();
  }

  void _onDocumentChange(DocumentChange change) {
    onGeometryInvalidated?.call(change);
    _tick();
  }

  /// Refreshes everything that depends on document content, for changes the
  /// document itself does not report such as a layer visibility toggle.
  void invalidateAll() {
    onGeometryInvalidated?.call(const DocumentChange(tablesChanged: true));
    _tick();
  }

  void _tick() => _ticks.tick();

  @override
  void addListener(VoidCallback listener) => _ticks.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _ticks.removeListener(listener);

  void _teardown() {
    if (_tornDown) return;
    _tornDown = true;
    _changeSubscription?.cancel();
    _selectionSubscription?.cancel();
    _viewport?.removeListener(_tick);
    _tools?.removeListener(_tick);
    _tools?.dispose();
    _viewport?.dispose();
    _session?.dispose();
    _ticks.dispose();
  }
}

class _TabTicks extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// One open drawing. Prefer [DocumentTabNotifier] at new call sites.
typedef DocumentTab = DocumentTabNotifier;

/// A [CommandInput] that prompts a real user.
///
/// The important property is that a prompt is offered to the pointer and to the
/// keyboard *simultaneously*, and whichever answers first wins while the other
/// is torn down. That is what makes `LINE` feel right: the same prompt accepts a
/// click, `10,20`, `@50<30`, or Escape, and the command that issued it does not
/// know or care which happened.
class InteractiveCommandInput implements CommandInput {
  InteractiveCommandInput({
    required this.tools,
    required this.commandLine,
    required this.args,
    required List<ParamSpec> params,
    this.locale = 'en',
  }) : _params = params;

  final ToolController tools;
  final CommandLineController commandLine;
  final String locale;

  /// Arguments supplied up front, for example by the command line's own
  /// `line 0,0 10,10` form. A prompt whose value is already known is not shown.
  final CommandArgs args;

  final List<ParamSpec> _params;
  final Set<String> _consumed = {};

  bool _cancelled = false;

  /// The last point the user supplied, which relative coordinate entry and
  /// rubber banding are both measured from.
  Vec2? lastPoint;

  @override
  Vec2? get lastPick => lastPoint;

  PreviewBuilder? _preview;
  List<Vec2> _markers = const [];

  @override
  void setPreview(PreviewBuilder? builder) => _preview = builder;

  @override
  void setMarkers(List<Vec2> points) => _markers = points;

  /// Vertices collected so far, for the session snapshot.
  int get collectedPointCount => _markers.length;

  @override
  bool get isInteractive => true;

  @override
  bool get canHandOff => false;

  @override
  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    commandLine.cancelPending();
    tools.cancel();
  }

  /// The next declared parameter of one of [types] that has not been used yet.
  ParamSpec? _nextParam(Set<ParamType> types) {
    for (final param in _params) {
      if (_consumed.contains(param.name)) continue;
      if (!types.contains(param.type)) continue;
      return param;
    }
    return null;
  }

  /// A pre-supplied value for the next matching parameter, or null.
  Object? _preSupplied(Set<ParamType> types) {
    final param = _nextParam(types);
    if (param == null) return null;
    _consumed.add(param.name);
    return args[param.name] ?? param.defaultValue;
  }

  // -------------------------------------------------------------------------
  // Prompts
  // -------------------------------------------------------------------------

  @override
  Future<Vec2> point(String message, {Vec2? basePoint}) async {
    final result = await pointOrNull(message, basePoint: basePoint);
    if (result == null) throw const CommandCancelled();
    return result;
  }

  @override
  Future<Vec2?> pointOrNull(String message, {Vec2? basePoint}) async {
    final supplied = CommandArgs.parsePoint(_preSupplied({ParamType.point}));
    if (supplied != null) {
      lastPoint = supplied;
      return supplied;
    }

    final anchor = basePoint ?? lastPoint;
    final tool = PointPromptTool(
      message: message,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        accept: (raw) => CoordinateParser.parse(raw, base: anchor),
      ),
    );

    final resolved = await _race<Vec2>(
      fromPointer: () {
        tools.push(tool);
        return tool.result;
      },
      fromKeyboard: typed,
      convert: (value) => value is Vec2 ? value : null,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved != null) lastPoint = resolved;
    return resolved;
  }

  @override
  Future<PointOrKeyword?> pointOrKeyword(
    String message, {
    Vec2? basePoint,
    List<String> keywords = const [],
  }) async {
    final supplied = CommandArgs.parsePoint(_preSupplied({ParamType.point}));
    if (supplied != null) {
      lastPoint = supplied;
      return PointOrKeyword.point(supplied);
    }

    final anchor = basePoint ?? lastPoint;
    final label = keywords.isEmpty
        ? message
        : '$message [${keywords.join('/')}]';
    final tool = PointPromptTool(
      message: label,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        keywords: keywords,
        accept: (raw) {
          final matched = ArgsCommandInput.matchKeyword(raw, keywords);
          if (matched != null) return PointOrKeyword.keyword(matched);
          final point = CoordinateParser.parse(raw, base: anchor);
          return point == null ? null : PointOrKeyword.point(point);
        },
      ),
    );

    final resolved = await _race<PointOrKeyword>(
      fromPointer: () {
        tools.push(tool);
        return tool.result.then(PointOrKeyword.point);
      },
      fromKeyboard: typed,
      convert: (value) {
        if (value is PointOrKeyword) return value;
        if (value is Vec2) return PointOrKeyword.point(value);
        if (value is String) {
          final matched = ArgsCommandInput.matchKeyword(value, keywords);
          return matched == null ? null : PointOrKeyword.keyword(matched);
        }
        return null;
      },
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved != null && resolved.isPoint) lastPoint = resolved.point;
    return resolved;
  }

  @override
  Future<double> distance(String message, {Vec2? basePoint}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.distance, ParamType.number}),
    );
    if (supplied != null) return supplied;

    final anchor = basePoint ?? lastPoint;
    // A distance can be typed as a number or picked as a second point, which is
    // how a draughtsman actually specifies a radius or an offset.
    final tool = PointPromptTool(
      message: message,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        accept: (raw) {
          final direct = CoordinateParser.parseDistance(raw);
          if (direct != null) return direct;
          final asPoint = CoordinateParser.parse(raw, base: anchor);
          if (asPoint != null && anchor != null) {
            return anchor.distanceTo(asPoint);
          }
          return null;
        },
      ),
    );

    final resolved = await _race<double>(
      fromPointer: () {
        tools.push(tool);
        return tool.result.then((picked) {
          lastPoint = picked;
          return anchor == null ? picked.length : anchor.distanceTo(picked);
        });
      },
      fromKeyboard: typed,
      convert: _asDouble,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<double> angle(String message, {Vec2? basePoint}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.angle, ParamType.number}),
    );
    if (supplied != null) return supplied;

    final anchor = basePoint ?? lastPoint;
    final tool = PointPromptTool(
      message: message,
      anchor: anchor,
      preview: _preview,
      markers: _markers,
    );
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        accept: CoordinateParser.parseAngle,
      ),
    );

    final resolved = await _race<double>(
      fromPointer: () {
        tools.push(tool);
        return tool.result.then((picked) {
          lastPoint = picked;
          return anchor == null ? picked.angle : (picked - anchor).angle;
        });
      },
      fromKeyboard: typed,
      convert: _asDouble,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<double> number(String message, {double? defaultValue}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.number, ParamType.distance}),
    );
    if (supplied != null) return supplied;
    final label = defaultValue == null
        ? message
        : '$message <${_format(defaultValue)}>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        allowEmpty: defaultValue != null,
        accept: (raw) =>
            raw.isEmpty ? defaultValue : CoordinateParser.parseDistance(raw),
      ),
    );
    final resolved = _asDouble(value) ?? defaultValue;
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<int> integer(String message, {int? defaultValue}) async {
    final supplied = _asDouble(
      _preSupplied({ParamType.integer, ParamType.number}),
    );
    if (supplied != null) return supplied.round();
    final label = defaultValue == null ? message : '$message <$defaultValue>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        allowEmpty: defaultValue != null,
        accept: (raw) => raw.isEmpty ? defaultValue : int.tryParse(raw.trim()),
      ),
    );
    final resolved = value is int ? value : _asDouble(value)?.round();
    if (resolved == null) throw const CommandCancelled();
    return resolved;
  }

  @override
  Future<String> text(String message, {String? defaultValue}) async {
    final supplied = _preSupplied({
      ParamType.text,
      ParamType.layer,
      ParamType.block,
      ParamType.choice,
    });
    if (supplied != null && supplied.toString().isNotEmpty) {
      return supplied.toString();
    }
    final label = defaultValue == null || defaultValue.isEmpty
        ? message
        : '$message <$defaultValue>';
    final value = await commandLine.request(
      PendingEntry(
        message: label,
        completer: Completer<Object?>(),
        allowEmpty: defaultValue != null,
        accept: (raw) => raw.isEmpty ? defaultValue : raw,
      ),
    );
    if (value is! String) throw const CommandCancelled();
    return value;
  }

  @override
  Future<String> keyword(
    String message,
    List<String> options, {
    String? defaultOption,
  }) async {
    final supplied = _preSupplied({ParamType.choice, ParamType.text});
    if (supplied != null) {
      final matched = ArgsCommandInput.matchKeyword(
        supplied.toString(),
        options,
      );
      if (matched != null) return matched;
    }
    final label = defaultOption == null
        ? '$message [${options.join('/')}]'
        : '$message [${options.join('/')}] <$defaultOption>';
    PreviewHoldTool? hold;
    if (_preview != null || _markers.isNotEmpty) {
      hold = PreviewHoldTool(
        message: label,
        preview: _preview,
        markers: _markers,
      );
      tools.push(hold);
    }
    try {
      final value = await commandLine.request(
        PendingEntry(
          message: label,
          completer: Completer<Object?>(),
          keywords: options,
          allowEmpty: defaultOption != null,
          accept: (raw) => raw.isEmpty
              ? defaultOption
              : ArgsCommandInput.matchKeyword(raw, options),
        ),
      );
      if (value is! String) throw const CommandCancelled();
      return value;
    } finally {
      if (hold != null) tools.finishTool();
    }
  }

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    final supplied = _preSupplied({ParamType.boolean});
    if (supplied != null) {
      final parsed = CommandArgs({'v': supplied}).boolean('v');
      if (parsed != null) return parsed;
    }
    final answer = await keyword(message, const [
      'Yes',
      'No',
    ], defaultOption: defaultValue ? 'Yes' : 'No');
    return answer == 'Yes';
  }

  @override
  Future<List<int>> selection(
    String message, {
    bool useExistingSelection = true,
    bool single = false,
  }) async {
    final param = _nextParam({ParamType.selection, ParamType.entity});
    if (param != null) {
      _consumed.add(param.name);
      final ids = args.ids(param.name);
      if (ids != null && ids.isNotEmpty) return ids;
    }
    if (useExistingSelection && tools.selection.isNotEmpty) {
      return tools.selection.ids.toList();
    }

    final tool = SelectionPromptTool(
      message: message,
      single: single,
      formatPicked: (prompt, count) =>
          l10nForLanguage(locale).prompt_selection_found(prompt, count),
    );
    // Typed entry at a selection prompt means "all", "last" or "previous",
    // which are the three selection keywords worth supporting.
    final typed = commandLine.request(
      PendingEntry(
        message: message,
        completer: Completer<Object?>(),
        keywords: const ['All', 'Last'],
        accept: (raw) {
          final keyword = ArgsCommandInput.matchKeyword(raw, const [
            'All',
            'Last',
          ]);
          if (keyword == 'All') {
            return [
              for (final entity in tools.document.activeEntities) entity.id,
            ];
          }
          if (keyword == 'Last') {
            final entities = tools.document.activeEntities;
            return entities.isEmpty ? <int>[] : [entities.last.id];
          }
          return CommandArgs({'ids': raw}).ids('ids');
        },
      ),
    );

    final resolved = await _race<List<int>>(
      fromPointer: () {
        tools.push(tool);
        return tool.result;
      },
      fromKeyboard: typed,
      convert: (value) => value is List<int> ? value : null,
      onAbandonPointer: () => tools.cancel(),
    );
    if (resolved == null) throw const CommandCancelled();
    if (tool.lastClick != null) lastPoint = tool.lastClick;
    if (resolved.isNotEmpty) tools.selection.replace(resolved);
    return resolved;
  }

  @override
  Future<Bounds2> window(String message) async {
    final tool = WindowPromptTool(message: message);
    tools.push(tool);
    return tool.result;
  }

  @override
  void write(String message) => commandLine.write(message);

  @override
  void status(String message) => commandLine.setStatus(message);

  // -------------------------------------------------------------------------
  // Racing the pointer against the keyboard
  // -------------------------------------------------------------------------

  /// Awaits the first of two sources to produce a value.
  ///
  /// Both sources are always started, and the loser is always torn down. Doing
  /// this in one place matters: a leaked prompt tool would keep swallowing
  /// clicks after its command had finished, which is the kind of bug that makes
  /// an application feel haunted.
  Future<T?> _race<T>({
    required Future<T> Function() fromPointer,
    required Future<Object?> fromKeyboard,
    required T? Function(Object? value) convert,
    required void Function() onAbandonPointer,
  }) async {
    final pointer = fromPointer();
    // Errors on the losing branch are expected (they are how cancellation is
    // signalled) and must not surface as unhandled asynchronous errors.
    final pointerGuarded = pointer.then<_Outcome<T>>(
      _Outcome.value,
      onError: (Object error) => _Outcome<T>.error(error),
    );
    final keyboardGuarded = fromKeyboard.then<_Outcome<T>>(
      (value) => _Outcome.value(convert(value)),
      onError: (Object error) => _Outcome<T>.error(error),
    );

    final first = await Future.any([pointerGuarded, keyboardGuarded]);

    // Tear down whichever source did not win.
    onAbandonPointer();
    commandLine.cancelPending('Superseded');
    // Drain the loser so its error, if any, is observed.
    unawaited(pointerGuarded.then((_) {}));
    unawaited(keyboardGuarded.then((_) {}));

    if (first.hasError) {
      final error = first.error;
      if (error is CommandCancelled) {
        _cancelled = true;
        return null;
      }
      throw error!;
    }
    return first.value;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String _format(double value) =>
      value == value.roundToDouble() && value.abs() < 1e15
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(4);
}

/// A completed-or-failed result, so both branches of a race can be awaited
/// without either throwing before the other has been observed.
class _Outcome<T> {
  const _Outcome.value(this.value) : error = null;
  const _Outcome.error(this.error) : value = null;

  final T? value;
  final Object? error;

  bool get hasError => error != null;
}

/// Answers from [args] first, then hands the leftover prompt to a person.
///
/// This is how an assistant turn that omitted a point becomes a canvas pick
/// instead of a cancelled tool call.
class FallbackCommandInput implements CommandInput {
  FallbackCommandInput({required this.primary, required this.fallbackOf});

  final ArgsCommandInput primary;
  final CommandInput Function() fallbackOf;

  CommandInput? _fallback;
  var _answeredPointFromArgs = false;

  CommandInput get _next => _fallback ??= fallbackOf();

  Future<T> _orFallback<T>(Future<T> Function(CommandInput input) run) async {
    final live = _fallback;
    if (live != null) return run(live);
    try {
      return await run(primary);
    } on CommandCancelled {
      return run(_next);
    }
  }

  @override
  bool get isInteractive => _fallback?.isInteractive ?? false;

  @override
  bool get canHandOff => true;

  @override
  bool get isCancelled =>
      primary.isCancelled || (_fallback?.isCancelled ?? false);

  @override
  Vec2? get lastPick => _fallback?.lastPick ?? primary.lastPick;

  void cancel() {
    primary.cancel();
    final live = _fallback;
    if (live is InteractiveCommandInput) live.cancel();
  }

  @override
  Future<Vec2> point(String message, {Vec2? basePoint}) =>
      _orFallback((input) => input.point(message, basePoint: basePoint));

  @override
  Future<Vec2?> pointOrNull(String message, {Vec2? basePoint}) =>
      primary.pointOrNull(message, basePoint: basePoint);

  @override
  Future<PointOrKeyword?> pointOrKeyword(
    String message, {
    Vec2? basePoint,
    List<String> keywords = const [],
  }) async {
    if (_fallback != null) {
      return _fallback!.pointOrKeyword(
        message,
        basePoint: basePoint,
        keywords: keywords,
      );
    }
    try {
      final result = await primary.pointOrKeyword(
        message,
        basePoint: basePoint,
        keywords: keywords,
      );
      if (result != null) {
        _answeredPointFromArgs = true;
        return result;
      }
    } on CommandCancelled {
      return _next.pointOrKeyword(
        message,
        basePoint: basePoint,
        keywords: keywords,
      );
    }
    // LINE extra vertices after start/end from args: null means done.
    // PLINE with no points array: null means take over the crosshair.
    if (_answeredPointFromArgs) return null;
    return _next.pointOrKeyword(
      message,
      basePoint: basePoint,
      keywords: keywords,
    );
  }

  @override
  Future<double> distance(String message, {Vec2? basePoint}) =>
      _orFallback((input) => input.distance(message, basePoint: basePoint));

  @override
  Future<double> angle(String message, {Vec2? basePoint}) =>
      _orFallback((input) => input.angle(message, basePoint: basePoint));

  @override
  Future<double> number(String message, {double? defaultValue}) =>
      _orFallback((input) => input.number(message, defaultValue: defaultValue));

  @override
  Future<int> integer(String message, {int? defaultValue}) => _orFallback(
    (input) => input.integer(message, defaultValue: defaultValue),
  );

  @override
  Future<String> text(String message, {String? defaultValue}) =>
      _orFallback((input) => input.text(message, defaultValue: defaultValue));

  @override
  Future<String> keyword(
    String message,
    List<String> options, {
    String? defaultOption,
  }) => _orFallback(
    (input) => input.keyword(message, options, defaultOption: defaultOption),
  );

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      primary.confirm(message, defaultValue: defaultValue);

  @override
  Future<List<int>> selection(
    String message, {
    bool useExistingSelection = true,
    bool single = false,
  }) =>
      // Object identity stays on pins / explicit ids. A missing selection
      // must fail, not become a canvas pick of everything in view.
      primary.selection(
        message,
        useExistingSelection: useExistingSelection,
        single: single,
      );

  @override
  Future<Bounds2> window(String message) =>
      _orFallback((input) => input.window(message));

  @override
  void write(String message) {
    primary.write(message);
    _fallback?.write(message);
  }

  @override
  void status(String message) {
    primary.status(message);
    _fallback?.status(message);
  }

  @override
  void setPreview(PreviewBuilder? builder) {
    primary.setPreview(builder);
    _fallback?.setPreview(builder);
  }

  @override
  void setMarkers(List<Vec2> points) {
    primary.setMarkers(points);
    _fallback?.setMarkers(points);
  }
}

/// Discovers SHX files on disk and builds the table the scene builder strokes.
///
/// Core never searches the filesystem. The host only reads `FANCAD_FONT_PATH`
/// and fonts that travel with the drawing — not another CAD install.
class ShxFontCatalog {
  static const envPath = 'FANCAD_FONT_PATH';

  /// Folders checked from first to last. A later file of the same family
  /// wins, so a `fonts/` next to the drawing overrides `FANCAD_FONT_PATH`.
  static List<String> searchDirectories({
    String? drawingPath,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final dirs = <String>[];
    void add(String? path) {
      final trimmed = path?.trim() ?? '';
      if (trimmed.isEmpty) return;
      if (!dirs.contains(trimmed)) dirs.add(trimmed);
    }

    final extra = env[envPath];
    if (extra != null && extra.isNotEmpty) {
      final sep = Platform.isWindows ? ';' : ':';
      for (final part in extra.split(sep)) {
        add(part);
      }
    }

    final drawing = drawingPath?.trim() ?? '';
    if (drawing.isNotEmpty) {
      final dir = p.dirname(drawing);
      add(dir);
      add(p.join(dir, 'fonts'));
    }
    return dirs;
  }

  /// Parses every `.shx` in [directories], or the default search path.
  ///
  /// Empty or truncated files are skipped. Does not throw: a missing font
  /// must not prevent a drawing from opening.
  static ShxFontTable load({
    String? drawingPath,
    Map<String, String>? environment,
    Iterable<String>? directories,
  }) {
    final byFamily = <String, ShxFont>{};
    final dirs =
        directories ??
        searchDirectories(drawingPath: drawingPath, environment: environment);
    for (final dir in dirs) {
      final folder = Directory(dir);
      if (!folder.existsSync()) continue;
      try {
        for (final entity in folder.listSync(followLinks: false)) {
          if (entity is! File) continue;
          if (!entity.path.toLowerCase().endsWith('.shx')) continue;
          try {
            final font = ShxFont.parse(entity.readAsBytesSync());
            if (font.isEmpty) continue;
            final family = ShxFontTable.normalizeFamily(
              p.basename(entity.path),
            );
            if (family.isEmpty) continue;
            byFamily[family] = font;
          } catch (_) {}
        }
      } catch (_) {}
    }
    return ShxFontTable(byFamily);
  }
}

/// Collects [drawing], or the front tab, into a [SessionSnapshot].
///
/// The assistant may be bound to a pinned drawing that is not on screen.
/// Do not bring that tab forward just to describe it.
SessionSnapshot collectSessionSnapshot(
  Workspace workspace, {
  DocumentTab? drawing,
}) => workspace.collectSessionSnapshot(drawing: drawing);
