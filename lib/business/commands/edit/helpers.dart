import 'package:fancad_core/fancad_core.dart';

List<Vec2> editPointList(Object? value) => CommandArgs.parsePoints(value);

Future<Map<String, String>> attributeValues(
  CommandContext context,
  String blockName,
) async {
  final attributes = <String, String>{};
  for (final def in context.document.attdefsOf(blockName)) {
    if (!def.asksOnInsert) {
      if (def.defaultValue.isNotEmpty) attributes[def.tag] = def.defaultValue;
      continue;
    }
    final provided = context.args.text(def.tag);
    if (provided != null) {
      attributes[def.tag] = provided;
      continue;
    }
    if (!context.input.isInteractive) {
      if (def.defaultValue.isNotEmpty) attributes[def.tag] = def.defaultValue;
      continue;
    }
    attributes[def.tag] = await context.input.text(
      'INSERT  ${def.prompt.isEmpty ? def.tag : def.prompt}:',
      defaultValue: def.defaultValue,
    );
  }
  return attributes;
}

BlockRecord? insertableBlock(CadDocument document, String name) {
  final key = name.toUpperCase();
  for (final block in document.insertableBlocks) {
    if (block.name.toUpperCase() == key) return block;
  }
  return null;
}

// -------------------------------------------------------------------------
// Shared implementations
// -------------------------------------------------------------------------

/// The two-point transform commands: move and mirror-style operations.
Future<CommandResult> editTransform(
  CommandContext context, {
  required String label,
  required String verb,
  required bool copy,
  required Mat3 Function(Vec2 from, Vec2 to) matrix,
}) async {
  final ids = await context.resolveSelection('ids', '$verb  Select objects:');
  if (ids.isEmpty) return const CommandResult.cancelled();
  final from = await context.resolvePoint('from', '$verb  Specify base point:');
  installTransformPreview(context, ids, from, (cursor) => matrix(from, cursor));
  final to = await context.resolvePoint(
    'to',
    '$verb  Specify second point:',
    basePoint: from,
  );
  context.input.setPreview(null);
  return applyEditTransform(context, label, ids, matrix(from, to), copy: copy);
}

CommandResult applyEditTransform(
  CommandContext context,
  String label,
  List<int> ids,
  Mat3 matrix, {
  required bool copy,
}) {
  if (matrix.isIdentity) {
    return const CommandResult.cancelled('The transform is a no-op.');
  }
  final committed = context.edit(label, (transaction) {
    if (copy) {
      transaction.duplicate(ids, matrix);
    } else {
      transaction.transformAll(ids, matrix);
    }
  });
  if (committed == null) {
    return CommandResult.failed(
      '$label affected nothing; the objects may be on a locked layer.',
    );
  }
  if (copy) context.selection.replace(committed.change.added);
  return CommandResult(
    status: CommandStatus.ok,
    message: '$label: ${ids.length} object(s).',
    data: {if (copy) 'ids': committed.change.added},
    transaction: committed,
  );
}

/// Shows the selection as it will look once the transform is applied.
///
/// Past a few hundred entities the outlines cost more than the edit itself, so
/// the bounding box stands in for them. That threshold is the difference
/// between a preview that helps and one that makes the drag stutter.
void installTransformPreview(
  CommandContext context,
  List<int> ids,
  Vec2 base,
  Mat3 Function(Vec2 cursor) matrix, {
  List<OverlayShape> Function(Vec2 cursor)? extra,
}) {
  context.input.setPreview((cursor) {
    final transform = matrix(cursor);
    final shapes = <OverlayShape>[
      OverlayLine(base, cursor),
      ...?extra?.call(cursor),
    ];
    if (ids.length > 200) {
      var box = const Bounds2.empty();
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity != null) {
          box = box.union(context.document.boundsOfEntity(entity));
        }
      }
      if (box.isNotEmpty) {
        final moved = box.transformed(transform);
        shapes.add(OverlayRect(moved.min, moved.max, crossing: true));
      }
      return shapes;
    }
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      shapes.addAll(
        editOutline(context.document, entity.transformed(transform)),
      );
    }
    return shapes;
  });
}

/// Flattens an entity into overlay polylines, for previews.
List<OverlayShape> editOutline(
  CadDocument document,
  CadEntity entity, {
  double tolerance = 0.05,
}) {
  final sink = PolylineSink();
  entity.emit(document.emitContext(tolerance: tolerance), sink);
  return [
    for (var i = 0; i < sink.polylines.length; i++)
      OverlayPolyline([
        for (var j = 0; j + 1 < sink.polylines[i].length; j += 2)
          Vec2(sink.polylines[i][j], sink.polylines[i][j + 1]),
      ], closed: sink.closedFlags[i]),
  ];
}
