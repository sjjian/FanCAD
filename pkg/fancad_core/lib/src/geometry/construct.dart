import 'dart:math' as math;
import 'dart:typed_data';

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

  /// A clamped uniform B-spline through the given control points.
  ///
  /// Degree is 3 when there are at least four points, otherwise it drops so
  /// the knot vector stays valid. This is the control-point form of SPLINE,
  /// not an interpolating fit — the curve is pulled toward the clicks, and
  /// only guaranteed to pass through the first and last.
  static SplineEntity? splineFromControls(
    List<Vec2> points, {
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    if (points.length < 2) return null;
    final degree = math.min(3, points.length - 1);
    final controlPoints = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      controlPoints[i * 2] = points[i].x;
      controlPoints[i * 2 + 1] = points[i].y;
    }
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: controlPoints,
      knots: _clampedUniformKnots(points.length, degree),
      degree: degree,
      fitPoints: Float64List.fromList(controlPoints),
    );
  }

  /// Open clamped uniform knots: `count + degree + 1` values, 0 at the start
  /// and 1 at the end, equally spaced in between.
  static List<double> _clampedUniformKnots(int count, int degree) {
    final knots = List<double>.filled(count + degree + 1, 0);
    for (var i = 0; i <= degree; i++) {
      knots[i] = 0;
      knots[knots.length - 1 - i] = 1;
    }
    final interior = count - degree - 1;
    for (var i = 1; i <= interior; i++) {
      knots[degree + i] = i / (interior + 1);
    }
    return knots;
  }

  /// An axis-aligned-or-rotated ellipse from a centre, one axis end, and the
  /// other semi-axis length.
  ///
  /// If the second radius is longer than the first axis, the two swap so the
  /// stored [EllipseEntity.ratio] stays at most 1, which is how DWG records it.
  static EllipseEntity? ellipse({
    required Vec2 center,
    required Vec2 axisEnd,
    required double otherRadius,
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    var major = axisEnd - center;
    final majorLength = major.length;
    if (majorLength < 1e-12 || otherRadius <= 0 || !otherRadius.isFinite) {
      return null;
    }
    var ratio = otherRadius / majorLength;
    if (ratio > 1) {
      major = major.normalized().perpendicular * otherRadius;
      ratio = majorLength / otherRadius;
    }
    return EllipseEntity(
      id: id,
      props: props,
      center: center,
      majorAxis: major,
      ratio: ratio,
    );
  }

  /// A circular donut as a closed two-vertex polyline with width.
  ///
  /// AutoCAD stores DONUT this way: the centreline radius is the average of
  /// the two radii and [PolylineEntity.constantWidth] is their difference, so
  /// a zero inner radius becomes a filled disk.
  static PolylineEntity? donut({
    required Vec2 center,
    required double innerRadius,
    required double outerRadius,
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    final inner = innerRadius.abs();
    final outer = outerRadius.abs();
    final r0 = math.min(inner, outer);
    final r1 = math.max(inner, outer);
    if (r1 <= 1e-12) return null;
    final mid = (r0 + r1) / 2;
    return PolylineEntity(
      id: id,
      props: props,
      vertices: Float64List.fromList([
        center.x - mid,
        center.y,
        1,
        center.x + mid,
        center.y,
        1,
      ]),
      closed: true,
      constantWidth: r1 - r0,
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

  /// Rounds the corner between two lines, or trims them to a sharp join.
  ///
  /// [pick1] and [pick2] choose which side of the intersection to keep on each
  /// line, which is what makes an X yield one of four possible fillets rather
  /// than an arbitrary one. A [radius] of zero is FILLET with R=0: the lines
  /// meet at the corner and no arc is created.
  static FilletResult? filletLines(
    LineEntity first,
    LineEntity second,
    double radius,
    Vec2 pick1,
    Vec2 pick2, {
    EntityProps? arcProps,
  }) {
    if (radius < 0 || !radius.isFinite) return null;
    final corner = Intersect.lineLine(
      first.start,
      first.end,
      second.start,
      second.end,
    );
    if (corner == null) return null;

    final keep1 = _filletKeepDir(first, corner, pick1);
    final keep2 = _filletKeepDir(second, corner, pick2);
    if (keep1 == null || keep2 == null) return null;

    final bisector = keep1 + keep2;
    if (bisector.lengthSquared < 1e-16) return null;

    final alpha = math.acos(keep1.dot(keep2).clamp(-1.0, 1.0));
    if (alpha < 1e-9) return null;

    if (radius == 0) {
      return FilletResult(
        first: _filletArm(first, corner, keep1, corner),
        second: _filletArm(second, corner, keep2, corner),
      );
    }

    final half = alpha / 2;
    final offset = radius / math.tan(half);
    if (!offset.isFinite || offset < 0) return null;

    final tangent1 = corner + keep1 * offset;
    final tangent2 = corner + keep2 * offset;
    final center = corner + bisector.normalized() * (radius / math.sin(half));

    // The arc must face the corner: the shorter sweep whose interior points
    // toward the intersection, not the long way around the circle.
    final startAngle = (tangent1 - center).angle;
    final endAngle = (tangent2 - center).angle;
    final viaAngle = (corner - center).angle;
    final forward =
        angularSweep(startAngle, viaAngle) <=
        angularSweep(startAngle, endAngle);

    return FilletResult(
      first: _filletArm(first, corner, keep1, tangent1),
      second: _filletArm(second, corner, keep2, tangent2),
      arc: ArcEntity(
        id: 0,
        props: arcProps ?? first.props,
        center: center,
        radius: radius,
        startAngle: forward ? startAngle : endAngle,
        endAngle: forward ? endAngle : startAngle,
      ),
    );
  }

  /// Cuts a straight chamfer between two lines.
  ///
  /// [dist1] and [dist2] are the distances from the intersection back along
  /// each kept arm. Both zero is CHAMFER with D=0: a sharp corner and no cut.
  static ChamferResult? chamferLines(
    LineEntity first,
    LineEntity second,
    double dist1,
    double dist2,
    Vec2 pick1,
    Vec2 pick2, {
    EntityProps? cutProps,
  }) {
    if (dist1 < 0 || dist2 < 0 || !dist1.isFinite || !dist2.isFinite) {
      return null;
    }
    final corner = Intersect.lineLine(
      first.start,
      first.end,
      second.start,
      second.end,
    );
    if (corner == null) return null;

    final keep1 = _filletKeepDir(first, corner, pick1);
    final keep2 = _filletKeepDir(second, corner, pick2);
    if (keep1 == null || keep2 == null) return null;

    final bisector = keep1 + keep2;
    if (bisector.lengthSquared < 1e-16) return null;
    final alpha = math.acos(keep1.dot(keep2).clamp(-1.0, 1.0));
    if (alpha < 1e-9) return null;

    if (dist1 == 0 && dist2 == 0) {
      return ChamferResult(
        first: _filletArm(first, corner, keep1, corner),
        second: _filletArm(second, corner, keep2, corner),
      );
    }

    final tangent1 = corner + keep1 * dist1;
    final tangent2 = corner + keep2 * dist2;
    return ChamferResult(
      first: _filletArm(first, corner, keep1, tangent1),
      second: _filletArm(second, corner, keep2, tangent2),
      cut: LineEntity(
        id: 0,
        props: cutProps ?? first.props,
        start: tangent1,
        end: tangent2,
      ),
    );
  }

  /// Breaks [line] at [first], or removes the span between [first] and [second].
  ///
  /// One point splits the line in two. Two points drop the middle and leave
  /// the outer remnants (either of which may vanish if a point is an endpoint).
  /// Returns null when the break would not change the line; an empty list when
  /// the whole line is removed.
  static List<LineEntity>? breakLine(
    LineEntity line,
    Vec2 first, [
    Vec2? second,
  ]) {
    final along = line.end - line.start;
    final lengthSquared = along.lengthSquared;
    if (lengthSquared < 1e-20) return null;

    double param(Vec2 point) =>
        ((point - line.start).dot(along) / lengthSquared).clamp(0.0, 1.0);

    var t1 = param(first);
    var t2 = second == null ? t1 : param(second);
    if (t1 > t2) {
      final swap = t1;
      t1 = t2;
      t2 = swap;
    }

    final pieces = <LineEntity>[];
    if (t1 > 1e-9) {
      pieces.add(
        LineEntity(
          id: line.id,
          props: line.props,
          start: line.start,
          end: line.start + along * t1,
        ),
      );
    }
    if (t2 < 1 - 1e-9) {
      pieces.add(
        LineEntity(
          id: pieces.isEmpty ? line.id : 0,
          props: line.props,
          start: line.start + along * t2,
          end: line.end,
        ),
      );
    }
    if (pieces.length == 1 &&
        pieces.first.start.distanceTo(line.start) < 1e-12 &&
        pieces.first.end.distanceTo(line.end) < 1e-12) {
      return null;
    }
    return pieces;
  }

  /// Direction from the corner along the side of [line] that [pick] sits on.
  static Vec2? _filletKeepDir(LineEntity line, Vec2 corner, Vec2 pick) {
    final along = line.end - line.start;
    final denom = along.lengthSquared;
    if (denom < 1e-20) return null;
    final projected = line.start + along * ((pick - line.start).dot(along) / denom);
    var dir = projected - corner;
    if (dir.lengthSquared < 1e-20) {
      final startLen = line.start.distanceSquaredTo(corner);
      final endLen = line.end.distanceSquaredTo(corner);
      dir = startLen >= endLen ? line.start - corner : line.end - corner;
    }
    if (dir.lengthSquared < 1e-20) return null;
    return dir.normalized();
  }

  /// The remnant of [line] from [tangent] out along [keepDir].
  static LineEntity _filletArm(
    LineEntity line,
    Vec2 corner,
    Vec2 keepDir,
    Vec2 tangent,
  ) {
    final startDot = (line.start - corner).dot(keepDir);
    final endDot = (line.end - corner).dot(keepDir);
    final far = startDot >= endDot ? line.start : line.end;
    return LineEntity(
      id: line.id,
      props: line.props,
      start: tangent,
      end: far.distanceTo(tangent) < 1e-12 ? tangent + keepDir : far,
    );
  }

  /// Interior points that split [line] into [segments] equal pieces.
  ///
  /// DIVIDE places markers between the ends, not on them: 4 segments means
  /// three points. Endpoints are already geometry; repeating them as nodes
  /// just clutters the drawing.
  static List<Vec2> divideLine(LineEntity line, int segments) {
    if (segments < 2) return const [];
    return [
      for (var i = 1; i < segments; i++)
        line.start.lerp(line.end, i / segments),
    ];
  }

  /// Points spaced [spacing] apart along [line], starting from the end nearer [pick].
  ///
  /// MEASURE never marks the endpoints: the first node is one interval in, and
  /// a leftover shorter than [spacing] at the far end is left unmarked.
  static List<Vec2> measureLine(LineEntity line, double spacing, Vec2 pick) {
    if (spacing <= 0 || !spacing.isFinite) return const [];
    final fromStart =
        pick.distanceSquaredTo(line.start) <= pick.distanceSquaredTo(line.end);
    final origin = fromStart ? line.start : line.end;
    final dest = fromStart ? line.end : line.start;
    final length = origin.distanceTo(dest);
    if (length <= spacing) return const [];
    return [
      for (var i = 1; i * spacing < length - 1e-12; i++)
        origin.lerp(dest, i * spacing / length),
    ];
  }

  /// Lengthens or shortens [line] by moving the endpoint nearer [pick].
  ///
  /// [total] sets the finished length. [delta] is added to the current length
  /// when [total] is omitted. The far end stays put, which is how LENGTHEN
  /// feels when you click the end you want to drag.
  static LineEntity? lengthenLine(
    LineEntity line,
    Vec2 pick, {
    double? delta,
    double? total,
  }) {
    final current = line.length;
    if (current < 1e-12) return null;
    final target = total ?? (current + (delta ?? 0));
    if (target <= 1e-12 || !target.isFinite) return null;
    final scale = target / current;
    final moveStart =
        pick.distanceSquaredTo(line.start) <= pick.distanceSquaredTo(line.end);
    return moveStart
        ? resizedLine(line, 1 - scale, 1)
        : resizedLine(line, 0, scale);
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

/// The two trimmed lines and optional joining arc produced by [Construct.filletLines].
class FilletResult {
  const FilletResult({
    required this.first,
    required this.second,
    this.arc,
  });

  final LineEntity first;
  final LineEntity second;
  final ArcEntity? arc;
}

/// The two trimmed lines and optional cut produced by [Construct.chamferLines].
class ChamferResult {
  const ChamferResult({
    required this.first,
    required this.second,
    this.cut,
  });

  final LineEntity first;
  final LineEntity second;
  final LineEntity? cut;
}
