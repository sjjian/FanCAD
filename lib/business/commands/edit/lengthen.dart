import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditLengthenCommand extends FanCadCommand {
  const EditLengthenCommand();

  @override
  String get id => 'edit.lengthen';
  @override
  String get title => 'Lengthen';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['len', 'lengthen'];
  @override
  String get description =>
      'Changes the length of a line, open polyline or arc by moving the '
      'end you pick. A bulge grows or shrinks along its arc. Supply a '
      'total length, or a signed delta to add to the current length. An '
      'arc cannot be closed into a full circle.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The line, polyline or arc to lengthen',
      required: false,
    ),
    ParamSpec(
      name: 'pick',
      type: ParamType.point,
      description: 'A point nearer the end that should move',
      required: false,
    ),
    ParamSpec(
      name: 'total',
      type: ParamType.distance,
      description: 'Finished length',
      required: false,
      min: 1e-9,
    ),
    ParamSpec(
      name: 'delta',
      type: ParamType.distance,
      description: 'Length to add; negative shortens',
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
        'LENGTHEN  Select a line, polyline or arc:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      targetId = picked.first;
    }

    final target = context.document.entity(targetId);
    if (target is! LineEntity &&
        target is! PolylineEntity &&
        target is! ArcEntity) {
      return const CommandResult.failed(
        'Lengthen supports lines, open polylines and arcs.',
      );
    }
    if (target is PolylineEntity && target.closed) {
      return const CommandResult.failed(
        'Lengthen cannot change a closed polyline.',
      );
    }
    final entity = target as CadEntity;

    final pick =
        context.args.point('pick') ??
        await context.input.point(
          'LENGTHEN  Specify a point nearer the end to change:',
        );

    final currentLength = Construct.lengthOf(entity);
    var total = context.args.number('total');
    final delta = context.args.number('delta');
    if (total == null && delta == null) {
      context.input
        ..setMarkers([_lengthenAnchor(entity, pick)])
        ..setPreview((cursor) {
          final preview = _lengthenEntity(
            entity,
            pick,
            total: _lengthenPreviewTotal(entity, pick, cursor),
          );
          return _lengthenOverlay(preview);
        });
      total = await context.input.number(
        'LENGTHEN  Specify total length:',
        defaultValue: currentLength,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);
    }

    final result = _lengthenEntity(entity, pick, total: total, delta: delta);
    if (result == null) {
      return const CommandResult.failed(
        'The resulting length must be positive.',
      );
    }
    if ((Construct.lengthOf(result) - currentLength).abs() < 1e-12) {
      return const CommandResult.cancelled('The length is unchanged.');
    }

    final committed = context.edit('Lengthen', (transaction) {
      transaction.modify(result);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was lengthened; the object may be on a locked layer.',
      );
    }
    context.selection.replace([targetId]);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Lengthen: ${Construct.lengthOf(result).toStringAsFixed(4)}.',
      transaction: committed,
    );
  }
}

/// The pieces an entity breaks into. Empty when it cannot be exploded.
CadEntity? _lengthenEntity(
  CadEntity target,
  Vec2 pick, {
  double? total,
  double? delta,
}) {
  return switch (target) {
    LineEntity() => Construct.lengthenLine(
      target,
      pick,
      total: total,
      delta: delta,
    ),
    PolylineEntity() => Construct.lengthenPolyline(
      target,
      pick,
      total: total,
      delta: delta,
    ),
    ArcEntity() => Construct.lengthenArc(
      target,
      pick,
      total: total,
      delta: delta,
    ),
    _ => null,
  };
}

Vec2 _lengthenAnchor(CadEntity target, Vec2 pick) {
  return switch (target) {
    LineEntity(:final start, :final end) =>
      pick.distanceSquaredTo(start) <= pick.distanceSquaredTo(end)
          ? end
          : start,
    PolylineEntity() =>
      pick.distanceSquaredTo(target.vertexAt(0)) <=
              pick.distanceSquaredTo(target.vertexAt(target.vertexCount - 1))
          ? target.vertexAt(target.vertexCount - 1)
          : target.vertexAt(0),
    ArcEntity(:final startPoint, :final endPoint) =>
      pick.distanceSquaredTo(startPoint) <= pick.distanceSquaredTo(endPoint)
          ? endPoint
          : startPoint,
    _ => pick,
  };
}

/// Total length implied by dragging the moving end toward [cursor].
double _lengthenPreviewTotal(CadEntity target, Vec2 pick, Vec2 cursor) {
  if (target is LineEntity) {
    return _lengthenAnchor(target, pick).distanceTo(cursor);
  }
  if (target is ArcEntity) {
    final fromStart =
        pick.distanceSquaredTo(target.startPoint) <=
        pick.distanceSquaredTo(target.endPoint);
    final cursorAngle = (cursor - target.center).angle;
    final sweep = fromStart
        ? angularSweep(cursorAngle, target.endAngle)
        : angularSweep(target.startAngle, cursorAngle);
    return target.radius * sweep;
  }
  if (target is! PolylineEntity || target.vertexCount < 2) {
    return 0;
  }
  final start = target.vertexAt(0);
  final end = target.vertexAt(target.vertexCount - 1);
  final fromStart =
      pick.distanceSquaredTo(start) <= pick.distanceSquaredTo(end);
  final moving = fromStart ? start : end;
  final inward = fromStart
      ? target.vertexAt(1)
      : target.vertexAt(target.vertexCount - 2);
  return Construct.lengthOf(target) -
      moving.distanceTo(inward) +
      inward.distanceTo(cursor);
}

List<OverlayShape> _lengthenOverlay(CadEntity? preview) {
  return switch (preview) {
    LineEntity(:final start, :final end) => [
      OverlayLine(start, end, dashed: false),
    ],
    PolylineEntity() => [
      OverlayPolyline([
        for (var i = 0; i < preview.vertexCount; i++) preview.vertexAt(i),
      ]),
    ],
    ArcEntity() => [
      OverlayArc(
        center: preview.center,
        radius: preview.radius,
        startAngle: preview.startAngle,
        sweep: preview.sweep,
      ),
    ],
    _ => const [],
  };
}
