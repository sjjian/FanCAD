import 'package:meta/meta.dart';

import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../model/document.dart';
import '../model/entity.dart';
import '../model/style.dart';
import 'patch.dart';

/// A committed, invertible unit of work.
@immutable
class CommittedTransaction {
  const CommittedTransaction({
    required this.label,
    required this.source,
    required this.forward,
    required this.inverse,
    required this.change,
    required this.timestamp,
  });

  final String label;
  final ChangeSource source;

  /// Patches in application order, used for redo.
  final List<Patch> forward;

  /// Inverse patches in application order; undo walks them backwards.
  final List<Patch> inverse;

  final DocumentChange change;
  final DateTime timestamp;

  int get patchCount => forward.length;

  /// A short summary suitable for an undo menu or an AI turn receipt.
  String summarize() {
    if (forward.isEmpty) return label;
    final counts = <String, int>{};
    for (final patch in forward) {
      final key = patch.describe();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.length == 1) {
      final entry = counts.entries.first;
      return entry.value == 1 ? entry.key : '${entry.key} x${entry.value}';
    }
    return '$label (${forward.length} changes)';
  }

  @override
  String toString() => 'CommittedTransaction($label, $change)';
}

/// Accumulates document mutations, applying them eagerly.
///
/// Mutations take effect as they are recorded so that multi-step commands can
/// read back their own intermediate results. Each recorded patch also produces
/// its inverse, so [rollback] and undo work without snapshotting the drawing.
class Transaction {
  Transaction(
    this.document, {
    this.label = 'Edit',
    this.source = ChangeSource.user,
    this.enforceLayerLocks = true,
  });

  final CadDocument document;
  final String label;
  final ChangeSource source;

  /// When true, edits to entities on locked or frozen layers are refused and
  /// recorded in [skipped] instead of silently succeeding.
  final bool enforceLayerLocks;

  final List<Patch> _forward = [];
  final List<Patch> _inverse = [];

  /// Ids that were rejected because their layer is locked.
  final List<int> skipped = [];

  DocumentChange _change = const DocumentChange();
  bool _committed = false;

  bool get isEmpty => _forward.isEmpty;
  bool get isNotEmpty => _forward.isNotEmpty;
  bool get isCommitted => _committed;
  int get patchCount => _forward.length;
  DocumentChange get change => _change;

  void _run(Patch patch) {
    assert(!_committed, 'Transaction already committed');
    final inverse = patch.inverse(document);
    final change = patch.applyTo(document);
    _forward.add(patch);
    _inverse.add(inverse);
    _change = _change.merge(change);
  }

  bool _isEditable(int id) {
    if (!enforceLayerLocks) return true;
    final entity = document.entity(id);
    if (entity == null) return false;
    if (!document.isLayerEditable(entity.props.layer)) {
      skipped.add(id);
      return false;
    }
    return true;
  }

  /// Records an already-built patch.
  ///
  /// Used when a change set was produced elsewhere and then approved, such as
  /// an AI turn that was previewed before being applied.
  void applyRaw(Patch patch) => _run(patch);

  // -------------------------------------------------------------------------
  // Entities
  // -------------------------------------------------------------------------

  /// Adds [entity], returning the id it was stored under.
  int add(CadEntity entity, {String? blockName, int? index}) {
    final reuseId = entity.id > 0 && document.entity(entity.id) == null;
    final id = reuseId ? entity.id : document.allocateId();
    final stored = entity.id == id ? entity : entity.withId(id);
    _run(
      AddEntityPatch(
        entity: stored,
        blockName: blockName ?? document.currentBlockName,
        index: index,
      ),
    );
    return id;
  }

  /// Adds several entities, returning their ids in order.
  List<int> addAll(Iterable<CadEntity> entities, {String? blockName}) => [
    for (final entity in entities) add(entity, blockName: blockName),
  ];

  /// Erases an entity. Returns false when it is missing or locked.
  bool erase(int id) {
    if (!_isEditable(id)) return false;
    final entity = document.entity(id);
    final owner = document.ownerOf(id);
    if (entity == null || owner == null) return false;
    _run(
      RemoveEntityPatch(
        entity: entity,
        blockName: owner,
        index: document.entityIndexOf(id),
      ),
    );
    return true;
  }

  /// Erases several entities. Returns how many were actually removed.
  int eraseAll(Iterable<int> ids) {
    var count = 0;
    for (final id in ids.toList()) {
      if (erase(id)) count++;
    }
    return count;
  }

  /// Replaces an entity with [entity], matched by id.
  bool modify(CadEntity entity) {
    if (!_isEditable(entity.id)) return false;
    final before = document.entity(entity.id);
    if (before == null) return false;
    if (identical(before, entity)) return false;
    _run(ModifyEntityPatch(before: before, after: entity));
    return true;
  }

  /// Applies a geometric transform to an entity.
  bool transform(int id, Mat3 matrix) {
    if (matrix.isIdentity) return false;
    if (!_isEditable(id)) return false;
    final before = document.entity(id);
    if (before == null) return false;
    _run(
      ModifyEntityPatch(before: before, after: before.transformed(matrix)),
    );
    return true;
  }

  /// Applies a geometric transform to several entities.
  int transformAll(Iterable<int> ids, Mat3 matrix) {
    if (matrix.isIdentity) return 0;
    var count = 0;
    for (final id in ids.toList()) {
      if (transform(id, matrix)) count++;
    }
    return count;
  }

  /// Copies entities through [matrix], returning the new ids.
  List<int> duplicate(Iterable<int> ids, Mat3 matrix) {
    final created = <int>[];
    for (final id in ids.toList()) {
      final source = document.entity(id);
      if (source == null) continue;
      final owner = document.ownerOf(id) ?? document.currentBlockName;
      final copy = matrix.isIdentity
          ? source.withId(0)
          : source.transformed(matrix).withId(0);
      created.add(add(copy, blockName: owner));
    }
    return created;
  }

  /// Changes the common attributes of an entity.
  bool setProps(int id, EntityProps props) {
    if (!_isEditable(id)) return false;
    final before = document.entity(id);
    if (before == null || before.props == props) return false;
    _run(ModifyEntityPatch(before: before, after: before.withProps(props)));
    return true;
  }

  /// Moves entities to a different layer.
  int setLayerOf(Iterable<int> ids, String layer) {
    var count = 0;
    for (final id in ids.toList()) {
      final entity = document.entity(id);
      if (entity == null) continue;
      if (setProps(id, entity.props.copyWith(layer: layer))) count++;
    }
    return count;
  }

  /// Shows or hides entities without deleting them.
  int setVisibleOf(Iterable<int> ids, bool visible) {
    var count = 0;
    for (final id in ids.toList()) {
      final entity = document.entity(id);
      if (entity == null) continue;
      if (setProps(id, entity.props.copyWith(visible: visible))) count++;
    }
    return count;
  }

  /// Changes the linetype of entities.
  int setLineTypeOf(Iterable<int> ids, String lineType) {
    var count = 0;
    for (final id in ids.toList()) {
      final entity = document.entity(id);
      if (entity == null) continue;
      if (setProps(id, entity.props.copyWith(lineType: lineType))) count++;
    }
    return count;
  }

  /// Changes the lineweight of entities.
  int setLineWeightOf(Iterable<int> ids, int lineWeight) {
    var count = 0;
    for (final id in ids.toList()) {
      final entity = document.entity(id);
      if (entity == null) continue;
      if (setProps(id, entity.props.copyWith(lineWeight: lineWeight))) {
        count++;
      }
    }
    return count;
  }

  /// Changes the colour of entities.
  int setColorOf(Iterable<int> ids, CadColor color) {
    var count = 0;
    for (final id in ids.toList()) {
      final entity = document.entity(id);
      if (entity == null) continue;
      if (setProps(id, entity.props.copyWith(color: color))) count++;
    }
    return count;
  }

  /// Moves a grip of an entity to a new location.
  bool moveGrip(int id, int gripIndex, Vec2 target) {
    if (!_isEditable(id)) return false;
    final before = document.entity(id);
    if (before == null) return false;
    final after = before.withGrip(gripIndex, target);
    if (identical(after, before)) return false;
    _run(ModifyEntityPatch(before: before, after: after));
    return true;
  }

  // -------------------------------------------------------------------------
  // Tables
  // -------------------------------------------------------------------------

  void putLayer(LayerDef layer) => _run(PutLayerPatch(layer));

  /// Sets the layer new entities are created on.
  void setCurrentLayer(String name) {
    if (document.currentLayer == name) return;
    _run(CurrentLayerPatch(name, document.currentLayer));
  }

  /// Removes a layer. Refuses to remove layer `0` or a layer still in use.
  bool removeLayer(String name) {
    if (name == '0') return false;
    final existing = document.layer(name);
    if (existing == null) return false;
    final inUse = document.entities.any(
      (entity) => entity.props.layer == name,
    );
    if (inUse) return false;
    _run(RemoveLayerPatch(name, existing));
    return true;
  }

  void putLineType(LineTypeDef lineType) => _run(
    PutLineTypePatch(lineType, document.lineTypes[lineType.name]),
  );

  void putTextStyle(TextStyleDef style) =>
      _run(PutTextStylePatch(style, document.textStyles[style.name]));

  void putBlock(BlockRecord block) =>
      _run(PutBlockPatch(block, document.blocks[block.name]));

  bool renameBlock(String from, String to) {
    final existing = document.blocks[from];
    if (existing == null ||
        existing.isLayoutBlock ||
        existing.isAnonymous ||
        existing.isXref) {
      return false;
    }
    if (from == to || to.isEmpty) return false;
    final clash = document.blocks.keys.any(
      (name) =>
          name.toUpperCase() == to.toUpperCase() &&
          name.toUpperCase() != from.toUpperCase(),
    );
    if (clash) return false;
    _run(RenameBlockPatch(from, to));
    return true;
  }

  bool removeBlock(String name) {
    final existing = document.blocks[name];
    if (existing == null || existing.isLayoutBlock) return false;
    final entities = [
      for (final id in existing.entityIds) ?document.entity(id),
    ];
    _run(RemoveBlockPatch(name, existing, entities: entities));
    return true;
  }

  void setHeaderVariable(String key, String value) => _run(
    HeaderVariablePatch(key, value, document.headerVariables[key]),
  );

  void setActiveLayout(String name) =>
      _run(ActiveLayoutPatch(name, document.activeLayoutName));

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Finalizes the transaction. Returns null when nothing changed.
  CommittedTransaction? commit() {
    assert(!_committed, 'Transaction already committed');
    _committed = true;
    if (_forward.isEmpty) return null;
    return CommittedTransaction(
      label: label,
      source: source,
      forward: List.unmodifiable(_forward),
      inverse: List.unmodifiable(_inverse),
      change: _change,
      timestamp: DateTime.now(),
    );
  }

  /// Reverts everything recorded so far.
  DocumentChange rollback() {
    var change = const DocumentChange();
    for (var i = _inverse.length - 1; i >= 0; i--) {
      change = change.merge(_inverse[i].applyTo(document));
    }
    _forward.clear();
    _inverse.clear();
    _change = const DocumentChange();
    _committed = true;
    return change;
  }
}

/// Undo and redo history for one document.
class UndoStack {
  UndoStack({this.limit = 256});

  /// Maximum number of retained transactions.
  final int limit;

  final List<CommittedTransaction> _undo = [];
  final List<CommittedTransaction> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  String? get nextUndoLabel => _undo.isEmpty ? null : _undo.last.summarize();
  String? get nextRedoLabel => _redo.isEmpty ? null : _redo.last.summarize();

  List<CommittedTransaction> get undoEntries => List.unmodifiable(_undo);
  int get depth => _undo.length;

  /// Records a committed transaction. Importer changes are not undoable.
  void push(CommittedTransaction transaction) {
    if (transaction.source == ChangeSource.importer) return;
    _undo.add(transaction);
    _redo.clear();
    while (_undo.length > limit) {
      _undo.removeAt(0);
    }
  }

  /// Reverts the most recent transaction.
  DocumentChange? undo(CadDocument document) {
    if (_undo.isEmpty) return null;
    final entry = _undo.removeLast();
    var change = const DocumentChange();
    for (var i = entry.inverse.length - 1; i >= 0; i--) {
      change = change.merge(entry.inverse[i].applyTo(document));
    }
    _redo.add(entry);
    return change;
  }

  /// Re-applies the most recently undone transaction.
  DocumentChange? redo(CadDocument document) {
    if (_redo.isEmpty) return null;
    final entry = _redo.removeLast();
    var change = const DocumentChange();
    for (final patch in entry.forward) {
      change = change.merge(patch.applyTo(document));
    }
    _undo.add(entry);
    return change;
  }

  /// Merges the last [count] undo entries into one.
  ///
  /// One AI turn can run several commands. The user should undo the turn, not
  /// one tool call inside it, so the agent loop records each edit and then
  /// asks the stack to collapse them.
  void coalesceLast(int count, {String? label}) {
    if (count <= 1 || _undo.length < count) return;
    final entries = _undo.sublist(_undo.length - count);
    _undo.removeRange(_undo.length - count, _undo.length);
    var change = const DocumentChange();
    final forward = <Patch>[];
    final inverse = <Patch>[];
    for (final entry in entries) {
      forward.addAll(entry.forward);
      inverse.addAll(entry.inverse);
      change = change.merge(entry.change);
    }
    _undo.add(
      CommittedTransaction(
        label: label ?? entries.last.label,
        source: entries.last.source,
        forward: forward,
        inverse: inverse,
        change: change,
        timestamp: entries.first.timestamp,
      ),
    );
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
