import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawDivideCommand extends FanCadCommand {
  const DrawDivideCommand();

  @override
  String get id => 'draw.divide';
  @override
  String get title => 'Divide';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['div', 'divide'];
  @override
  String get description =>
      'Places point markers that split a line, polyline, arc or circle '
      'into equal segments. Open objects leave the endpoints unmarked; '
      'a circle or closed polyline places a marker at every interval. '
      'A bulge is followed as its arc, not the chord.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The object to divide',
      required: false,
    ),
    ParamSpec(
      name: 'segments',
      type: ParamType.integer,
      description: 'Number of equal segments, at least 2',
      min: 2,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final supplied = context.args.integer('target');
    final int targetId;
    if (supplied != null) {
      targetId = supplied;
    } else {
      context.selection.clear();
      final picked = await context.input.selection(
        'DIVIDE  Select object to divide:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      targetId = picked.first;
    }

    final target = context.document.entity(targetId);
    if (target is! LineEntity &&
        target is! PolylineEntity &&
        target is! ArcEntity &&
        target is! CircleEntity) {
      return const CommandResult.failed(
        'Divide supports lines, polylines, arcs and circles.',
      );
    }

    final segments =
        context.args.integer('segments') ??
        await context.input.integer(
          'DIVIDE  Enter the number of segments:',
          defaultValue: 2,
        );
    if (segments < 2) {
      return const CommandResult.failed(
        'A division needs at least two segments.',
      );
    }

    final points = switch (target) {
      LineEntity() => Construct.divideLine(target, segments),
      PolylineEntity() => Construct.dividePolyline(target, segments),
      ArcEntity() => Construct.divideArc(target, segments),
      CircleEntity() => Construct.divideCircle(target, segments),
      _ => const <Vec2>[],
    };
    if (points.isEmpty) {
      return const CommandResult.failed('Nothing to place.');
    }
    if (!await acceptPointPlacement(
      context,
      'DIVIDE  Place ${points.length} point(s)?',
      points,
    )) {
      return const CommandResult.cancelled();
    }
    final layer = context.document.currentLayer;
    return commitDraw(context, 'Divide', [
      for (final at in points)
        PointEntity(
          id: 0,
          props: EntityProps(layer: layer),
          position: at,
        ),
    ]);
  }
}
