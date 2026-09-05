import 'package:fancad_core/fancad_core.dart';

/// Clipboard copy / paste, the family that moves geometry between drawings.
///
/// Distinct from [EditCommands] COPY, which only duplicates inside the active
/// document. The store is process-wide so Ctrl+C in one tab and Ctrl+V in
/// another share a clip without touching the OS clipboard.
class ClipboardCommands {
  const ClipboardCommands({required this.store});

  final DrawingClipboard store;

  static const String _category = 'Modify';

  List<CommandDescriptor> all() => [
    _copyClip(),
    _copyBase(),
    _cutClip(),
    _pasteClip(),
    _pasteOrig(),
    _pasteBlock(),
  ];

  CommandDescriptor _copyClip() => CommandDescriptor(
    id: 'edit.copyClip',
    title: 'Copy to Clipboard',
    category: _category,
    aliases: const ['copyclip'],
    icon: 'copy',
    defaultKeybinding: 'ctrl+c',
    description:
        'Copies the selected objects to the clipboard. The lower-left of '
        'the selection is the paste base. Paste in this drawing or another '
        'tab with PASTECLIP.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) => _capture(context, verb: 'COPYCLIP', cut: false),
  );

  CommandDescriptor _copyBase() => CommandDescriptor(
    id: 'edit.copyBase',
    title: 'Copy with Base Point',
    category: _category,
    aliases: const ['copybase'],
    defaultKeybinding: 'ctrl+shift+c',
    description:
        'Copies the selected objects to the clipboard with a base point you '
        'pick, so PASTECLIP can land that point on the insertion.',
    params: const [
      ParamSpec.point(
        'from',
        description: 'Base point stored on the clipboard',
      ),
      ParamSpec.selection('ids'),
    ],
    handler: (context) =>
        _capture(context, verb: 'COPYBASE', cut: false, askBase: true),
  );

  CommandDescriptor _cutClip() => CommandDescriptor(
    id: 'edit.cutClip',
    title: 'Cut',
    category: _category,
    aliases: const ['cutclip'],
    defaultKeybinding: 'ctrl+x',
    risk: CommandRisk.destructive,
    aiExposure: AiExposure.approvalRequired,
    description:
        'Copies the selected objects to the clipboard and deletes them from '
        'the drawing. Objects on a locked layer stay; the clipboard still '
        'holds a copy.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) => _capture(context, verb: 'CUTCLIP', cut: true),
  );

  CommandDescriptor _pasteClip() => CommandDescriptor(
    id: 'edit.pasteClip',
    title: 'Paste',
    category: _category,
    aliases: const ['pasteclip'],
    defaultKeybinding: 'ctrl+v',
    description:
        'Pastes clipboard objects at an insertion point. The stored base '
        'point lands on that click.',
    params: const [
      ParamSpec.point(
        'to',
        description: 'Insertion point for the clipboard base',
      ),
    ],
    handler: (context) => _paste(context, asBlock: false, original: false),
  );

  CommandDescriptor _pasteOrig() => CommandDescriptor(
    id: 'edit.pasteOrig',
    title: 'Paste to Original Coordinates',
    category: _category,
    aliases: const ['pasteorig'],
    description:
        'Pastes clipboard objects at the coordinates they had in the source '
        'drawing, without asking for an insertion point.',
    handler: (context) => _paste(context, asBlock: false, original: true),
  );

  CommandDescriptor _pasteBlock() => CommandDescriptor(
    id: 'edit.pasteBlock',
    title: 'Paste as Block',
    category: _category,
    aliases: const ['pasteblock'],
    defaultKeybinding: 'ctrl+shift+v',
    description:
        'Pastes clipboard objects as one anonymous block reference. The '
        'stored base point lands on the insertion point you pick.',
    params: const [
      ParamSpec.point('to', description: 'Insertion point for the new block'),
    ],
    handler: (context) => _paste(context, asBlock: true, original: false),
  );

  Future<CommandResult> _capture(
    CommandContext context, {
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

  Future<CommandResult> _paste(
    CommandContext context, {
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
        shapes.addAll(
          _outline(context.document, entity.transformed(transform)),
        );
      }
      return shapes;
    });
  }

  static List<OverlayShape> _outline(CadDocument document, CadEntity entity) {
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
}
