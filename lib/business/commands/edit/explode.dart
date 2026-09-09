import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditExplodeCommand extends FanCadCommand {
  const EditExplodeCommand();

  @override
  String get id => 'edit.explode';
  @override
  String get title => 'Explode';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['x', 'explode'];
  @override
  String get description =>
      'Breaks polylines into their segments, block references into copies '
      'of their contents, and dimensions into the lines, arrows and text '
      'they draw.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'EXPLODE  Select objects to explode:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final committed = context.edit('Explode', (transaction) {
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final pieces = _explodeEntity(context.document, entity);
        if (pieces.isEmpty) continue;
        transaction
          ..addAll(pieces)
          ..erase(id);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'None of the selected objects can be exploded.',
      );
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Explode: ${committed.change.removed.length} object(s) became '
          '${committed.change.added.length}.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}

List<CadEntity> _explodeEntity(CadDocument document, CadEntity entity) {
  switch (entity) {
    case PolylineEntity():
      final count = entity.vertexCount;
      if (count < 2) return const [];
      final segments = entity.closed ? count : count - 1;
      return [
        for (var i = 0; i < segments; i++)
          // A bulged segment is an arc; reconstructing it keeps the exploded
          // geometry identical to what was on screen.
          if (entity.bulgeAt(i) == 0)
            LineEntity(
              id: 0,
              props: entity.props,
              start: entity.vertexAt(i),
              end: entity.vertexAt((i + 1) % count),
            )
          else
            ?_arcFromBulge(
              entity.vertexAt(i),
              entity.vertexAt((i + 1) % count),
              entity.bulgeAt(i),
              entity.props,
            ),
      ];
    case InsertEntity(:final blockName):
      final ids = document.entityIdsOf(blockName);
      if (ids == null || ids.isEmpty) return const [];
      final result = <CadEntity>[];
      for (var row = 0; row < entity.rowCount; row++) {
        for (var column = 0; column < entity.columnCount; column++) {
          final transform = entity.transformFor(column, row);
          for (final id in ids) {
            final member = document.entity(id);
            if (member == null) continue;
            if (member is AttdefEntity) {
              result.add(
                member
                    .toAttrib(
                      entity.attributeValue(member.tag, member.defaultValue),
                    )
                    .transformed(transform)
                    .withId(0),
              );
            } else {
              result.add(member.transformed(transform).withId(0));
            }
          }
        }
      }
      return result;
    case SolidEntity(:final corners):
      if (corners.length < 3) return const [];
      return [
        PolylineEntity.fromPoints(
          id: 0,
          props: entity.props,
          points: corners,
          closed: true,
        ),
      ];
    case DimensionEntity(:final blockName):
      if (blockName.isNotEmpty) {
        final ids = document.entityIdsOf(blockName);
        if (ids != null && ids.isNotEmpty) {
          return [
            for (final id in ids)
              if (document.entity(id) case final member?) member.withId(0),
          ];
        }
      }
      return Construct.explodeDimension(
        entity,
        style: document.dimStyle(entity.styleName),
      );
    default:
      return const [];
  }
}

/// Rebuilds the arc a polyline bulge encodes.
///
/// The bulge is the tangent of a quarter of the included angle, which is the
/// compact form DWG uses; recovering the centre from it is the reason an
/// exploded polyline keeps its curves.
ArcEntity? _arcFromBulge(
  Vec2 start,
  Vec2 end,
  double bulge,
  EntityProps props,
) {
  if (bulge == 0) return null;
  final chord = end - start;
  final chordLength = chord.length;
  if (chordLength < 1e-12) return null;
  final included = 4 * math.atan(bulge.abs());
  final radius = chordLength / (2 * math.sin(included / 2));
  if (!radius.isFinite || radius <= 0) return null;
  // The centre sits on the perpendicular bisector, on the side the sign of
  // the bulge selects.
  final apothem = math.sqrt(
    math.max(radius * radius - chordLength * chordLength / 4, 0),
  );
  final midpoint = start.lerp(end, 0.5);
  final normal = chord.normalized().perpendicular;
  final sign = bulge > 0 ? -1.0 : 1.0;
  final center = midpoint + normal * (apothem * sign);
  final startAngle = (start - center).angle;
  final endAngle = (end - center).angle;
  return ArcEntity(
    id: 0,
    props: props,
    center: center,
    radius: radius,
    // A positive bulge sweeps counter-clockwise from start to end.
    startAngle: bulge > 0 ? startAngle : endAngle,
    endAngle: bulge > 0 ? endAngle : startAngle,
  );
}
