import 'dart:async';

import 'change.dart';
import 'document.dart';
import 'history.dart';

/// Raised when the user or the host cancels a running command.
///
/// The signal lives in the engine because tool prompts and command input both
/// need to abort the same future. The command layer owns the wording and the
/// policy; this type only carries the reason.
class CommandCancelled implements Exception {
  const CommandCancelled([this.reason = 'Cancelled']);

  final String reason;

  @override
  String toString() => 'CommandCancelled($reason)';
}

/// The current selection set for one document.
///
/// Selection is intentionally *not* stored on entities. Keeping it in a side
/// structure means selecting a thousand entities costs one set insertion each
/// instead of a thousand entity replacements and a thousand undo patches.
class SelectionSet {
  SelectionSet();

  final Set<int> _ids = <int>{};
  final Set<int> _viewports = <int>{};
  final StreamController<Set<int>> _controller =
      StreamController<Set<int>>.broadcast(sync: true);

  /// Grip index currently being dragged, keyed by entity id. Populated by the
  /// grip editing tool.
  final Map<int, int> activeGrips = {};

  Stream<Set<int>> get changes => _controller.stream;

  Set<int> get ids => Set.unmodifiable(_ids);

  /// Indices into [Layout.viewports] of the active paper tab.
  Set<int> get viewportIndices => Set.unmodifiable(_viewports);

  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty && _viewports.isEmpty;
  bool get isNotEmpty => !isEmpty;
  bool get isSingle => _ids.length == 1;

  /// The only selected id, or null when the selection is not a single entity.
  int? get single => _ids.length == 1 ? _ids.first : null;

  bool contains(int id) => _ids.contains(id);

  bool add(int id) {
    final cleared = _viewports.isNotEmpty;
    _viewports.clear();
    if (!_ids.add(id) && !cleared) return false;
    _notify();
    return true;
  }

  int addAll(Iterable<int> ids) {
    final cleared = _viewports.isNotEmpty;
    final before = _ids.length;
    _viewports.clear();
    _ids.addAll(ids);
    if (_ids.length == before && !cleared) return 0;
    _notify();
    return _ids.length - before;
  }

  bool remove(int id) {
    if (!_ids.remove(id)) return false;
    activeGrips.remove(id);
    _notify();
    return true;
  }

  int removeAll(Iterable<int> ids) {
    var count = 0;
    for (final id in ids) {
      if (_ids.remove(id)) {
        activeGrips.remove(id);
        count++;
      }
    }
    if (count > 0) _notify();
    return count;
  }

  bool toggle(int id) {
    _viewports.clear();
    final added = _ids.contains(id) ? !_ids.remove(id) : _ids.add(id);
    _notify();
    return added;
  }

  void replace(Iterable<int> ids) {
    final next = ids.toSet();
    if (next.length == _ids.length &&
        _ids.containsAll(next) &&
        _viewports.isEmpty) {
      return;
    }
    _ids
      ..clear()
      ..addAll(next);
    _viewports.clear();
    activeGrips.removeWhere((id, _) => !_ids.contains(id));
    _notify();
  }

  /// Selects paper-space viewport windows. Entity selection is cleared.
  void selectViewports(Iterable<int> indices) {
    final next = indices.toSet();
    if (next.length == _viewports.length &&
        _viewports.containsAll(next) &&
        _ids.isEmpty) {
      return;
    }
    _ids.clear();
    activeGrips.clear();
    _viewports
      ..clear()
      ..addAll(next);
    _notify();
  }

  void clear() {
    if (_ids.isEmpty && activeGrips.isEmpty && _viewports.isEmpty) return;
    _ids.clear();
    _viewports.clear();
    activeGrips.clear();
    _notify();
  }

  /// Drops ids that no longer exist, called after entities are erased.
  void prune(bool Function(int id) exists) {
    final stale = _ids.where((id) => !exists(id)).toList();
    if (stale.isEmpty) return;
    removeAll(stale);
  }

  /// Drops viewport indices that are no longer on the active layout.
  void pruneViewports(int viewportCount) {
    final stale = _viewports
        .where((index) => index < 0 || index >= viewportCount)
        .toList();
    if (stale.isEmpty) return;
    for (final index in stale) {
      _viewports.remove(index);
    }
    _notify();
  }

  void _notify() {
    if (!_controller.isClosed) _controller.add(ids);
  }

  void dispose() {
    _controller.close();
  }

  @override
  String toString() => 'SelectionSet(${_ids.length})';
}

/// One drawing's mutable engine state: document, undo history, selection and
/// the change stream.
///
/// Host metadata such as the tab title, file path and maximized viewport lives
/// on [CadEngine] or the host tab, not here. The unit a plugin or an AI turn
/// receives when it asks for "the active drawing" is still this session.
class DocumentSession {
  DocumentSession({
    required this.id,
    required this.document,
    UndoStack? history,
  }) : history = history ?? UndoStack();

  /// Stable session id, used by the plugin and AI APIs to address a document.
  final String id;

  final CadDocument document;
  final UndoStack history;
  final SelectionSet selection = SelectionSet();

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

  bool get isDirty => _dirty;

  /// Clears the dirty flag after the host wrote the document to disk.
  void markSaved() {
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
  String toString() => 'DocumentSession($id)';
}
