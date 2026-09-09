import 'package:fancad_core/fancad_core.dart';

Future<CommandResult> captureClipboard(
  CommandContext context,
  DrawingClipboard store, {
  required String verb,
  required bool cut,
  bool askBase = false,
}) async {
  Vec2? base;
  if (askBase) {
    base = await context.resolvePoint('from', '$verb  Specify base point:');
  }
  final ids = await context.resolveSelection('ids', '$verb  Select objects:');
  if (ids.isEmpty) return const CommandResult.cancelled();
  base ??= DrawingClip.lowerLeftOf(context.document, ids);
  final clip = DrawingClip.extract(context.document, ids, basePoint: base);
  if (clip == null) return const CommandResult.cancelled();
  store.clip = clip;

  if (!cut) {
    return CommandResult.ok(
      message: '$verb: ${clip.entities.length} object(s) copied.',
      data: {'count': clip.entities.length},
    );
  }

  final committed = context.edit('Cut', (transaction) {
    transaction.eraseAll(ids);
  });
  final erased = committed?.change.removed.length ?? 0;
  if (committed == null) {
    return CommandResult.ok(
      message:
          '$verb: ${clip.entities.length} object(s) copied; '
          'nothing was deleted (the objects may be on a locked layer).',
      data: {'count': clip.entities.length, 'erased': 0},
    );
  }
  context.selection.clear();
  return CommandResult(
    status: CommandStatus.ok,
    message:
        '$verb: ${clip.entities.length} object(s) cut'
        '${erased == clip.entities.length ? '.' : ' ($erased deleted).'}',
    data: {'count': clip.entities.length, 'erased': erased},
    transaction: committed,
  );
}

Future<CommandResult> pasteClipboard(
  CommandContext context,
  DrawingClipboard store, {
  required bool asBlock,
  required bool original,
}) async {
  final clip = store.clip;
  if (clip == null || clip.isEmpty) {
    return const CommandResult.cancelled('The clipboard is empty.');
  }

  final Vec2 insertion;
  if (original) {
    insertion = clip.basePoint;
  } else {
    _installPastePreview(context, clip);
    insertion = await context.resolvePoint(
      'to',
      asBlock
          ? 'PASTEBLOCK  Specify insertion point:'
          : 'PASTECLIP  Specify insertion point:',
      basePoint: clip.basePoint,
    );
    context.input.setPreview(null);
  }

  final label = asBlock
      ? 'Paste as Block'
      : original
      ? 'Paste to Original Coordinates'
      : 'Paste';
  final committed = context.edit(label, (transaction) {
    clip.paste(transaction, insertion: insertion, asBlock: asBlock);
  });
  if (committed == null) {
    return const CommandResult.failed('Nothing was pasted.');
  }
  final added = committed.change.added;
  // Block contents are also "added"; selection should be the objects that
  // landed in the current space, not the internals of imported blocks.
  final space = context.document.currentBlockName;
  final visible = [
    for (final id in added)
      if (context.document.ownerOf(id) == space) id,
  ];
  context.selection.replace(visible.isEmpty ? added : visible);
  return CommandResult(
    status: CommandStatus.ok,
    message: asBlock
        ? 'Paste as block: 1 insert.'
        : 'Paste: ${visible.length} object(s).',
    data: {'ids': visible.isEmpty ? added : visible},
    transaction: committed,
  );
}

/// Ghost of the clip follows the cursor, offset from the stored base.
void _installPastePreview(CommandContext context, DrawingClip clip) {
  final base = clip.basePoint;
  context.input.setPreview((cursor) {
    final transform = Mat3.translation(cursor.x - base.x, cursor.y - base.y);
    final shapes = <OverlayShape>[];
    if (clip.entities.length > 200) {
      var box = const Bounds2.empty();
      for (final entity in clip.entities) {
        box = box.union(entity.computeBounds(blocks: context.document));
      }
      if (box.isNotEmpty) {
        final moved = box.transformed(transform);
        shapes.add(OverlayRect(moved.min, moved.max, crossing: true));
      }
      return shapes;
    }
    for (final entity in clip.entities) {
      shapes.addAll(_outline(context.document, entity.transformed(transform)));
    }
    return shapes;
  });
}

List<OverlayShape> _outline(CadDocument document, CadEntity entity) {
  final sink = PolylineSink();
  entity.emit(document.emitContext(tolerance: 0.05), sink);
  return [
    for (var i = 0; i < sink.polylines.length; i++)
      OverlayPolyline([
        for (var j = 0; j + 1 < sink.polylines[i].length; j += 2)
          Vec2(sink.polylines[i][j], sink.polylines[i][j + 1]),
      ], closed: sink.closedFlags[i]),
  ];
}
