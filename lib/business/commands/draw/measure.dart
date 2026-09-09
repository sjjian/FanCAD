import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawMeasureCommand extends FanCadCommand {
  const DrawMeasureCommand();

  @override
  String get id => 'draw.measure';
  @override
  String get title => 'Measure';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['me', 'measure'];
  @override
  String get description =>
      'Places point markers at a fixed spacing along a line, polyline, '
      'arc or circle. Open objects start from the nearer end; a circle '
      'starts at the pick. Endpoints are not marked. A bulge is followed '
      'as its arc, not the chord.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The object to measure',
      required: false,
    ),
    ParamSpec(
      name: 'spacing',
      type: ParamType.distance,
      description: 'Distance between markers',
      min: 1e-9,
    ),
    ParamSpec(
      name: 'pick',
      type: ParamType.point,
      description: 'A point nearer the end to start from',
      required: false,
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
        'MEASURE  Select object to measure:',
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
        'Measure supports lines, polylines, arcs and circles.',
      );
    }

    final pick =
        context.args.point('pick') ??
        context.input.lastPick ??
        switch (target) {
          LineEntity(:final start) => start,
          PolylineEntity() => target.vertexAt(0),
          ArcEntity(:final startPoint) => startPoint,
          CircleEntity(:final center) => center,
          _ => const Vec2(0, 0),
        };
    List<Vec2> measured(double spacing) => switch (target) {
      LineEntity() => Construct.measureLine(target, spacing, pick),
      PolylineEntity() => Construct.measurePolyline(target, spacing, pick),
      ArcEntity() => Construct.measureArc(target, spacing, pick),
      CircleEntity() => Construct.measureCircle(target, spacing, pick),
      _ => const <Vec2>[],
    };
    if (context.args.number('spacing') == null) {
      context.input
        ..setMarkers([pick])
        ..setPreview((cursor) {
          final spacing = pick.distanceTo(cursor);
          if (spacing <= 0) return const <OverlayShape>[];
          return [for (final at in measured(spacing)) OverlayPoint(at)];
        });
    }
    final spacing =
        context.args.number('spacing') ??
        await context.input.distance(
          'MEASURE  Specify segment length:',
          basePoint: pick,
        );
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    if (spacing <= 0) {
      return const CommandResult.failed('The spacing must be positive.');
    }

    final points = measured(spacing);
    if (points.isEmpty) {
      return const CommandResult.failed(
        'The object is shorter than the spacing, so nothing was placed.',
      );
    }
    final layer = context.document.currentLayer;
    return commitDraw(context, 'Measure', [
      for (final at in points)
        PointEntity(
          id: 0,
          props: EntityProps(layer: layer),
          position: at,
        ),
    ]);
  }
}
