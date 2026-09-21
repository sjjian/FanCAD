import 'dart:async';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';
import '../storage/drawing_settings.dart';
import 'command_line_model.dart';
import 'document_tab.dart';
import 'interactive_input.dart';
import 'shx_fonts.dart';

part 'workspace.freezed.dart';

/// A request for the user to approve a set of pending changes.
///
/// Raised as data rather than by showing a dialog directly, so the approval gate
/// works identically whether the caller is a plugin, an AI turn, or a test.
class ApprovalRequest {
  ApprovalRequest({
    required this.title,
    required this.details,
    this.highlightIds = const [],
  });

  final String title;
  final String details;

  /// Entities the change would touch, highlighted on the canvas while the user
  /// decides. Seeing what is about to change is most of what makes an approval
  /// gate worth having.
  final List<int> highlightIds;

  final Completer<bool> _completer = Completer<bool>();

  Future<bool> get decision => _completer.future;

  void approve() {
    if (!_completer.isCompleted) _completer.complete(true);
  }

  void reject() {
    if (!_completer.isCompleted) _completer.complete(false);
  }
}

/// A toast-style notification.
@freezed
abstract class Notice with _$Notice {
  const factory Notice(
    String message, {
    @Default(false) bool isError,
    required DateTime at,
  }) = _Notice;
}

/// The application state: open documents, the command registry, and the wiring
/// that lets a command reach the UI.
///
/// This is the object that owns the "one write path" guarantee. Every mutation —
/// from a toolbar button, a typed command, a plugin, or the model — is a
/// [CommandRegistry.run] call routed through here, so there is exactly one place
/// where a change can be observed, logged, undone or refused.
class Workspace extends ChangeNotifier implements CommandServices {
  Workspace({
    required this.commands,
    required this.importer,
    required this.drawing,
    CommandLineController? commandLine,
    this.localeOf,
  }) : commandLine = commandLine ?? CommandLineController() {
    snapEngine = SnapEngine(
      enabled: drawing.snapEnabled,
      snapToGrid: drawing.showGrid,
      modes: _restoreSnapModes(),
      tracking: TrackingSettings(
        ortho: drawing.ortho,
        polar: drawing.polar,
        polarIncrement: drawing.polarIncrement(),
      ),
    );
  }

  final CommandRegistry commands;
  final DrawingImporter importer;
  final DrawingSettings drawing;
  final CommandLineController commandLine;

  /// Current UI language. The shell supplies this so command prompts follow
  /// the setting without rebuilding the workspace.
  final String Function()? localeOf;

  @override
  String get locale {
    final value = localeOf?.call()?.trim() ?? '';
    return value.isEmpty ? 'en' : value;
  }

  List<String> get recentFiles => drawing.recentFiles;

  /// Snapping is application-wide rather than per-tab, because the toggles live
  /// on the canvas HUD and users expect them to stay put when switching tabs.
  late final SnapEngine snapEngine;

  /// Geometry clipboard shared by every open tab. COPYCLIP writes here;
  /// PASTECLIP in another drawing reads it. Not the OS clipboard.
  final DrawingClipboard clipboard = DrawingClipboard();

  ShxFontTable _shxFonts = const ShxFontTable();
  bool _disposed = false;

  final List<DocumentTab> _tabs = [];
  int _activeIndex = -1;
  int _nextSessionId = 1;
  final Map<DocumentTab, StreamSubscription<Set<int>>> _selectionReveals = {};

  final List<Notice> _notices = [];
  final StreamController<ApprovalRequest> _approvals =
      StreamController<ApprovalRequest>.broadcast();
  final StreamController<String> _panelReveals =
      StreamController<String>.broadcast();

  /// Set while a command is running, so the UI can refuse to start another.
  String? _runningCommand;

  /// The interactive input of the in-flight [run], when there is one.
  InteractiveCommandInput? _activeInput;

  /// Entities an approval dialog is asking about, drawn as highlights.
  List<int> _pendingHighlights = const [];

  /// A short-lived flash, merged into [pendingHighlightIds].
  List<int> _flashHighlights = const [];
  Timer? _flashTimer;

  /// Hovered chip / `#id` in the assistant pane. Cleared on pointer exit.
  List<int> _hoverHighlights = const [];

  /// Last geometry the human or the assistant created or changed.
  List<int> _lastCreatedIds = const [];
  List<int> _lastModifiedIds = const [];

  /// True while an assistant turn is in flight. Blocks new interactive verbs
  /// and drops in-flight canvas edits so the drawing stays read-only.
  bool _assistantBusy = false;

  /// The extension file `plugins.edit` asked the Re-Editor to open.
  ({String id, String relative})? _pluginEditorTarget;
  int _pluginEditorRequest = 0;

  List<DocumentTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;

  DocumentTab? get active => _activeIndex >= 0 && _activeIndex < _tabs.length
      ? _tabs[_activeIndex]
      : null;

  /// The active tab when it is a real drawing, not the start screen.
  DocumentTab? get activeDrawing {
    final tab = active;
    if (tab == null || tab.isStartPage) return null;
    return tab;
  }

  bool get hasDocument => activeDrawing != null;

  List<Notice> get notices => List.unmodifiable(_notices);

  /// Fires when something asks the user to approve a change.
  Stream<ApprovalRequest> get approvals => _approvals.stream;

  /// Fires when a command asks for a panel to be brought forward.
  Stream<String> get panelReveals => _panelReveals.stream;

  String? get runningCommand => _runningCommand;
  bool get isBusy => _runningCommand != null;
  bool get assistantBusy => _assistantBusy;

  List<int> get lastCreatedIds => _lastCreatedIds;
  List<int> get lastModifiedIds => _lastModifiedIds;

  /// Points collected by the in-flight interactive command.
  int get collectedPointCount => _activeInput?.collectedPointCount ?? 0;

  /// Entities the canvas should highlight while an approval is pending.
  List<int> get pendingHighlightIds => [
    ..._pendingHighlights,
    ..._flashHighlights,
    ..._hoverHighlights,
  ];

  ({String id, String relative})? get pluginEditorTarget => _pluginEditorTarget;
  int get pluginEditorRequest => _pluginEditorRequest;

  void setPendingHighlights(List<int> ids) {
    _pendingHighlights = List.unmodifiable(ids);
    notifyListeners();
  }

  /// Pulses [ids] on the canvas, then clears them so they do not stick.
  void flashHighlights(List<int> ids) {
    _flashTimer?.cancel();
    _flashHighlights = List.unmodifiable(ids);
    notifyListeners();
    if (ids.isEmpty) return;
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      _flashHighlights = const [];
      notifyListeners();
    });
  }

  /// Holds [ids] while the pointer is over a chip or `#id` in chat.
  void setHoverHighlights(List<int> ids) {
    if (_sameIds(_hoverHighlights, ids)) return;
    _hoverHighlights = List.unmodifiable(ids);
    notifyListeners();
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
    if (_assistantBusy == value) return;
    _assistantBusy = value;
    if (value) {
      for (final tab in _tabs) {
        tab.tools.cancelGesture();
      }
    }
    notifyListeners();
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
      notifyListeners();
      return current;
    }
    final session = DocumentSession(
      id: '${_nextSessionId++}',
      document: document ?? CadDocument(),
      title: title,
    );
    final tab = _adopt(
      DocumentTab(
        session: session,
        snapEngine: snapEngine,
        selectionTool: _selectionTool(),
      ),
    );
    _discardIdleStartPages();
    return tab;
  }

  /// Opens the start screen in a tab, or brings an existing one forward.
  DocumentTab openStartTab() {
    for (var i = 0; i < _tabs.length; i++) {
      if (!_tabs[i].isStartPage) continue;
      activate(i);
      return _tabs[i];
    }
    return _adopt(
      DocumentTab(
        session: DocumentSession(
          id: '${_nextSessionId++}',
          document: CadDocument(),
        ),
        snapEngine: snapEngine,
        selectionTool: _selectionTool(),
        isStartPage: true,
      ),
    );
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
    for (var i = 0; i < _tabs.length; i++) {
      if (_sameDrawingFile(_tabs[i].filePath, target)) {
        activate(i);
        _discardIdleStartPages();
        return _tabs[i];
      }
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
        DocumentTab(
          session: session,
          snapEngine: snapEngine,
          filePath: stored,
          diagnostics: result.diagnostics,
          selectionTool: _selectionTool(),
        ),
      );
      tab.viewport.zoomToExtents(result.document);
      drawing.pushRecent(stored);
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
      drawing.pushRecent(written);
      if (outcome.usedFallback && outcome.plan.reason.isNotEmpty) {
        notify(outcome.plan.reason);
      }
      notifyListeners();
      return written;
    } catch (error) {
      notify('Could not save $target: $error', isError: true);
      return null;
    }
  }

  DocumentTab _adopt(DocumentTab tab) {
    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    tab.setShowGrid(drawing.showGrid);
    tab.addListener(notifyListeners);
    // A pick that names objects brings Properties forward so the left pane
    // matches what is on the canvas, instead of staying on Layers.
    _selectionReveals[tab] = tab.session.selection.changes.listen((ids) {
      if (ids.isEmpty || !identical(tab, active)) return;
      revealPanel('properties');
    });
    notifyListeners();
    return tab;
  }

  void activate(int index) {
    if (index < 0 || index >= _tabs.length || index == _activeIndex) return;
    _activeIndex = index;
    snapEngine.snapToGrid = _tabs[index].showGrid;
    notifyListeners();
  }

  void activateTab(DocumentTab tab) => activate(_tabs.indexOf(tab));

  /// Open drawing for [selector], or the active tab when [selector] is empty.
  ///
  /// Matches session id, then file path, then a unique title. Duplicate titles
  /// are not a match — use the id from [listOpenDrawings].
  DocumentTab? findDrawing(String? selector) {
    final key = selector?.trim() ?? '';
    if (key.isEmpty) return activeDrawing;

    for (final tab in _tabs) {
      if (tab.isStartPage) continue;
      if (tab.session.id == key) return tab;
    }
    for (final tab in _tabs) {
      if (tab.isStartPage) continue;
      if (_sameDrawingFile(tab.filePath, key)) return tab;
    }
    DocumentTab? titled;
    var matches = 0;
    for (final tab in _tabs) {
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
      for (final tab in _tabs)
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

  List<Map<String, Object?>> listOpenDrawings() {
    final current = activeDrawing;
    return [
      for (final tab in _tabs)
        if (!tab.isStartPage)
          {
            'id': tab.session.id,
            'title': tab.title,
            'path': tab.filePath,
            'dirty': tab.isDirty,
            'active': identical(tab, current),
            'entityCount': tab.document.entityCount,
            'activeLayout': tab.document.activeLayoutName,
          },
    ];
  }

  DocumentTab? tabForSession(DocumentSession session) {
    final index = indexOfSession(session);
    if (index < 0) return null;
    return _tabs[index];
  }

  int indexOfSession(DocumentSession session) {
    for (var i = 0; i < _tabs.length; i++) {
      if (identical(_tabs[i].session, session)) return i;
    }
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].session.id == session.id) return i;
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
  void clearRecentFiles() {
    drawing.setRecentFiles(const []);
    notifyListeners();
  }

  /// Drops recent paths whose files are gone, so the File menu and empty
  /// workspace stop offering drawings that cannot be opened.
  int pruneMissingRecentFiles() {
    final recent = drawing.recentFiles;
    final kept = [
      for (final path in recent)
        if (File(path).existsSync()) path,
    ];
    if (kept.length == recent.length) return 0;
    drawing.setRecentFiles(kept);
    notifyListeners();
    return recent.length - kept.length;
  }

  void _dropRecent(String path) {
    final identity = _fileIdentity(path);
    final recent = drawing.recentFiles;
    final kept = [
      for (final item in recent)
        if (_fileIdentity(item) != identity) item,
    ];
    if (kept.length == recent.length) return;
    drawing.setRecentFiles(kept);
    notifyListeners();
  }

  /// Closes a tab. Returns false when the caller should ask about unsaved
  /// changes first.
  bool closeTab(int index, {bool force = false}) {
    if (index < 0 || index >= _tabs.length) return true;
    final tab = _tabs[index];
    if (tab.isDirty && !force) return false;
    _tabs.removeAt(index);
    _selectionReveals.remove(tab)?.cancel();
    tab.removeListener(notifyListeners);
    tab.dispose();
    if (_tabs.isEmpty) {
      _activeIndex = -1;
    } else if (index < _activeIndex) {
      // A tab to the left disappeared; the active document did not move, so
      // its index has to follow it. Leaving the number alone would activate
      // whatever slid into this slot — usually the neighbour, not the drawing
      // the user was still looking at.
      _activeIndex -= 1;
    } else if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    }
    notifyListeners();
    return true;
  }

  void _discardIdleStartPages() {
    final keep = activeDrawing;
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (!_tabs[i].isStartPage) continue;
      if (identical(_tabs[i], keep)) continue;
      closeTab(i, force: true);
    }
  }

  /// Closes every drawing except [keep], using the same Save / Don't save /
  /// Cancel path a single tab close uses.
  Future<bool> closeOtherTabs(DocumentTab keep) async {
    while (true) {
      DocumentTab? next;
      for (final tab in _tabs) {
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
    while (_tabs.isNotEmpty) {
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
    if (_assistantBusy && !_isHostCommand(descriptor.id)) {
      final message =
          'The assistant is working. Stop it before starting a command.';
      commandLine.writeError(message);
      return CommandResult.failed(message);
    }
    if (_runningCommand != null) {
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
                  DocumentTab(
                    session: DocumentSession(
                      id: 'transient',
                      document: CadDocument(),
                    ),
                    snapEngine: snapEngine,
                    selectionTool: _selectionTool(),
                  ))
            : newDocument(title: 'Drawing1'));
    _runningCommand = descriptor.id;
    notifyListeners();

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
      _runningCommand = null;
      notifyListeners();
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
    if (tab != null && tab.viewport.revertInteraction()) {
      notifyListeners();
      return;
    }
    if (tab != null && tab.tools.cancelGesture()) {
      notifyListeners();
      return;
    }
    if (commandLine.isAwaitingInput) {
      commandLine.cancelPending();
    } else {
      tab?.tools.cancel();
    }
    notifyListeners();
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
        _runningCommand != null &&
        descriptor.risk != CommandRisk.readOnly) {
      return CommandResult.failed(
        '$_runningCommand is running. Stop it or wait before changing '
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
                _runningCommand = each.id;
                _activeInput = handed;
                notifyListeners();
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
      if (handed != null && _runningCommand == descriptor.id) {
        _runningCommand = null;
        notifyListeners();
      }
    }
  }

  DocumentTab _tabForSession(DocumentSession session) {
    for (final tab in _tabs) {
      if (identical(tab.session, session)) return tab;
    }
    return activeDrawing ?? active!;
  }

  void _rememberResult(CommandResult result) {
    final change = result.transaction?.change;
    var created = change?.added ?? const <int>[];
    var modified = change?.modified ?? const <int>[];
    if (created.isEmpty) {
      created = _idsFromData(result.data);
    }
    if (created.isEmpty && modified.isEmpty) return;
    if (created.isNotEmpty) {
      _lastCreatedIds = List.unmodifiable(created);
    }
    if (modified.isNotEmpty) {
      _lastModifiedIds = List.unmodifiable(modified);
    }
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
    final saved = drawing.snapModes;
    if (saved.isEmpty) return {...SnapMode.defaults};
    return {for (final name in saved) ?SnapMode.parse(name)};
  }

  void toggleSnapMode(SnapMode mode) {
    if (!snapEngine.modes.remove(mode)) snapEngine.modes.add(mode);
    _persistSnapModes();
    notifyListeners();
  }

  void resetSnapModes() {
    snapEngine.modes = {...SnapMode.defaults};
    _persistSnapModes();
    notifyListeners();
  }

  void _persistSnapModes() {
    drawing.setSnapModes([for (final each in snapEngine.modes) each.name]);
  }

  void setSnapEnabled(bool value) {
    snapEngine.enabled = value;
    drawing.setSnapEnabled(value);
    notifyListeners();
  }

  void setOrtho(bool value) {
    snapEngine.tracking = snapEngine.tracking.copyWith(ortho: value);
    drawing.setOrtho(value);
    notifyListeners();
  }

  void setPolar(bool value) {
    snapEngine.tracking = snapEngine.tracking.copyWith(polar: value);
    drawing.setPolar(value);
    notifyListeners();
  }

  void setShowGrid(bool value) {
    drawing.setShowGrid(value);
    active?.setShowGrid(value);
    snapEngine.snapToGrid = value;
    notifyListeners();
  }

  void setPolarIncrement(double radians) {
    snapEngine.tracking = snapEngine.tracking.copyWith(polarIncrement: radians);
    drawing.setPolarIncrement(radians);
    notifyListeners();
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
    _notices.add(Notice(message, isError: isError, at: DateTime.now()));
    while (_notices.length > 32) {
      _notices.removeAt(0);
    }
    commandLine.write(
      message,
      level: isError ? HistoryLevel.error : HistoryLevel.normal,
    );
    notifyListeners();
  }

  void dismissNotice(Notice notice) {
    _notices.remove(notice);
    notifyListeners();
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
  Future<void> reloadShxFonts({String? drawingPath}) async {
    if (_disposed) return;
    _shxFonts = ShxFontCatalog.load(
      drawingPath: drawingPath ?? active?.filePath,
    );
    for (final tab in _tabs) {
      tab.invalidateAll();
    }
    notifyListeners();
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

  /// Opens [relative] of extension [id] in the Re-Editor and brings that panel
  /// forward. The editor watches [pluginEditorRequest] so a second edit of the
  /// same file still reloads it.
  void openPluginEditor(String id, String relative) {
    _pluginEditorTarget = (id: id, relative: relative);
    _pluginEditorRequest += 1;
    revealPanel('editor');
    notifyListeners();
  }

  @override
  Future<bool> requestApproval(String title, String details) =>
      requestApprovalFor(title, details, const []);

  /// Asks for approval with the affected entities highlighted.
  ///
  /// With nobody listening — a headless run, a test, a shell that has not
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
    final request = ApprovalRequest(
      title: title,
      details: details,
      highlightIds: highlightIds,
    );
    _approvals.add(request);
    return request.decision;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _disposed = true;
    for (final tab in _tabs) {
      tab.removeListener(notifyListeners);
      tab.dispose();
    }
    for (final sub in _selectionReveals.values) {
      sub.cancel();
    }
    _selectionReveals.clear();
    _tabs.clear();
    _approvals.close();
    _panelReveals.close();
    commandLine.dispose();
    super.dispose();
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
