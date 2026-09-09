import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditInsertCommand extends FanCadCommand {
  const EditInsertCommand();

  @override
  String get id => 'edit.insert';
  @override
  String get title => 'Insert';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['i', 'insert'];
  @override
  String get description =>
      'Places one or more references to a named block. Scale is uniform; '
      'rotation is in degrees. Pass a points array to stamp the same '
      'block at several locations.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Block to insert',
    ),
    ParamSpec.point('at', description: 'Insertion point'),
    ParamSpec(
      name: 'points',
      type: ParamType.points,
      description: 'Array of additional [x, y] insertion points',
      required: false,
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Uniform scale factor',
      required: false,
      defaultValue: 1,
    ),
    ParamSpec(
      name: 'rotation',
      type: ParamType.angle,
      description: 'Rotation in degrees',
      required: false,
      defaultValue: 0,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final requested = (await context.resolveText(
      'name',
      'INSERT  Enter block name:',
    )).trim();
    if (requested.isEmpty) {
      return const CommandResult.failed('INSERT needs a block name.');
    }
    final block = insertableBlock(context.document, requested);
    if (block == null) {
      return CommandResult.failed(
        'There is no insertable block named "$requested".',
      );
    }
    final scale = context.args.number('scale') ?? 1;
    if (scale.abs() < 1e-12) {
      return const CommandResult.failed('Insert scale cannot be zero.');
    }
    final rotation = (context.args.number('rotation') ?? 0) * math.pi / 180;
    var points = [
      ?context.args.point('at'),
      ...editPointList(context.args['points']),
    ];
    if (points.isEmpty) {
      context.input.setPreview(_insertMark);
      final at = await context.input.pointOrNull(
        'INSERT  Specify insertion point:',
      );
      context.input.setPreview(null);
      if (at == null) return const CommandResult.cancelled();
      points = [at];
      while (context.input.isInteractive) {
        context.input.setPreview(_insertMark);
        final next = await context.input.pointOrNull(
          'INSERT  Specify next insertion point (Escape to finish):',
        );
        if (next == null) break;
        points.add(next);
      }
      context.input.setPreview(null);
    }
    final layer = EntityProps(layer: context.document.currentLayer);
    final attributes = await attributeValues(context, block.name);
    final created = [
      for (final at in points)
        InsertEntity(
          id: 0,
          props: layer,
          blockName: block.name,
          position: at,
          scale: Vec2(scale, scale),
          rotation: rotation,
          attributes: attributes,
        ),
    ];
    final committed = context.edit('Insert', (transaction) {
      transaction.addAll(created);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was inserted.');
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Insert "${block.name}": ${committed.change.added.length} reference(s).',
      data: {'block': block.name, 'ids': committed.change.added},
      transaction: committed,
    );
  }
}

List<OverlayShape> _insertMark(Vec2 cursor) => [
  OverlayLine(cursor - const Vec2(2, 0), cursor + const Vec2(2, 0)),
  OverlayLine(cursor - const Vec2(0, 2), cursor + const Vec2(0, 2)),
];
