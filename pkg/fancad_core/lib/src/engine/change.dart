import 'package:freezed_annotation/freezed_annotation.dart';

part 'change.freezed.dart';

/// The result of applying a change to the document, describing exactly which
/// entities moved so that the renderer and the spatial index can update
/// incrementally instead of rebuilding.
@freezed
abstract class DocumentChange with _$DocumentChange {
  const DocumentChange._();

  const factory DocumentChange({
    @Default([]) List<int> added,
    @Default([]) List<int> removed,
    @Default([]) List<int> modified,

    /// A symbol table (layers, line types, styles) changed, so resolved styles
    /// must be recomputed even for untouched entities.
    @Default(false) bool tablesChanged,

    /// Blocks or layouts changed, so any cached block geometry is stale.
    @Default(false) bool structureChanged,
  }) = _DocumentChange;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      modified.isEmpty &&
      !tablesChanged &&
      !structureChanged;

  bool get isNotEmpty => !isEmpty;

  /// Whether a full regeneration is cheaper than a targeted update.
  bool get requiresFullRegeneration => tablesChanged || structureChanged;

  DocumentChange merge(DocumentChange other) => DocumentChange(
    added: [...added, ...other.added],
    removed: [...removed, ...other.removed],
    modified: [...modified, ...other.modified],
    tablesChanged: tablesChanged || other.tablesChanged,
    structureChanged: structureChanged || other.structureChanged,
  );

  @override
  String toString() =>
      'DocumentChange(+${added.length} -${removed.length} '
      '~${modified.length}${tablesChanged ? ' tables' : ''}'
      '${structureChanged ? ' structure' : ''})';
}
