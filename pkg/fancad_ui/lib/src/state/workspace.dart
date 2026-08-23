import 'dart:async';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../workbench/command_line_model.dart';
import '../workbench/interactive_input.dart';
import 'document_tab.dart';
import 'settings.dart';

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
@immutable
class Notice {
  const Notice(this.message, {this.isError = false, required this.at});

  final String message;
  final bool isError;
  final DateTime at;
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
    required this.settings,
    CommandLineController? commandLine,
  }) : commandLine = commandLine ?? CommandLineController() {
    snapEngine = SnapEngine(
      enabled: settings.getBool(SettingsKeys.snapEnabled, fallback: true),
      modes: _restoreSnapModes(),
      tracking: TrackingSettings(
        ortho: settings.getBool(SettingsKeys.orthoMode),
        polar: settings.getBool(SettingsKeys.polarMode, fallback: true),
        polarIncrement: settings.getDouble(
          SettingsKeys.polarIncrement,
          fallback: 0.7853981633974483,
        ),
      ),
    );
  }

  final CommandRegistry commands;
  final DrawingImporter importer;
  final SettingsStore settings;
  final CommandLineController commandLine;

  /// Snapping is application-wide rather than per-tab, because the toggles live
  /// in the status bar and users expect them to stay put when switching tabs.
  late final SnapEngine snapEngine;

  final List<DocumentTab> _tabs = [];
  int _activeIndex = -1;
  int _nextSessionId = 1;

  final List<Notice> _notices = [];
  final StreamController<ApprovalRequest> _approvals =
      StreamController<ApprovalRequest>.broadcast();
  final StreamController<String> _panelReveals =
      StreamController<String>.broadcast();

  /// Set while a command is running, so the UI can refuse to start another.
  String? _runningCommand;

  /// Entities an approval dialog is asking about, drawn as highlights.
  List<int> _pendingHighlights = const [];

  /// The extension file `plugins.edit` asked the Re-Editor to open.
  ({String id, String relative})? _pluginEditorTarget;
  int _pluginEditorRequest = 0;

  List<DocumentTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;

  DocumentTab? get active => _activeIndex >= 0 && _activeIndex < _tabs.length
      ? _tabs[_activeIndex]
      : null;

  bool get hasDocument => active != null;

  List<Notice> get notices => List.unmodifiable(_notices);

  /// Fires when something asks the user to approve a change.
  Stream<ApprovalRequest> get approvals => _approvals.stream;

  /// Fires when a command asks for a panel to be brought forward.
  Stream<String> get panelReveals => _panelReveals.stream;

  String? get runningCommand => _runningCommand;
  bool get isBusy => _runningCommand != null;

  /// Entities the canvas should highlight while an approval is pending.
  List<int> get pendingHighlightIds => _pendingHighlights;

  ({String id, String relative})? get pluginEditorTarget => _pluginEditorTarget;
  int get pluginEditorRequest => _pluginEditorRequest;

  void setPendingHighlights(List<int> ids) {
    _pendingHighlights = List.unmodifiable(ids);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------------

  /// Creates an empty drawing and makes it active.
  DocumentTab newDocument({String? title, CadDocument? document}) {
    final session = DocumentSession(
      id: '${_nextSessionId++}',
      document: document ?? CadDocument(),
      title: title,
    );
    return _adopt(DocumentTab(session: session, snapEngine: snapEngine));
  }

  /// Opens [path], reporting failures as notices rather than exceptions.
  Future<DocumentTab?> openFile(String path) async {
    final target = path.trim();
    if (target.isEmpty) {
      notify('There is no file to open.', isError: true);
      return null;
    }
    if (!File(target).existsSync()) {
      _dropRecent(target);
      notify('$target is missing and was removed from Recent.', isError: true);
      return null;
    }
    // An already-open file is activated rather than opened twice; two tabs onto
    // one file with independent undo stacks is a data-loss trap. Compare the
    // resolved file, so a symlink or a `./` in the path is not a second tab.
    for (var i = 0; i < _tabs.length; i++) {
      if (_sameDrawingFile(_tabs[i].filePath, target)) {
        activate(i);
        return _tabs[i];
      }
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
        ),
      );
      tab.viewport.zoomToExtents(result.document);
      settings.pushRecent(SettingsKeys.recentFiles, stored);
      commandLine.writeSuccess(
        'Opened ${result.entityCount} entities in '
        '${result.totalTime.inMilliseconds} ms'
        '${result.fromCache ? ' (from cache)' : ''}.',
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
    final tab = active;
    if (tab == null) {
      notify('There is no drawing to save.', isError: true);
      return null;
    }
    final target = (path ?? tab.filePath)?.trim();
    if (target == null || target.isEmpty) {
      notify('There is no path to save to.', isError: true);
      return null;
    }

    try {
      final outcome = await importer.save(target, tab.document);
      final written = _fileIdentity(outcome.path);
      tab.markSaved(written);
      settings.pushRecent(SettingsKeys.recentFiles, written);
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
    tab.setShowGrid(settings.getBool(SettingsKeys.showGrid, fallback: true));
    tab.addListener(notifyListeners);
    notifyListeners();
    return tab;
  }

  void activate(int index) {
    if (index < 0 || index >= _tabs.length || index == _activeIndex) return;
    _activeIndex = index;
    notifyListeners();
  }

  void activateTab(DocumentTab tab) => activate(_tabs.indexOf(tab));

  /// Drops the recent-files list. Missing paths otherwise stay in the File
  /// menu and on the empty workspace until the user restarts.
  void clearRecentFiles() {
    settings.set(SettingsKeys.recentFiles, <String>[]);
    notifyListeners();
  }

  /// Drops recent paths whose files are gone, so the File menu and empty
  /// workspace stop offering drawings that cannot be opened.
  int pruneMissingRecentFiles() {
    final recent = settings.getStringList(SettingsKeys.recentFiles);
    final kept = [
      for (final path in recent)
        if (File(path).existsSync()) path,
    ];
    if (kept.length == recent.length) return 0;
    settings.set(SettingsKeys.recentFiles, kept);
    notifyListeners();
    return recent.length - kept.length;
  }

  void _dropRecent(String path) {
    final identity = _fileIdentity(path);
    final recent = settings.getStringList(SettingsKeys.recentFiles);
    final kept = [
      for (final item in recent)
        if (_fileIdentity(item) != identity) item,
    ];
    if (kept.length == recent.length) return;
    settings.set(SettingsKeys.recentFiles, kept);
    notifyListeners();
  }

  /// Closes a tab. Returns false when the caller should ask about unsaved
  /// changes first.
  bool closeTab(int index, {bool force = false}) {
    if (index < 0 || index >= _tabs.length) return true;
    final tab = _tabs[index];
    if (tab.isDirty && !force) return false;
    _tabs.removeAt(index);
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
    if (_runningCommand != null) {
      // Starting a new command cancels the old one, which is the behaviour
      // every CAD user already has in their fingers.
      commandLine.cancelPending('Superseded by $idOrAlias');
      active?.tools.cancel();
    }
    if (active == null) {
      final message = _missingDocumentMessage(descriptor.id);
      if (message != null) {
        commandLine.writeError(message);
        return CommandResult.failed(message);
      }
    }
    // File commands that create or replace the document must not leave a
    // leftover blank tab behind if the user cancels the picker.
    final tab =
        active ??
        (_isHostFileCommand(descriptor.id)
            ? DocumentTab(
                session: DocumentSession(
                  id: 'transient',
                  document: CadDocument(),
                ),
                snapEngine: snapEngine,
              )
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
          );
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
      return result;
    } finally {
      input?.cancel();
      _runningCommand = null;
      notifyListeners();
    }
  }

  static bool _isHostFileCommand(String id) =>
      id == 'file.open' || id == 'file.openRecent' || id == 'file.new';

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
  /// Escape has to mean the same thing everywhere — abandon the current command
  /// and clear the selection — so it is one method rather than a behaviour each
  /// widget reimplements.
  void cancelActive() {
    final tab = active;
    if (commandLine.isAwaitingInput) {
      commandLine.cancelPending();
    } else if (tab != null && tab.tools.isPrompting) {
      tab.tools.cancel();
    } else if (tab != null && tab.selection.isNotEmpty) {
      tab.selection.clear();
    } else {
      tab?.tools.cancel();
    }
    notifyListeners();
  }

  /// Runs a command non-interactively from a supplied argument map.
  ///
  /// This is the path plugins and AI tool calls take: identical command
  /// implementations, but every prompt is answered from [args] and an
  /// unanswerable prompt is an error instead of a hang.
  Future<CommandResult> runHeadless(
    String idOrAlias, {
    Map<String, Object?> args = const {},
    ChangeSource source = ChangeSource.plugin,
    DocumentSession? session,
    void Function(String message)? log,
  }) async {
    final descriptor = commands.find(idOrAlias);
    if (descriptor == null) {
      return CommandResult.failed('Unknown command: $idOrAlias');
    }
    final target = session ?? active?.session;
    if (target == null) {
      return CommandResult.failed('No drawing is open');
    }
    return commands.run(
      descriptor.id,
      args: args,
      source: source,
      contextBuilder: (each) => CommandContext(
        session: target,
        args: CommandArgs(args),
        input: ArgsCommandInput(
          args: CommandArgs(args),
          params: each.params,
          selection: target.selection,
          log: log ?? commandLine.write,
        ),
        services: this,
        source: source,
        commandId: each.id,
      ),
    );
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
    final saved = settings.getStringList(SettingsKeys.snapModes);
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
    settings.set(SettingsKeys.snapModes, [
      for (final each in snapEngine.modes) each.name,
    ]);
  }

  void setSnapEnabled(bool value) {
    snapEngine.enabled = value;
    settings.set(SettingsKeys.snapEnabled, value);
    notifyListeners();
  }

  void setOrtho(bool value) {
    snapEngine.tracking = snapEngine.tracking.copyWith(ortho: value);
    settings.set(SettingsKeys.orthoMode, value);
    notifyListeners();
  }

  void setPolar(bool value) {
    snapEngine.tracking = snapEngine.tracking.copyWith(polar: value);
    settings.set(SettingsKeys.polarMode, value);
    notifyListeners();
  }

  void setShowGrid(bool value) {
    settings.set(SettingsKeys.showGrid, value);
    active?.setShowGrid(value);
    notifyListeners();
  }

  void setPolarIncrement(double radians) {
    snapEngine.tracking = snapEngine.tracking.copyWith(polarIncrement: radians);
    settings.set(SettingsKeys.polarIncrement, radians);
    notifyListeners();
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
    for (final tab in _tabs) {
      tab.removeListener(notifyListeners);
      tab.dispose();
    }
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
