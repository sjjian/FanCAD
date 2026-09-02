import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/foundation.dart';

/// One open drawing, with everything that is per-tab rather than per-app.
///
/// A tab bundles the three controllers that have to agree about which drawing
/// is being looked at: the document session (content and undo), the viewport
/// (camera) and the tool controller (interaction). Keeping them together is
/// what makes switching tabs a single assignment rather than a resynchronisation
/// of three independent pieces of state.
class DocumentTab extends ChangeNotifier {
  DocumentTab({
    required this.session,
    SnapEngine? snapEngine,
    this.filePath,
    this.diagnostics = const [],
  }) : viewport = ViewportController() {
    tools = ToolController(
      session: session,
      viewportProvider: () => viewport.viewport,
      snapEngine: snapEngine,
      onWrite: _history.add,
      onPrompt: (message) {
        _prompt = message;
        notifyListeners();
      },
    )..defaultTool = SelectionTool();

    _changeSubscription = session.changes.listen(_onDocumentChange);
    _selectionSubscription = session.selection.changes.listen((_) {
      notifyListeners();
    });
    viewport.addListener(notifyListeners);
    tools.addListener(notifyListeners);
  }

  final DocumentSession session;
  final ViewportController viewport;
  late final ToolController tools;

  /// The file this tab was opened from, if any.
  String? filePath;

  /// Import warnings, kept so the user can review them after the fact.
  final List<String> diagnostics;

  final List<String> _history = [];
  String _prompt = '';

  StreamSubscription<DocumentChange>? _changeSubscription;
  StreamSubscription<Set<int>>? _selectionSubscription;

  /// Set by the shell so a document change can drop the right cached geometry.
  ///
  /// The canvas owns its tessellation cache, so the tab cannot invalidate it
  /// directly; this hook is how the two are connected without the tab holding a
  /// reference to a widget.
  void Function(DocumentChange change)? onGeometryInvalidated;

  /// The most recent scene, for the canvas zoom readout's draw-call tooltip.
  RenderScene? lastScene;

  CadDocument get document => session.document;
  SelectionSet get selection => session.selection;
  UndoStack get history => session.history;

  String get title => session.title;
  bool get isDirty => session.isDirty;

  /// The transient prompt for the command line.
  String get prompt => _prompt;

  /// Which layers are drawn, or null for all of them. Set by LAYISO.
  Set<String>? isolatedLayers;

  /// Whether the reference grid is drawn.
  bool showGrid = true;

  void setPrompt(String message) {
    if (_prompt == message) return;
    _prompt = message;
    notifyListeners();
  }

  void setIsolatedLayers(Set<String>? layers) {
    isolatedLayers = layers;
    notifyListeners();
  }

  void setShowGrid(bool value) {
    if (showGrid == value) return;
    showGrid = value;
    notifyListeners();
  }

  void noteScene(RenderScene scene) {
    lastScene = scene;
  }

  /// Records that the document has been written to [path].
  void markSaved(String path) {
    filePath = path;
    session.markSaved(path);
    notifyListeners();
  }

  void _onDocumentChange(DocumentChange change) {
    onGeometryInvalidated?.call(change);
    notifyListeners();
  }

  /// Refreshes everything that depends on document content, for changes the
  /// document itself does not report such as a layer visibility toggle.
  void invalidateAll() {
    onGeometryInvalidated?.call(const DocumentChange(tablesChanged: true));
    notifyListeners();
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    _selectionSubscription?.cancel();
    viewport.removeListener(notifyListeners);
    tools.removeListener(notifyListeners);
    tools.dispose();
    viewport.dispose();
    session.dispose();
    super.dispose();
  }
}
