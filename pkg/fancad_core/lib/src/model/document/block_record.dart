import 'package:freezed_annotation/freezed_annotation.dart';

import '../../geometry/vector.dart';

part 'block_record.freezed.dart';

/// A block definition: a named, reusable collection of entities.
@freezed
abstract class BlockRecord with _$BlockRecord {
  const BlockRecord._();

  const factory BlockRecord({
    required String name,
    @Default(Vec2.zero()) Vec2 basePoint,
    @Default([]) List<int> entityIds,

    /// True for `*Model_Space` and `*Paper_Space*`, which are containers rather
    /// than insertable blocks.
    @Default(false) bool isLayoutBlock,

    /// True for generated blocks such as the `*D` dimension geometry blocks and
    /// `*U` hatch blocks, which are hidden from the block picker.
    @Default(false) bool isAnonymous,
    @Default('') String description,

    /// Non-empty when this block is an external reference.
    @Default('') String xrefPath,
  }) = _BlockRecord;

  bool get isXref => xrefPath.isNotEmpty;

  @override
  String toString() => 'BlockRecord($name, ${entityIds.length} entities)';
}
