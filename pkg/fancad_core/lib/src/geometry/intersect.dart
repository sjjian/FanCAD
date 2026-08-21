import 'dart:math' as math;
import 'dart:typed_data';

import 'vector.dart';

/// Analytic intersection and projection helpers.
///
/// These back object snapping (intersection / perpendicular / nearest) and the
/// trim / extend / fillet family of editing commands, so they operate on exact
/// primitives rather than on the flattened render geometry.
class Intersect {
  const Intersect._();

  static const double epsilon = 1e-10;

  /// Intersection of two infinite lines. Null when parallel.
  static Vec2? lineLine(Vec2 p1, Vec2 p2, Vec2 p3, Vec2 p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denominator = d1.cross(d2);
    if (denominator.abs() < epsilon) return null;
    final t = (p3 - p1).cross(d2) / denominator;
    return p1 + d1 * t;
  }

  /// Intersection of two finite segments, honouring both parameter ranges.
  static Vec2? segmentSegment(Vec2 p1, Vec2 p2, Vec2 p3, Vec2 p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denominator = d1.cross(d2);
    if (denominator.abs() < epsilon) return null;
    final delta = p3 - p1;
    final t = delta.cross(d2) / denominator;
    final u = delta.cross(d1) / denominator;
    if (t < -epsilon || t > 1 + epsilon || u < -epsilon || u > 1 + epsilon) {
      return null;
    }
    return p1 + d1 * t;
  }

  /// Intersections of an infinite line with a circle (0, 1 or 2 points).
  static List<Vec2> lineCircle(
    Vec2 p1,
    Vec2 p2,
    Vec2 center,
    double radius,
  ) {
    final d = p2 - p1;
    final lengthSquared = d.lengthSquared;
    if (lengthSquared < epsilon) return const [];
    final delta = p1 - center;
    final b = 2 * d.dot(delta);
    final c = delta.lengthSquared - radius * radius;
    final discriminant = b * b - 4 * lengthSquared * c;
    if (discriminant < 0) return const [];
    if (discriminant.abs() < epsilon) {
      return [p1 + d * (-b / (2 * lengthSquared))];
    }
    final root = math.sqrt(discriminant);
    return [
      p1 + d * ((-b - root) / (2 * lengthSquared)),
      p1 + d * ((-b + root) / (2 * lengthSquared)),
    ];
  }

  /// Intersections of two circles.
  static List<Vec2> circleCircle(
    Vec2 c1,
    double r1,
    Vec2 c2,
    double r2,
  ) {
    final delta = c2 - c1;
    final distance = delta.length;
    if (distance < epsilon) return const [];
    if (distance > r1 + r2 + epsilon) return const [];
    if (distance < (r1 - r2).abs() - epsilon) return const [];
    final a = (r1 * r1 - r2 * r2 + distance * distance) / (2 * distance);
    final hSquared = r1 * r1 - a * a;
    final h = hSquared <= 0 ? 0.0 : math.sqrt(hSquared);
    final base = c1 + delta * (a / distance);
    if (h == 0) return [base];
    final offset = delta.perpendicular * (h / distance);
    return [base + offset, base - offset];
  }

  /// Closest point on the segment `[a, b]` to [p], clamped to the segment.
  static Vec2 closestPointOnSegment(Vec2 p, Vec2 a, Vec2 b) {
    final d = b - a;
    final lengthSquared = d.lengthSquared;
    if (lengthSquared < epsilon) return a;
    final t = ((p - a).dot(d) / lengthSquared).clamp(0.0, 1.0);
    return a + d * t;
  }

  /// Perpendicular distance from [p] to the segment `[a, b]`.
  static double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) =>
      p.distanceTo(closestPointOnSegment(p, a, b));

  /// Closest point on an interleaved `[x, y, ...]` polyline, plus the index of
  /// the segment that owns it. Returns null for degenerate input.
  static PolylineHit? closestPointOnPolyline(
    Vec2 p,
    Float64List xy, {
    bool closed = false,
  }) {
    final count = xy.length ~/ 2;
    if (count == 0) return null;
    if (count == 1) {
      return PolylineHit(Vec2(xy[0], xy[1]), 0, p.distanceTo(Vec2(xy[0], xy[1])));
    }
    var best = double.infinity;
    var bestPoint = Vec2(xy[0], xy[1]);
    var bestSegment = 0;
    final segmentCount = closed ? count : count - 1;
    for (var i = 0; i < segmentCount; i++) {
      final j = (i + 1) % count;
      final a = Vec2(xy[i * 2], xy[i * 2 + 1]);
      final b = Vec2(xy[j * 2], xy[j * 2 + 1]);
      final candidate = closestPointOnSegment(p, a, b);
      final distance = p.distanceSquaredTo(candidate);
      if (distance < best) {
        best = distance;
        bestPoint = candidate;
        bestSegment = i;
      }
    }
    return PolylineHit(bestPoint, bestSegment, math.sqrt(best));
  }

  /// Whether an interleaved polygon ring contains [p] (even-odd rule).
  static bool polygonContains(Float64List xy, Vec2 p) {
    final count = xy.length ~/ 2;
    if (count < 3) return false;
    var inside = false;
    for (var i = 0, j = count - 1; i < count; j = i++) {
      final xi = xy[i * 2], yi = xy[i * 2 + 1];
      final xj = xy[j * 2], yj = xy[j * 2 + 1];
      if ((yi > p.y) != (yj > p.y) &&
          p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Whether the polyline crosses the axis-aligned rectangle. Used by crossing
  /// window selection, which must hit entities that merely pass through.
  static bool polylineCrossesRect(
    Float64List xy,
    double minX,
    double minY,
    double maxX,
    double maxY, {
    bool closed = false,
  }) {
    final count = xy.length ~/ 2;
    if (count == 0) return false;
    if (count == 1) {
      final x = xy[0], y = xy[1];
      return x >= minX && x <= maxX && y >= minY && y <= maxY;
    }
    final segmentCount = closed ? count : count - 1;
    for (var i = 0; i < segmentCount; i++) {
      final j = (i + 1) % count;
      if (_segmentCrossesRect(
        xy[i * 2],
        xy[i * 2 + 1],
        xy[j * 2],
        xy[j * 2 + 1],
        minX,
        minY,
        maxX,
        maxY,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Cohen-Sutherland style trivial accept / reject followed by an exact test.
  static bool _segmentCrossesRect(
    double x0,
    double y0,
    double x1,
    double y1,
    double minX,
    double minY,
    double maxX,
    double maxY,
  ) {
    if ((x0 >= minX && x0 <= maxX && y0 >= minY && y0 <= maxY) ||
        (x1 >= minX && x1 <= maxX && y1 >= minY && y1 <= maxY)) {
      return true;
    }
    if (math.max(x0, x1) < minX ||
        math.min(x0, x1) > maxX ||
        math.max(y0, y1) < minY ||
        math.min(y0, y1) > maxY) {
      return false;
    }
    final a = Vec2(x0, y0);
    final b = Vec2(x1, y1);
    final corners = [
      Vec2(minX, minY),
      Vec2(maxX, minY),
      Vec2(maxX, maxY),
      Vec2(minX, maxY),
    ];
    for (var i = 0; i < 4; i++) {
      if (segmentSegment(a, b, corners[i], corners[(i + 1) % 4]) != null) {
        return true;
      }
    }
    return false;
  }
}

/// The result of projecting a point onto a polyline.
class PolylineHit {
  const PolylineHit(this.point, this.segmentIndex, this.distance);

  final Vec2 point;
  final int segmentIndex;
  final double distance;
}
