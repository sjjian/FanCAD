import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditTrimCommand extends FanCadCommand {
  const EditTrimCommand();

  @override
  String get id => 'edit.trim';
  @override
  String get title => 'Trim';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['tr', 'trim'];
  @override
  String? get icon => 'trim';
  @override
  String get description =>
      'Shortens a line, polyline or arc back to where it crosses the '
      'selected cutting edges. The part containing the pick point is '
      'removed. A closed polyline opens; a bulge is cut on the arc, not '
      'the chord.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('edges', description: 'Cutting edges'),
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The line, polyline or arc to trim',
    ),
    ParamSpec.point('pick', description: 'A point on the piece to remove'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      _trimOrExtend(context, extend: false);
}

class EditExtendCommand extends FanCadCommand {
  const EditExtendCommand();

  @override
  String get id => 'edit.extend';
  @override
  String get title => 'Extend';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ex', 'extend'];
  @override
  String get description =>
      'Lengthens a line, open polyline or arc until it meets the '
      'selected boundary edges. A bulge grows along its circle. On a '
      'polyline or arc the pick chooses which end moves.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('edges', description: 'Boundary edges'),
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The line, polyline or arc to extend',
    ),
    ParamSpec.point('pick', description: 'A point nearer the end to move'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      _trimOrExtend(context, extend: true);
}

Vec2 _splinePick(SplineEntity spline) {
  final xy = Flatten.bspline(
    controlPoints: spline.controlPoints,
    knots: spline.knots,
    degree: spline.degree,
    weights: spline.weights,
    tolerance: 1e-3,
    closed: spline.closed,
  );
  if (xy.length < 2) return const Vec2.zero();
  final index = (xy.length ~/ 4) * 2;
  final clamped = index.clamp(0, xy.length - 2);
  return Vec2(xy[clamped], xy[clamped + 1]);
}

Future<CommandResult> _trimOrExtend(
  CommandContext context, {
  required bool extend,
}) async {
  final verb = extend ? 'EXTEND' : 'TRIM';
  final edgeIds = await context.resolveSelection(
    'edges',
    extend ? 'EXTEND  Select boundary edges:' : 'TRIM  Select cutting edges:',
  );
  if (edgeIds.isEmpty) return const CommandResult.cancelled();
  // The edges are now fixed; clearing the selection stops the next prompt
  // from silently reusing them as the thing to modify.
  context.selection.clear();

  final edges = <CadEntity>[
    for (final id in edgeIds) ?context.document.entity(id),
  ];

  // A supplied target means one pass; otherwise the command keeps asking,
  // which is how TRIM is used in practice — pick edges once, then trim as
  // many objects as you like until Escape.
  final suppliedTarget = context.args.integer('target');
  final suppliedPick = context.args.point('pick');

  var changed = 0;
  var attempts = 0;
  CommittedTransaction? last;
  while (true) {
    final int targetId;
    if (suppliedTarget != null) {
      if (attempts > 0) break;
      targetId = suppliedTarget;
    } else {
      final picked = await context.input.selection(
        '$verb  Select an object to ${extend ? 'extend' : 'trim'} '
        '(Escape to finish):',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) break;
      targetId = picked.first;
    }
    attempts++;

    final target = context.document.entity(targetId);
    if (target is! LineEntity &&
        target is! PolylineEntity &&
        target is! ArcEntity &&
        target is! EllipseEntity &&
        target is! SplineEntity) {
      context.input.write(
        '$verb supports lines, polylines, arcs, ellipses and splines; '
        '${target?.kind.name ?? 'that object'} was skipped.',
      );
      if (suppliedTarget != null) {
        return CommandResult.failed(
          '$verb supports lines, polylines, arcs, ellipses and splines.',
        );
      }
      continue;
    }
    if (extend &&
        ((target is PolylineEntity && target.closed) ||
            (target is SplineEntity && target.closed))) {
      context.input.write('EXTEND cannot change a closed curve.');
      if (suppliedTarget != null) {
        return const CommandResult.failed(
          'EXTEND cannot change a closed curve.',
        );
      }
      continue;
    }
    final entity = target as CadEntity;
    final CadEntity? result;
    if (extend) {
      result = switch (entity) {
        LineEntity() => Construct.extendLine(entity, edges),
        PolylineEntity() => Construct.extendPolyline(
          entity,
          edges,
          suppliedPick,
        ),
        ArcEntity() => Construct.extendArc(entity, edges, suppliedPick),
        EllipseEntity() => Construct.extendEllipse(entity, edges, suppliedPick),
        SplineEntity() => Construct.extendSpline(entity, edges, suppliedPick),
        _ => null,
      };
    } else {
      final crossings = <Vec2>[
        for (final edge in edges) ...Construct.crossingsAlong(entity, edge),
      ];
      // Without a pick point there is no way to know which side to discard,
      // so the middle of the object is the least surprising guess.
      final pick =
          suppliedPick ??
          switch (entity) {
            LineEntity(:final midpoint) => midpoint,
            ArcEntity(:final midPoint) => midPoint,
            EllipseEntity() => entity.pointAt(
              entity.startParam + entity.sweep / 2,
            ),
            PolylineEntity() =>
              Construct.dividePolyline(entity, 2).firstOrNull ??
                  entity.vertexAt(0),
            SplineEntity() => _splinePick(entity),
            _ => const Vec2(0, 0),
          };
      result = switch (entity) {
        LineEntity() => Construct.trimLine(entity, crossings, pick),
        PolylineEntity() => Construct.trimPolyline(entity, crossings, pick),
        ArcEntity() => Construct.trimArc(entity, crossings, pick),
        EllipseEntity() => Construct.trimEllipse(entity, crossings, pick),
        SplineEntity() => Construct.trimSpline(entity, crossings, pick),
        _ => null,
      };
    }
    if (result == null) {
      context.input.write(
        '$verb: no usable intersection with the selected edges.',
      );
      if (suppliedTarget != null) {
        return CommandResult.failed(
          '$verb found no usable intersection with the selected edges.',
        );
      }
      continue;
    }
    last = context.edit(extend ? 'Extend' : 'Trim', (transaction) {
      transaction.modify(result!);
    });
    if (last != null) changed++;
    context.selection.clear();
  }

  if (changed == 0) return const CommandResult.cancelled();
  return CommandResult(
    status: CommandStatus.ok,
    message: '$verb: $changed object(s) modified.',
    transaction: last,
  );
}
