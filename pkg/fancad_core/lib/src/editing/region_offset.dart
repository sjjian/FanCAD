import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clipper2/clipper2.dart';

import '../document/entity.dart';
import '../geometry/intersect.dart';
import '../geometry/vector.dart';

/// Offsets a REGION boundary by a signed distance.
///
/// Positive [signedDistance] shrinks the material and negative grows it,
/// because every loop is normalised so the material is on its left. The fast
/// path keeps lines and circular arcs analytic; an ellipse, spline or a join
/// that the analytic path cannot resolve falls back to a Clipper2 polygon
/// offset and sets [RegionGeometry.approximated].
class RegionOffset {
  const RegionOffset();

  RegionGeometry? apply(
    RegionGeometry geometry,
    double signedDistance, {
    double tolerance = 1e-3,
  }) {
    if (geometry.components.isEmpty ||
        !signedDistance.isFinite ||
        signedDistance.abs() < 1e-9) {
      return null;
    }
    final normalized = geometry.normalized();
    return _analytic(normalized, signedDistance, tolerance) ??
        _polygon(normalized, signedDistance, tolerance);
  }

  RegionGeometry? _analytic(
    RegionGeometry geometry,
    double distance,
    double tolerance,
  ) {
    final components = <RegionComponent>[];
    for (final component in geometry.components) {
      final outer = _offsetLoop(component.outer, distance, tolerance);
      if (outer == null) return null;
      final holes = <RegionLoop>[];
      for (final hole in component.holes) {
        final offset = _offsetLoop(hole, distance, tolerance);
        if (offset == null) return null;
        holes.add(offset);
      }
      components.add(RegionComponent(outer: outer, holes: holes));
    }
    return RegionGeometry(
      components: components,
      approximated: geometry.approximated,
    );
  }

  RegionLoop? _offsetLoop(RegionLoop loop, double distance, double tolerance) {
    final expanded = _expand(loop.curves);
    if (expanded == null || expanded.isEmpty) return null;
    if (expanded.length == 1) {
      final curve = expanded.single;
      final offset = _offsetCurve(curve, distance);
      if (offset == null) return null;
      if (curve is RegionConicArc && curve.isClosed) {
        return RegionLoop([offset]);
      }
      // A loop needs at least two pieces to close.
      if (!_near(curve.start, curve.end, tolerance)) return null;
      return RegionLoop([offset]);
    }
    final offset = <RegionCurve>[];
    for (final curve in expanded) {
      final moved = _offsetCurve(curve, distance);
      if (moved == null) return null;
      offset.add(moved);
    }
    final count = offset.length;
    for (var i = 0; i < count; i++) {
      final previous = (i - 1 + count) % count;
      final vertex = expanded[i].start;
      var a = offset[previous];
      var b = offset[i];
      if (_near(a.end, b.start, tolerance)) {
        // Keep the joint on the conic when one side is an arc: a midpoint of
        // two near-but-not-equal points can sit a hair off the circle.
        final join = a is RegionConicArc
            ? a.end
            : b is RegionConicArc
            ? b.start
            : a.end.lerp(b.start, 0.5);
        final nextA = _withEnd(a, join);
        final nextB = _withStart(b, join);
        if (nextA == null || nextB == null) return null;
        a = nextA;
        b = nextB;
      } else {
        final hits = _crossings(a, b)
            .where((hit) => _onCurve(a, hit, tolerance))
            .where((hit) => _onCurve(b, hit, tolerance))
            .toList();
        if (hits.isEmpty) return null;
        hits.sort(
          (left, right) => left
              .distanceSquaredTo(vertex)
              .compareTo(right.distanceSquaredTo(vertex)),
        );
        final join = hits.first;
        // A join far from the original corner means the offset has eaten a
        // feature or two edges nearly coincide. Let the polygon backend
        // resolve that instead of emitting a self-crossing loop.
        final reach = math.max(distance.abs() * 8, tolerance * 64);
        if (join.distanceTo(vertex) > reach) return null;
        a = _withEnd(a, join) ?? a;
        b = _withStart(b, join) ?? b;
      }
      offset[previous] = a;
      offset[i] = b;
    }
    for (var i = 0; i < count; i++) {
      final next = (i + 1) % count;
      if (!_near(offset[i].end, offset[next].start, tolerance)) return null;
      if (offset[i].length <= tolerance) return null;
    }
    return RegionLoop(offset);
  }

  /// Splits a straight polyline into line pieces so the join logic can trim
  /// them. Returns null when a curve has no analytic offset.
  List<RegionCurve>? _expand(List<RegionCurve> curves) {
    final out = <RegionCurve>[];
    for (final curve in curves) {
      switch (curve) {
        case RegionPolyline(:final points):
          final count = points.length ~/ 2;
          for (var i = 0; i < count; i++) {
            final start = Vec2(points[i * 2], points[i * 2 + 1]);
            final next = (i + 1) % count;
            final end = Vec2(points[next * 2], points[next * 2 + 1]);
            if (start.distanceTo(end) < 1e-12) continue;
            out.add(RegionLine(start: start, end: end));
          }
        case RegionSpline():
          return null;
        case RegionConicArc():
          if (_circleOf(curve) == null) return null;
          out.add(curve);
        case RegionLine():
          if (curve.length < 1e-12) continue;
          out.add(curve);
      }
    }
    return out;
  }

  RegionCurve? _offsetCurve(RegionCurve curve, double distance) {
    switch (curve) {
      case RegionLine(:final start, :final end):
        final direction = end - start;
        if (direction.lengthSquared < 1e-20) return null;
        final normal = direction.perpendicular.normalized() * distance;
        return RegionLine(start: start + normal, end: end + normal);
      case RegionConicArc():
        final circle = _circleOf(curve);
        if (circle == null) return null;
        final sign = curve.sweep < 0 ? 1.0 : -1.0;
        final radius = circle.radius + sign * distance;
        if (radius <= 1e-9) return null;
        final scale = radius / circle.radius;
        return RegionConicArc(
          center: curve.center,
          u: curve.u * scale,
          v: curve.v * scale,
          startParameter: curve.startParameter,
          sweep: curve.sweep,
        );
      case RegionPolyline():
      case RegionSpline():
        return null;
    }
    return null;
  }

  RegionCurve? _withEnd(RegionCurve curve, Vec2 end) {
    switch (curve) {
      case RegionLine(:final start):
        if (start.distanceTo(end) < 1e-9) return null;
        return RegionLine(start: start, end: end);
      case RegionConicArc():
        final sweep = _sweepTo(curve, end, atStart: false);
        if (sweep == null) return null;
        return RegionConicArc(
          center: curve.center,
          u: curve.u,
          v: curve.v,
          startParameter: curve.startParameter,
          sweep: sweep,
        );
      case RegionPolyline():
      case RegionSpline():
        return null;
    }
    return null;
  }

  RegionCurve? _withStart(RegionCurve curve, Vec2 start) {
    switch (curve) {
      case RegionLine(:final end):
        if (start.distanceTo(end) < 1e-9) return null;
        return RegionLine(start: start, end: end);
      case RegionConicArc():
        final sweep = _sweepTo(curve, start, atStart: true);
        if (sweep == null) return null;
        final parameter = _parameterOf(curve, start);
        if (parameter == null) return null;
        return RegionConicArc(
          center: curve.center,
          u: curve.u,
          v: curve.v,
          startParameter: parameter,
          sweep: sweep,
        );
      case RegionPolyline():
      case RegionSpline():
        return null;
    }
    return null;
  }

  List<Vec2> _crossings(RegionCurve a, RegionCurve b) {
    final circleA = a is RegionConicArc ? _circleOf(a) : null;
    final circleB = b is RegionConicArc ? _circleOf(b) : null;
    if (a is RegionLine && b is RegionLine) {
      final hit = Intersect.lineLine(a.start, a.end, b.start, b.end);
      return hit == null ? const [] : [hit];
    }
    if (a is RegionLine && circleB != null) {
      return Intersect.lineCircle(
        a.start,
        a.end,
        circleB.center,
        circleB.radius,
      );
    }
    if (circleA != null && b is RegionLine) {
      return Intersect.lineCircle(
        b.start,
        b.end,
        circleA.center,
        circleA.radius,
      );
    }
    if (circleA != null && circleB != null) {
      return Intersect.circleCircle(
        circleA.center,
        circleA.radius,
        circleB.center,
        circleB.radius,
      );
    }
    return const [];
  }

  bool _onCurve(RegionCurve curve, Vec2 point, double tolerance) {
    switch (curve) {
      case RegionLine(:final start, :final end):
        final direction = end - start;
        final length = direction.length;
        if (length < 1e-12) return false;
        // The join may fall just outside the offset segment: growing a corner
        // extends both neighbours until they meet again.
        final distance = ((point - start).cross(direction) / length).abs();
        return distance <= tolerance;
      case RegionConicArc():
        final parameter = _parameterOf(curve, point);
        return parameter != null && _relative(curve, parameter) != null;
      case RegionPolyline():
      case RegionSpline():
        return false;
    }
    return false;
  }

  /// The signed sweep from the start of [curve] to the parameter of [point].
  ///
  /// When [atStart] is false the hit trims the end; when true it becomes the
  /// new start, so the returned value is the remaining sweep.
  double? _sweepTo(RegionConicArc curve, Vec2 point, {required bool atStart}) {
    final parameter = _parameterOf(curve, point);
    if (parameter == null) return null;
    final delta = _relative(curve, parameter);
    if (delta == null) return null;
    final swept = delta.abs();
    final total = curve.sweep.abs();
    if (swept > total + 1e-9) return null;
    if (atStart) {
      final remaining = total - swept;
      if (remaining <= 1e-9) return null;
      return curve.sweep < 0 ? -remaining : remaining;
    }
    if (swept <= 1e-9) return null;
    return curve.sweep < 0 ? -swept : swept;
  }

  /// How far along [curve]'s parameter span [parameter] sits, signed like
  /// [curve.sweep] and measured from its start.
  double? _relative(RegionConicArc curve, double parameter) {
    final direction = curve.sweep < 0 ? -1.0 : 1.0;
    var delta = (parameter - curve.startParameter) * direction;
    delta %= math.pi * 2;
    if (delta < 0) delta += math.pi * 2;
    if (delta > curve.sweep.abs() + 1e-9) return null;
    return delta * direction;
  }

  /// The parameter of [point] on the circle of [curve].
  double? _parameterOf(RegionConicArc curve, Vec2 point) {
    final circle = _circleOf(curve);
    if (circle == null) return null;
    final dx = point.x - curve.center.x;
    final dy = point.y - curve.center.y;
    final u = curve.u;
    final v = curve.v;
    final uu = u.lengthSquared;
    final vv = v.lengthSquared;
    if (uu < 1e-20 || vv < 1e-20) return null;
    final cosine = (dx * u.x + dy * u.y) / uu;
    final sine = (dx * v.x + dy * v.y) / vv;
    if (cosine.abs() < 1e-12 && sine.abs() < 1e-12) return null;
    return math.atan2(sine, cosine);
  }

  _Circle? _circleOf(RegionConicArc curve) {
    final u = curve.u;
    final v = curve.v;
    final ul = u.length;
    final vl = v.length;
    if (ul < 1e-12 || vl < 1e-12) return null;
    if ((ul - vl).abs() > 1e-8 * math.max(ul, vl)) return null;
    if (u.dot(v).abs() > 1e-8 * ul * vl) return null;
    return _Circle(curve.center, (ul + vl) / 2);
  }

  RegionGeometry? _polygon(
    RegionGeometry geometry,
    double distance,
    double tolerance,
  ) {
    final safeTolerance = math.max(tolerance, 1e-9);
    final scale = 1 / safeTolerance;
    final paths = <Path64>[];
    for (final component in geometry.components) {
      paths.add(_path(component.outer, scale, safeTolerance));
      for (final hole in component.holes) {
        paths.add(_path(hole, scale, safeTolerance));
      }
    }
    final result = Clipper.inflatePaths(
      paths: paths,
      delta: -distance * scale,
      joinType: JoinType.miter,
      endType: EndType.polygon,
      miterLimit: 10,
    );
    final loops = <RegionLoop>[];
    for (final path in result) {
      if (path.length < 3) continue;
      final points = Float64List(path.length * 2);
      for (var i = 0; i < path.length; i++) {
        points[i * 2] = path[i].x / scale;
        points[i * 2 + 1] = path[i].y / scale;
      }
      loops.add(RegionLoop([RegionPolyline(points)]));
    }
    if (loops.isEmpty) return null;
    return RegionGeometry.fromLoops(
      loops,
      approximated: true,
      tolerance: safeTolerance,
    );
  }

  Path64 _path(RegionLoop loop, double scale, double tolerance) => [
    for (final point in loop.samplePoints(tolerance))
      Point64.fromDouble(point.x, point.y, scale: scale),
  ];

  bool _near(Vec2 a, Vec2 b, double tolerance) =>
      a.distanceSquaredTo(b) <=
      math.max(tolerance, 1e-9) * math.max(tolerance, 1e-9);
}

class _Circle {
  const _Circle(this.center, this.radius);

  final Vec2 center;
  final double radius;
}
