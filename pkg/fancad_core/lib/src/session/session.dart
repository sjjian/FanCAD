import 'dart:async';

import '../model/document.dart';
import '../txn/patch.dart';
import '../txn/transaction.dart';
import 'selection.dart';

/// One open drawing, together with everything that is per-document state:
/// undo history, selection, dirty flag and the change stream.
///
/// This is the object a plugin or an AI turn receives when it asks for "the
/// active drawing", and the unit the UI binds a document tab to.
class DocumentSession {
  DocumentSession({
    required this.id,
    required this.document,
    this.filePath,
    String? title,
    UndoStack? history,
  }) : history = history ?? UndoStack(),
       _title = title;

  /// Stable session id, used by the plugin and AI APIs to address a document.
  final String id;

  final CadDocument document;
  final UndoStack history;
  final SelectionSet selection = SelectionSet();

  /// Path on disk, or null for an unsaved drawing.
  String? filePath;

  String? _title;
  bool _dirty = false;

  final StreamController<DocumentChange> _changes =
      StreamController<DocumentChange>.broadcast(sync: true);
  final StreamController<CommittedTransaction> _transactions =
      StreamController<CommittedTransaction>.broadcast(sync: true);

  /// Emitted after every applied change, including undo and redo.
  Stream<DocumentChange> get changes => _changes.stream;

  /// Emitted only for newly committed transactions, not for undo or redo.
  /// The AI layer listens here to build its turn receipt.
  Stream<CommittedTransaction> get transactions => _transactions.stream;

  String get title {
    if (_title != null) return _title!;
    final path = filePath;
    if (path == null) return 'Drawing$id';
    final separator = path.contains(r'\') ? r'\' : '/';
    return path.split(separator).last;
  }

  set title(String value) => _title = value;

  bool get isDirty => _dirty;

  void markSaved(String path) {
    filePath = path;
    _dirty = false;
    _emit(const DocumentChange(tablesChanged: true));
  }

  /// Runs [body] inside a transaction and commits it.
  ///
  /// Returns null when the body made no changes, in which case nothing is
  /// pushed onto the undo stack. This is the single entry point every mutation
  /// path uses, so undo integrity does not depend on callers remembering to
  /// commit.
  CommittedTransaction? edit(
    String label,
    void Function(Transaction transaction) body, {
    ChangeSource source = ChangeSource.user,
    bool enforceLayerLocks = true,
  }) {
    final transaction = Transaction(
      document,
      label: label,
      source: source,
      enforceLayerLocks: enforceLayerLocks,
    );
    try {
      body(transaction);
    } catch (error) {
      // Leaving a half-applied edit behind would corrupt the drawing, so an
      // exception rolls the whole transaction back before rethrowing.
      transaction.rollback();
      rethrow;
    }
    final committed = transaction.commit();
    if (committed == null) return null;
    history.push(committed);
    if (source != ChangeSource.importer) _dirty = true;
    selection.prune((id) => document.entity(id) != null);
    selection.pruneViewports(document.activeLayout.viewports.length);
    _emit(committed.change);
    if (!_transactions.isClosed) _transactions.add(committed);
    return committed;
  }

  /// Applies a pre-built patch list, for example an approved AI change set.
  CommittedTransaction? applyPatches(
    String label,
    List<Patch> patches, {
    ChangeSource source = ChangeSource.ai,
  }) => edit(label, (transaction) {
    for (final patch in patches) {
      transaction.applyRaw(patch);
    }
  }, source: source);

  bool undo() {
    final change = history.undo(document);
    if (change == null) return false;
    _dirty = true;
    selection.prune((id) => document.entity(id) != null);
    selection.pruneViewports(document.activeLayout.viewports.length);
    _emit(change);
    return true;
  }

  bool redo() {
    final change = history.redo(document);
    if (change == null) return false;
    _dirty = true;
    selection.prune((id) => document.entity(id) != null);
    selection.pruneViewports(document.activeLayout.viewports.length);
    _emit(change);
    return true;
  }

  /// Notifies listeners without recording anything, for changes that live
  /// outside the document such as a layer visibility toggle in the UI.
  void notifyExternalChange(DocumentChange change) => _emit(change);

  void _emit(DocumentChange change) {
    if (change.isEmpty) return;
    if (!_changes.isClosed) _changes.add(change);
  }

  void dispose() {
    selection.dispose();
    _changes.close();
    _transactions.close();
  }

  @override
  String toString() => 'DocumentSession($id, $title)';
}
