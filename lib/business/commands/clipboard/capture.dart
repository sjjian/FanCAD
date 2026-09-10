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
///
/// Outlines are flattened once. A large clip used to fall back to a crossing
/// box because emit-on-every-move stuttered; translating cached polylines
/// does not.
void _installPastePreview(CommandContext context, DrawingClip clip) {
  final base = clip.basePoint;
  final ghost = pastePreviewShapes(clip, styles: context.document);
  context.input.setPreview((cursor) {
    final delta = cursor - base;
    return [for (final shape in ghost) shape.translated(delta)];
  });
}

/// Clip geometry in source coordinates, including INSERT contents from the
/// clip rather than the destination drawing.
List<OverlayShape> pastePreviewShapes(
  DrawingClip clip, {
  StyleResolver styles = StyleResolver.passthrough,
}) {
  final emit = EmitContext(
    tolerance: 0.05,
    blocks: _ClipBlocks(clip),
    styles: styles,
  );
  final shapes = <OverlayShape>[];
  for (final entity in clip.entities) {
    shapes.addAll(_outline(emit, entity));
  }
  return shapes;
}

List<OverlayShape> _outline(EmitContext emit, CadEntity entity) {
  final sink = PolylineSink();
  entity.emit(emit, sink);
  return [
    for (var i = 0; i < sink.polylines.length; i++)
      OverlayPolyline([
        for (var j = 0; j + 1 < sink.polylines[i].length; j += 2)
          Vec2(sink.polylines[i][j], sink.polylines[i][j + 1]),
      ], closed: sink.closedFlags[i]),
  ];
}

/// Block table carried on the clip, so a paste into an empty drawing can
/// still flatten INSERTs that do not exist in the target yet.
class _ClipBlocks implements BlockLookup {
  _ClipBlocks(this.clip);

  final DrawingClip clip;
  final Map<String, Bounds2> _bounds = {};

  BlockRecord? _block(String name) {
    final direct = clip.blocks[name];
    if (direct != null) return direct;
    final needle = name.toUpperCase();
    for (final block in clip.blocks.values) {
      if (block.name.toUpperCase() == needle) return block;
    }
    return null;
  }

  @override
  List<int>? entityIdsOf(String blockName) => _block(blockName)?.entityIds;

  @override
  void emitBlock(String blockName, EmitContext context, GeometrySink sink) {
    final block = _block(blockName);
    if (block == null) return;
    final needsOffset = block.basePoint != const Vec2.zero();
    final effective = needsOffset
        ? context.descend(
            Mat3.translation(-block.basePoint.x, -block.basePoint.y),
            context.inheritedStyle,
          )
        : context;
    for (final id in block.entityIds) {
      final entity = clip.blockEntities[id];
      if (entity == null || !entity.props.visible) continue;
      entity.emit(effective, sink);
    }
  }

  @override
  Bounds2 boundsOf(String blockName) {
    final cached = _bounds[blockName];
    if (cached != null) return cached;
    final block = _block(blockName);
    if (block == null) return const Bounds2.empty();
    _bounds[blockName] = const Bounds2.empty();
    var box = const Bounds2.empty();
    for (final id in block.entityIds) {
      final entity = clip.blockEntities[id];
      if (entity == null || !entity.props.visible) continue;
      box = box.union(entity.computeBounds(blocks: this));
    }
    return _bounds[blockName] = box;
  }
}
