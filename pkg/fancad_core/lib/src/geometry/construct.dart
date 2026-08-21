import 'dart:math' as math;

import '../model/entity.dart';
import '../model/style.dart';
import 'intersect.dart';
import 'vector.dart';

/// The analytic constructions behind the editing commands.
///
/// These are pure functions on entities rather than methods on a tool, because
/// every one of them has three callers: the interactive command, a plugin, and
/// an AI tool call. Keeping them here means those three can never drift apart,
/// and it means each one is directly unit testable.
class Construct {
  const Construct._();

  /// The arc through three points, or null when they are collinear.
  ///
  /// The centre is the circumcentre; the subtlety is the sweep direction, which
  /// has to be chosen so the arc actually passes through [via] rather than
  /// taking the long way round.
  static ArcEntity? arcThrough(
    Vec2 start,
    Vec2 via,
    Vec2 end, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final d =
        2 *
        (start.x * (via.y - end.y) +
            via.x * (end.y - start.y) +
            end.x * (start.y - via.y));
    if (d.abs() < 1e-12) return null;
    final centerX =
        (start.lengthSquared * (via.y - end.y) +
            via.lengthSquared * (end.y - start.y) +
            end.lengthSquared * (start.y - via.y)) /
        d;
    final centerY =
        (start.lengthSquared * (end.x - via.x) +
            via.lengthSquared * (start.x - end.x) +
            end.lengthSquared * (via.x - start.x)) /
        d;
    final center = Vec2(centerX, centerY);
    final radius = center.distanceTo(start);
    if (!radius.isFinite || radius <= 0) return null;

    final startAngle = (start - center).angle;
    final endAngle = (end - center).angle;
    final viaAngle = (via - center).angle;
    // If the counter-clockwise sweep from start to end does not contain the
    // middle point, the arc runs the other way, so the endpoints swap.
    final forward =
        angularSweep(startAngle, viaAngle) <= angularSweep(startAngle, endAngle);
    return ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: forward ? startAngle : endAngle,
      endAngle: forward ? endAngle : startAngle,
    );
  }

  /// The unique circle through three points, or null when they are collinear.
  ///
  /// CIRCLE 3P is this construction: the circumcentre is already the arc-through
  /// result, and dropping the sweep leaves the full circle.
  static CircleEntity? circleThrough(
    Vec2 first,
    Vec2 second,
    Vec2 third, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final arc = arcThrough(first, second, third);
    if (arc == null) return null;
    return CircleEntity(
      id: id,
      props: props,
      center: arc.center,
      radius: arc.radius,
    );
  }

  /// A closed rectangular polyline through two opposite corners.
  static PolylineEntity? rectangle(
    Vec2 first,
    Vec2 second, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final minX = math.min(first.x, second.x);
    final minY = math.min(first.y, second.y);
    final maxX = math.max(first.x, second.x);
    final maxY = math.max(first.y, second.y);
    if (maxX - minX <= 0 || maxY - minY <= 0) return null;
    return PolylineEntity.fromPoints(
      id: id,
      props: props,
      points: [
        Vec2(minX, minY),
        Vec2(maxX, minY),
        Vec2(maxX, maxY),
        Vec2(minX, maxY),
      ],
      closed: true,
    );
  }

  /// A regular polygon, as the POLYGON command produces it.
  static PolylineEntity polygon({
    required Vec2 center,
    required double radius,
    required int sides,
    double startAngle = math.pi / 2,
    bool circumscribed = false,
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final count = sides.clamp(3, 1024);
    // Inscribed means the vertices touch the circle; circumscribed means the
    // edge midpoints do, so the vertex radius has to grow to compensate.
    final effective = circumscribed
        ? radius / math.cos(math.pi / count)
        : radius;
    return PolylineEntity.fromPoints(
      id: id,
      props: props,
      points: [
        for (var i = 0; i < count; i++)
          center + Vec2.polar(startAngle + i * 2 * math.pi / count, effective),
      ],
      closed: true,
    );
  }

  /// Offsets [entity] by [distance] to whichever side [towards] falls on.
  ///
  /// Analytic per type rather than a general polygon offset: a circle offsets to
  /// a circle and an arc to an arc. A user who offsets a circle and gets a
  /// 64-segment polyline back will not use the command twice.
  static CadEntity? offset(CadEntity entity, double distance, Vec2 towards) {
    if (distance <= 0) return null;
    switch (entity) {
      case LineEntity(:final start, :final end):
        final direction = (end - start).normalized();
        if (direction.length == 0) return null;
        final normal = direction.perpendicular;
        // Which side is the pick on? The sign of the projection decides.
        final sign = normal.dot(towards - start) >= 0 ? 1.0 : -1.0;
        final shift = normal * (distance * sign);
        return LineEntity(
          id: 0,
          props: entity.props,
          start: start + shift,
          end: end + shift,
        );
      case CircleEntity(:final center, :final radius):
        final target = center.distanceTo(towards) > radius
            ? radius + distance
            : radius - distance;
        if (target <= 0) return null;
        return CircleEntity(
          id: 0,
          props: entity.props,
          center: center,
          radius: target,
        );
      case ArcEntity(:final center, :final radius):
        final target = center.distanceTo(towards) > radius
            ? radius + distance
            : radius - distance;
        if (target <= 0) return null;
        return ArcEntity(
          id: 0,
          props: entity.props,
          center: center,
          radius: target,
          startAngle: entity.startAngle,
          endAngle: entity.endAngle,
        );
      case PolylineEntity():
        return _offsetPolyline(entity, distance, towards);
      case EllipseEntity() ||
          SplineEntity() ||
          PointEntity() ||
          TextEntity() ||
          MTextEntity() ||
          InsertEntity() ||
          HatchEntity() ||
          DimensionEntity() ||
          LeaderEntity() ||
          SolidEntity() ||
          RayEntity() ||
          XLineEntity() ||
          ImageEntity() ||
          UnknownEntity():
        return null;
    }
  }

  /// Offsets a polyline by moving each segment and re-intersecting neighbours.
  ///
  /// Miter joins rather than round ones, because the mitered offset of a
  /// rectangle is another rectangle, which is what a user expects to get.
  static PolylineEntity? _offsetPolyline(
    PolylineEntity source,
    double distance,
    Vec2 towards,
  ) {
    final count = source.vertexCount;
    if (count < 2) return null;
    final vertices = [for (var i = 0; i < count; i++) source.vertexAt(i)];
    final segmentCount = source.closed ? count : count - 1;

    // Decide the side once, from the segment nearest the pick, so the whole
    // polyline offsets coherently instead of segment by segment.
    var bestDistance = double.infinity;
    var sign = 1.0;
    for (var i = 0; i < segmentCount; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % count];
      final foot = Intersect.closestPointOnSegment(towards, a, b);
      final gap = foot.distanceTo(towards);
      if (gap < bestDistance) {
        bestDistance = gap;
        final normal = (b - a).normalized().perpendicular;
        sign = normal.dot(towards - a) >= 0 ? 1.0 : -1.0;
      }
    }

    // Offset each segment as an infinite line, then intersect consecutive ones
    // to find the new vertices.
    final lines = <(Vec2, Vec2)>[];
    for (var i = 0; i < segmentCount; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % count];
      final direction = (b - a).normalized();
      if (direction.length == 0) continue;
      final shift = direction.perpendicular * (distance * sign);
      lines.add((a + shift, b + shift));
    }
    if (lines.isEmpty) return null;

    final result = <Vec2>[];
    if (!source.closed) result.add(lines.first.$1);
    final joints = source.closed ? lines.length : lines.length - 1;
    for (var i = 0; i < joints; i++) {
      final current = lines[i];
      final next = lines[(i + 1) % lines.length];
      final joint = Intersect.lineLine(
        current.$1,
        current.$2,
        next.$1,
        next.$2,
      );
      // Parallel neighbours (a straight-through vertex) have no intersection;
      // the shared offset endpoint is the right answer there.
      result.add(joint ?? current.$2);
    }
    if (!source.closed) result.add(lines.last.$2);
    if (result.length < 2) return null;

    return PolylineEntity.fromPoints(
      id: 0,
      props: source.props,
      points: result,
      closed: source.closed,
    );
  }

  /// Trims [line] by discarding the piece that contains [pick].
  ///
  /// [crossings] are the points where the cutting edges meet the line. Returns
  /// null when the pick is not in a removable interval.
  static LineEntity? trimLine(
    LineEntity line,
    List<Vec2> crossings,
    Vec2 pick,
  ) {
    if (crossings.isEmpty) return null;
    final direction = line.end - line.start;
    final lengthSquared = direction.lengthSquared;
    if (lengthSquared < 1e-18) return null;

    double parameterOf(Vec2 p) =>
        (p - line.start).dot(direction) / lengthSquared;

    // Parameterise the line, sort the cuts along it, and find which interval
    // the pick falls in. That interval is the piece to discard.
    final cuts = <double>[
      0,
      for (final crossing in crossings)
        if (parameterOf(crossing) > 1e-9 && parameterOf(crossing) < 1 - 1e-9)
          parameterOf(crossing),
      1,
    ]..sort();
    if (cuts.length <= 2) return null;

    final pickParameter = parameterOf(pick).clamp(0.0, 1.0);
    for (var i = 0; i + 1 < cuts.length; i++) {
      if (pickParameter < cuts[i] || pickParameter > cuts[i + 1]) continue;
      final keepBefore = cuts[i] > 0;
      final keepAfter = cuts[i + 1] < 1;
      if (!keepBefore && !keepAfter) return null;
      if (keepBefore && keepAfter) {
        // Trimming out of the middle would correctly produce two lines, but
        // silently doubling the entity count surprises users more than it
        // helps, so the longer remnant is kept.
        return cuts[i] >= 1 - cuts[i + 1]
            ? resizedLine(line, 0, cuts[i])
            : resizedLine(line, cuts[i + 1], 1);
      }
      return keepBefore
          ? resizedLine(line, 0, cuts[i])
          : resizedLine(line, cuts[i + 1], 1);
    }
    return null;
  }

  /// Lengthens [line] until it meets one of [edges].
  static LineEntity? extendLine(LineEntity line, List<CadEntity> edges) {
    final direction = line.end - line.start;
    final lengthSquared = direction.lengthSquared;
    if (lengthSquared < 1e-18) return null;

    double? bestBefore;
    double? bestAfter;

    void consider(Vec2 hit) {
      final t = (hit - line.start).dot(direction) / lengthSquared;
      if (t < -1e-9) {
        if (bestBefore == null || t > bestBefore!) bestBefore = t;
      } else if (t > 1 + 1e-9) {
        if (bestAfter == null || t < bestAfter!) bestAfter = t;
      }
    }

    for (final edge in edges) {
      switch (edge) {
        case LineEntity(:final start, :final end):
          // The line is treated as infinite (extension happens beyond its
          // endpoints) but the boundary is not: the hit must land on the edge.
          final hit = Intersect.lineLine(line.start, line.end, start, end);
          if (hit == null) continue;
          if (Intersect.distanceToSegment(hit, start, end) > 1e-6) continue;
          consider(hit);
        case CircleEntity(:final center, :final radius):
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          )) {
            consider(hit);
          }
        case ArcEntity(:final center, :final radius):
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          )) {
            final angle = (hit - center).angle;
            if (angularSweep(edge.startAngle, angle) <= edge.sweep) {
              consider(hit);
            }
          }
        default:
          continue;
      }
    }

    // Prefer extending forward, which is the end the user is usually reaching
    // towards; fall back to the start.
    if (bestAfter != null) return resizedLine(line, 0, bestAfter!);
    if (bestBefore != null) return resizedLine(line, bestBefore!, 1);
    return null;
  }

  /// A copy of [line] spanning the parameter range `[from, to]`.
  static LineEntity resizedLine(LineEntity line, double from, double to) {
    final direction = line.end - line.start;
    return LineEntity(
      id: line.id,
      props: line.props,
      start: line.start + direction * from,
      end: line.start + direction * to,
    );
  }

  /// Every point where [line] meets [edge], for the trim family.
  static List<Vec2> crossingsWith(
    LineEntity line,
    CadEntity edge, {
    double tolerance = 1e-3,
  }) {
    switch (edge) {
      case LineEntity(:final start, :final end):
        final hit = Intersect.segmentSegment(
          line.start,
          line.end,
          start,
          end,
        );
        return hit == null ? const [] : [hit];
      case CircleEntity(:final center, :final radius):
        return [
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          ))
            if (Intersect.distanceToSegment(hit, line.start, line.end) < 1e-6)
              hit,
        ];
      case ArcEntity(:final center, :final radius):
        return [
          for (final hit in Intersect.lineCircle(
            line.start,
            line.end,
            center,
            radius,
          ))
            if (Intersect.distanceToSegment(hit, line.start, line.end) < 1e-6 &&
                angularSweep(edge.startAngle, (hit - center).angle) <=
                    edge.sweep)
              hit,
        ];
      case PolylineEntity():
        final result = <Vec2>[];
        final count = edge.vertexCount;
        final segments = edge.closed ? count : count - 1;
        for (var i = 0; i < segments; i++) {
          final hit = Intersect.segmentSegment(
            line.start,
            line.end,
            edge.vertexAt(i),
            edge.vertexAt((i + 1) % count),
          );
          if (hit != null) result.add(hit);
        }
        return result;
      default:
        return const [];
    }
  }

  /// The total length of an entity, for the measurement tools.
  static double lengthOf(CadEntity entity) => switch (entity) {
    LineEntity(:final length) => length,
    CircleEntity(:final radius) => 2 * math.pi * radius,
    ArcEntity(:final radius) => radius * entity.sweep,
    PolylineEntity() => _polylineLength(entity),
    _ => 0,
  };

  static double _polylineLength(PolylineEntity polyline) {
    var total = 0.0;
    final count = polyline.vertexCount;
    final segments = polyline.closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      total += polyline
          .vertexAt(i)
          .distanceTo(polyline.vertexAt((i + 1) % count));
    }
    return total;
  }

  /// The signed area enclosed by a closed entity. Positive is counter-clockwise.
  static double areaOf(CadEntity entity) => switch (entity) {
    CircleEntity(:final radius) => math.pi * radius * radius,
    PolylineEntity() when entity.closed => _shoelace(entity),
    HatchEntity(:final loops) => () {
      var total = 0.0;
      for (final loop in loops) {
        var sum = 0.0;
        final count = loop.pointCount;
        for (var i = 0; i < count; i++) {
          final j = (i + 1) % count;
          sum +=
              loop.vertices[i * 2] * loop.vertices[j * 2 + 1] -
              loop.vertices[j * 2] * loop.vertices[i * 2 + 1];
        }
        total += (sum / 2).abs() * (loop.isOuter ? 1 : -1);
      }
      return total;
    }(),
    _ => 0,
  };

  static double _shoelace(PolylineEntity polyline) {
    var sum = 0.0;
    final count = polyline.vertexCount;
    for (var i = 0; i < count; i++) {
      final a = polyline.vertexAt(i);
      final b = polyline.vertexAt((i + 1) % count);
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }
}
