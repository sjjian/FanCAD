import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawCircleTtrCommand extends FanCadCommand {
  const DrawCircleTtrCommand();

  @override
  String get id => 'draw.circleTtr';
  @override
  String get title => 'Circle (Tan Tan Radius)';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ttr', 'circlettr'];
  @override
  String get description =>
      'Draws a circle of a given radius tangent to two lines, circles '
      'or arcs. The pick on each object chooses the side (and, for a '
      'circle, external versus internal tangent).';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'first',
      type: ParamType.entity,
      description: 'First tangent object',
    ),
    ParamSpec(
      name: 'second',
      type: ParamType.entity,
      description: 'Second tangent object',
    ),
    ParamSpec(
      name: 'radius',
      type: ParamType.distance,
      description: 'Radius of the new circle',
      min: 1e-9,
    ),
    ParamSpec(
      name: 'pick1',
      type: ParamType.point,
      required: false,
      description: 'Point that marks the side of the first object',
    ),
    ParamSpec(
      name: 'pick2',
      type: ParamType.point,
      required: false,
      description: 'Point that marks the side of the second object',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final firstId = context.args.integer('first');
    final secondId = context.args.integer('second');
    final int id1;
    final int id2;
    Vec2? firstSide;
    Vec2? secondSide;
    if (firstId != null && secondId != null) {
      id1 = firstId;
      id2 = secondId;
    } else {
      context.selection.clear();
      final firstPick = await context.input.selection(
        'CIRCLE  Select first tangent object:',
        useExistingSelection: false,
        single: true,
      );
      if (firstPick.isEmpty) return const CommandResult.cancelled();
      id1 = firstPick.first;
      firstSide = context.input.lastPick;
      final secondPick = await context.input.selection(
        'CIRCLE  Select second tangent object:',
        useExistingSelection: false,
        single: true,
      );
      if (secondPick.isEmpty) return const CommandResult.cancelled();
      id2 = secondPick.first;
      secondSide = context.input.lastPick;
    }

    final first = context.document.entity(id1);
    final second = context.document.entity(id2);
    if (first == null || second == null) {
      return const CommandResult.failed('A tangent object no longer exists.');
    }

    final pick1 =
        context.args.point('pick1') ?? firstSide ?? _tangentPick(first);
    final pick2 =
        context.args.point('pick2') ?? secondSide ?? _tangentPick(second);

    context.input
      ..setMarkers([pick1, pick2])
      ..setPreview((cursor) {
        final radius = pick1.distanceTo(cursor);
        if (radius <= 0) return const <OverlayShape>[];
        final preview = Construct.circleTangentRadius(
          first,
          second,
          radius,
          pick1,
          pick2,
        );
        if (preview == null) {
          return [OverlayLine(pick1, cursor)];
        }
        return [
          OverlayArc(center: preview.center, radius: preview.radius),
          OverlayLine(pick1, cursor),
        ];
      });
    final radius =
        context.args.number('radius') ??
        await context.input.distance(
          'CIRCLE  Specify radius:',
          basePoint: pick1,
        );
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    if (radius <= 0) {
      return const CommandResult.failed('The radius must be positive.');
    }

    final circle = Construct.circleTangentRadius(
      first,
      second,
      radius,
      pick1,
      pick2,
      props: EntityProps(layer: context.document.currentLayer),
    );
    if (circle == null) {
      return const CommandResult.failed(
        'No circle of that radius is tangent to both objects on the '
        'picked sides.',
      );
    }
    return commitDraw(context, 'Circle', [circle]);
  }
}

Vec2 _tangentPick(CadEntity entity) => switch (entity) {
  LineEntity(:final midpoint) => midpoint,
  CircleEntity(:final center) => center,
  ArcEntity(:final midPoint) => midPoint,
  _ => entity.computeBounds().center,
};
