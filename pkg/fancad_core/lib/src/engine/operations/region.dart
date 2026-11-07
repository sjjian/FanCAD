import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clipper2/clipper2.dart';

import '../../geometry/bounds.dart';
import '../../geometry/flatten.dart';
import '../../geometry/intersect.dart';
import '../../geometry/vector.dart';
import '../../model/entity/entity.dart';

/// Builds curve-preserving REGION loops from closed drawing entities.
///
/// Closed polylines, circles and ellipses become a single loop. Open lines,
/// arcs and polyline segments are chained end-to-end. Curves that do not
/// close are ignored.
class RegionBuilder {
  const RegionBuilder();

  RegionGeometry? build(Iterable<CadEntity> entities) {
    final closed = <RegionLoop>[];
    final pool = <RegionCurve>[];
    for (final entity in entities) {
      _addEntity(entity, closed, pool);
    }
    final loops = <RegionLoop>[...closed];
    if (pool.isNotEmpty) {
      loops.addAll(_chain(pool));
    }
    if (loops.isEmpty) return null;
    final geometry = RegionGeometry.fromLoops(loops);
    return geometry.components.isEmpty ? null : geometry;
  }

  void _addEntity(
    CadEntity entity,
    List<RegionLoop> closed,
    List<RegionCurve> pool,
  ) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        pool.add(RegionLine(start: start, end: end));
      case ArcEntity(
        :final center,
        :final radius,
        :final startAngle,
        :final endAngle,
      ):
        final sweep = angularSweep(startAngle, endAngle);
        final curve = RegionConicArc(
          center: center,
          u: Vec2(radius, 0),
          v: Vec2(0, radius),
          startParameter: startAngle,
          sweep: sweep,
        );
        if (curve.isClosed) {
          closed.add(RegionLoop([curve]));
        } else {
          pool.add(curve);
        }
      case CircleEntity(:final center, :final radius):
        closed.add(
          RegionLoop([
            RegionConicArc(
              center: center,
              u: Vec2(radius, 0),
              v: Vec2(0, radius),
              startParameter: 0,
              sweep: math.pi * 2,
            ),
          ]),
        );
      case EllipseEntity(
        :final center,
        :final majorAxis,
        :final ratio,
        :final startParam,
        :final endParam,
      ):
        final curve = RegionConicArc(
          center: center,
          u: majorAxis,
          v: majorAxis.perpendicular * ratio,
          startParameter: startParam,
          sweep: entity.sweep,
        );
        if (curve.isClosed || (startParam - endParam).abs() < 1e-9) {
          closed.add(RegionLoop([curve]));
        } else {
          pool.add(curve);
        }
      case PolylineEntity(closed: final isClosed):
        final count = entity.vertexCount;
        final segments = isClosed ? count : count - 1;
        final curves = <RegionCurve>[];
        for (var i = 0; i < segments; i++) {
          final a = entity.vertexAt(i);
          final b = entity.vertexAt((i + 1) % count);
          final bulge = entity.bulgeAt(i);
          final arc = Flatten.bulgeArc(a, b, bulge);
          if (arc == null) {
            curves.add(RegionLine(start: a, end: b));
          } else {
            curves.add(
              RegionConicArc(
                center: arc.center,
                u: Vec2(arc.radius, 0),
                v: Vec2(0, arc.radius),
                startParameter: (a - arc.center).angle,
                sweep: 4 * math.atan(bulge),
              ),
            );
          }
        }
        if (isClosed) {
          closed.add(RegionLoop(curves));
        } else {
          pool.addAll(curves);
        }
      case SplineEntity(
        :final controlPoints,
        :final knots,
        :final weights,
        :final degree,
        closed: final splineClosed,
      ):
        if (controlPoints.isEmpty) return;
        final curve = RegionSpline(
          controlPoints: controlPoints,
          knots: knots,
          weights: weights,
          degree: degree,
          closed: splineClosed,
        );
        if (splineClosed) {
          closed.add(RegionLoop([curve]));
        } else {
          pool.add(curve);
        }
      default:
        break;
    }
  }

  List<RegionLoop> _chain(List<RegionCurve> curves) {
    var box = const Bounds2.empty();
    for (final curve in curves) {
      box = box.union(curve.bounds);
    }
    final tolerance = math.max(1e-6, box.diagonal.abs() * 1e-7);
    bool near(Vec2 a, Vec2 b) => (a - b).length <= tolerance;
    final used = <int>{};
    final loops = <RegionLoop>[];
    for (var i = 0; i < curves.length; i++) {
      if (used.contains(i)) continue;
      final chain = <RegionCurve>[curves[i]];
      used.add(i);
      var current = curves[i];
      var guard = 0;
      while (guard++ <= curves.length) {
        if (near(current.end, chain.first.start)) break;
        var next = -1;
        var reverse = false;
        for (var j = 0; j < curves.length; j++) {
          if (used.contains(j)) continue;
          if (near(curves[j].start, current.end)) {
            next = j;
            break;
          }
          if (near(curves[j].end, current.end)) {
            next = j;
            reverse = true;
            break;
          }
        }
        if (next < 0) break;
        used.add(next);
        current = reverse ? curves[next].reversed() : curves[next];
        chain.add(current);
      }
      if (chain.length >= 2 && near(current.end, chain.first.start)) {
        loops.add(RegionLoop(chain));
      }
    }
    return loops;
  }
}

enum RegionOp { union, subtract, intersect, xor }

/// A 2D REGION boolean implementation.
///
/// The current backend flattens every curve to a polyline and uses Clipper2.
/// The result is therefore polygonal and [RegionGeometry.approximated] is set.
/// An exact line/conic arrangement can replace this class without changing the
/// entity or file format.
abstract interface class RegionBoolean {
  RegionGeometry apply(
    RegionOp op,
    List<RegionGeometry> operands, {
    double tolerance = 1e-3,
  });
}

/// Clipper2-backed polygon boolean.
class ClipperRegionBoolean implements RegionBoolean {
  const ClipperRegionBoolean();

  @override
  RegionGeometry apply(
    RegionOp op,
    List<RegionGeometry> operands, {
    double tolerance = 1e-3,
  }) {
    final geometry = [for (final operand in operands) operand.normalized()]
      ..removeWhere((operand) => operand.components.isEmpty);
    if (geometry.isEmpty) return const RegionGeometry(components: []);
    final scale = tolerance > 0 ? 1 / tolerance : 1000.0;
    final paths = [
      for (final operand in geometry) ...[
        for (final component in operand.components) ...[
          _path(component.outer, scale, tolerance),
          for (final hole in component.holes) _path(hole, scale, tolerance),
        ],
      ],
    ];
    final subject = [
      for (final component in geometry.first.components) ...[
        _path(component.outer, scale, tolerance),
        for (final hole in component.holes) _path(hole, scale, tolerance),
      ],
    ];
    final clip = [
      for (final operand in geometry.skip(1)) ...[
        for (final component in operand.components) ...[
          _path(component.outer, scale, tolerance),
          for (final hole in component.holes) _path(hole, scale, tolerance),
        ],
      ],
    ];
    Paths64 result;
    switch (op) {
      case RegionOp.union:
        result = Clipper.union(subject: paths, fillRule: FillRule.nonZero);
      case RegionOp.subtract:
        result = Clipper.difference(
          subject: subject,
          clip: clip,
          fillRule: FillRule.nonZero,
        );
      case RegionOp.intersect:
        result = Clipper.intersect(
          subject: subject,
          clip: clip,
          fillRule: FillRule.nonZero,
        );
      case RegionOp.xor:
        result = Clipper.xor(
          subject: subject,
          clip: clip,
          fillRule: FillRule.nonZero,
        );
    }
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
    if (loops.isEmpty) return const RegionGeometry(components: []);
    return RegionGeometry.fromLoops(
      loops,
      approximated: true,
      tolerance: math.max(tolerance, 1e-9),
    );
  }

  Path64 _path(RegionLoop loop, double scale, double tolerance) => [
    for (final point in loop.samplePoints(tolerance))
      Point64.fromDouble(point.x, point.y, scale: scale),
  ];
}

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

/// Rounds corners of a REGION boundary with a tangent arc.
///
/// Straight and circular-arc pairs use the exact offset-locus construction.
/// A corner involving an ellipse or a spline is solved numerically on the two
/// offset curves. Trimming an ellipse keeps its conic form; trimming a spline
/// falls back to a sampled polyline and marks the result approximated.
class RegionFillet {
  const RegionFillet();

  /// Rounds the corner nearest [pick].
  RegionGeometry? vertex(
    RegionGeometry geometry,
    Vec2 pick,
    double radius, {
    double tolerance = 1e-6,
  }) {
    if (!(radius > 0) || !radius.isFinite) return null;
    final normalized = geometry.normalized();
    _LocatedCorner? best;
    var bestDistance = double.infinity;
    for (
      var component = 0;
      component < normalized.components.length;
      component++
    ) {
      final loops = _loopsOf(normalized.components[component]);
      for (var loop = 0; loop < loops.length; loop++) {
        for (final corner in _corners(loops[loop], radius, tolerance)) {
          final distance = corner.point.distanceSquaredTo(pick);
          if (distance < bestDistance) {
            bestDistance = distance;
            best = _LocatedCorner(component, loop, corner);
          }
        }
      }
    }
    if (best == null) return null;
    final result = _filletLoop(
      _loopsOf(normalized.components[best.component])[best.loop],
      best.corner.index,
      radius,
      tolerance,
    );
    return _replace(normalized, best.component, best.loop, result);
  }

  /// Rounds every corner that the radius fits.
  RegionGeometry? all(
    RegionGeometry geometry,
    double radius, {
    double tolerance = 1e-6,
  }) {
    if (!(radius > 0) || !radius.isFinite) return null;
    final normalized = geometry.normalized();
    final components = <RegionComponent>[];
    var changed = false;
    var approximated = normalized.approximated;
    for (final component in normalized.components) {
      final loops = _loopsOf(component);
      final out = <RegionLoop>[];
      for (final loop in loops) {
        final filleted = _filletAllLoop(loop, radius, tolerance);
        out.add(filleted?.loop ?? loop);
        if (filleted != null) {
          changed = true;
          approximated = approximated || filleted.approximated;
        }
      }
      components.add(
        RegionComponent(outer: out.first, holes: out.skip(1).toList()),
      );
    }
    if (!changed) return null;
    return RegionGeometry(components: components, approximated: approximated);
  }

  RegionGeometry? _replace(
    RegionGeometry geometry,
    int componentIndex,
    int loopIndex,
    _FilletLoopResult? replacement,
  ) {
    if (replacement == null) return null;
    final components = <RegionComponent>[];
    for (var i = 0; i < geometry.components.length; i++) {
      final loops = _loopsOf(geometry.components[i]);
      if (i != componentIndex) {
        components.add(geometry.components[i]);
        continue;
      }
      loops[loopIndex] = replacement.loop;
      components.add(
        RegionComponent(outer: loops.first, holes: loops.skip(1).toList()),
      );
    }
    return RegionGeometry(
      components: components,
      approximated: geometry.approximated || replacement.approximated,
    );
  }

  List<RegionLoop> _loopsOf(RegionComponent component) => [
    component.outer,
    ...component.holes,
  ];

  _FilletLoopResult? _filletAllLoop(
    RegionLoop loop,
    double radius,
    double tolerance,
  ) {
    var current = loop;
    var guard = 0;
    var approximated = false;
    while (true) {
      final corners = _corners(current, radius, tolerance);
      if (corners.isEmpty) break;
      final next = _filletLoop(current, corners.first.index, radius, tolerance);
      if (next == null) break;
      current = next.loop;
      approximated = approximated || next.approximated;
      if (++guard > 10000) break;
    }
    if (guard == 0) return null;
    return _FilletLoopResult(current, approximated);
  }

  _FilletLoopResult? _filletLoop(
    RegionLoop loop,
    int cornerIndex,
    double radius,
    double tolerance,
  ) {
    final curves = _expand(loop.curves);
    if (curves == null || curves.length < 2) return null;
    final count = curves.length;
    if (cornerIndex < 0 || cornerIndex >= count) return null;
    final joint = _joint(curves, cornerIndex, radius, tolerance);
    if (joint == null) return null;
    final incomingIndex = joint.incomingIndex;
    final out = <RegionCurve>[];
    for (var i = 0; i < count; i++) {
      if (i == cornerIndex && cornerIndex != 0) out.add(joint.arc);
      if (i == incomingIndex) {
        out.add(joint.incoming);
      } else if (i == cornerIndex) {
        if (cornerIndex == 0) out.add(joint.arc);
        out.add(joint.outgoing);
      } else {
        out.add(curves[i]);
      }
    }
    for (var i = 0; i < out.length; i++) {
      final next = (i + 1) % out.length;
      if (out[i].end.distanceTo(out[next].start) > tolerance * 10) {
        return null;
      }
    }
    return _FilletLoopResult(RegionLoop(out), joint.approximated);
  }

  List<_Corner> _corners(RegionLoop loop, double radius, double tolerance) {
    final curves = _expand(loop.curves);
    if (curves == null || curves.length < 2) return const [];
    final out = <_Corner>[];
    for (var i = 0; i < curves.length; i++) {
      final previous = curves[(i - 1 + curves.length) % curves.length];
      final current = curves[i];
      if (previous.end.distanceTo(current.start) > tolerance) continue;
      if (_joint(curves, i, radius, tolerance) != null) {
        out.add(_Corner(i, current.start));
      }
    }
    return out;
  }

  /// The best fillet at the joint between `curves[index - 1]` and
  /// `curves[index]`.
  _FilletJoint? _joint(
    List<RegionCurve> curves,
    int index,
    double radius,
    double tolerance,
  ) {
    final count = curves.length;
    final incomingIndex = (index - 1 + count) % count;
    final incoming = curves[incomingIndex];
    final outgoing = curves[index];
    if (!_filletable(incoming) || !_filletable(outgoing)) return null;
    final corner = outgoing.start;
    if (incoming.end.distanceTo(corner) > tolerance) return null;

    final incomingTangent = _tangentAtEnd(incoming);
    final outgoingTangent = _tangentAtStart(outgoing);
    if (incomingTangent == null || outgoingTangent == null) return null;
    final back = -incomingTangent;
    final alpha = math.acos(back.dot(outgoingTangent).clamp(-1.0, 1.0));
    if (alpha < 1e-9 || alpha > math.pi - 1e-9) return null;
    final bisector = (back + outgoingTangent).normalized();
    if (bisector.lengthSquared < 1e-20) return null;

    if (_isSimple(incoming) && _isSimple(outgoing)) {
      return _jointSimple(
        incomingIndex,
        incoming,
        outgoing,
        corner,
        bisector,
        incomingTangent,
        outgoingTangent,
        radius,
        tolerance,
      );
    }
    return _jointNumeric(
      incomingIndex,
      incoming,
      outgoing,
      corner,
      bisector,
      radius,
      tolerance,
    );
  }

  _FilletJoint? _jointSimple(
    int incomingIndex,
    RegionCurve incoming,
    RegionCurve outgoing,
    Vec2 corner,
    Vec2 bisector,
    Vec2 incomingTangent,
    Vec2 outgoingTangent,
    double radius,
    double tolerance,
  ) {
    _Candidate? best;
    for (final first in _offsetLoci(incoming, radius)) {
      for (final second in _offsetLoci(outgoing, radius)) {
        for (final center in _intersections(first, second)) {
          final delta = center - corner;
          if (delta.lengthSquared < 1e-20 || delta.dot(bisector) <= 0) {
            continue;
          }
          final tangentIn = _tangentPoint(incoming, center, radius, tolerance);
          final tangentOut = _tangentPoint(outgoing, center, radius, tolerance);
          if (tangentIn == null || tangentOut == null) continue;
          final normalIn = incomingTangent.perpendicular;
          final sideIn = bisector.dot(normalIn) >= 0 ? 1.0 : -1.0;
          if ((center - tangentIn).dot(normalIn) * sideIn <= 0) continue;
          final normalOut = outgoingTangent.perpendicular;
          final sideOut = bisector.dot(normalOut) >= 0 ? 1.0 : -1.0;
          if ((center - tangentOut).dot(normalOut) * sideOut <= 0) continue;

          final trimmedIn = _trimEnd(incoming, tangentIn, tolerance);
          final trimmedOut = _trimStart(outgoing, tangentOut, tolerance);
          if (trimmedIn == null || trimmedOut == null) continue;
          final arc = _arcBetween(center, radius, tangentIn, tangentOut);
          if (arc == null) continue;
          final joint = _makeJoint(
            incomingIndex,
            trimmedIn,
            trimmedOut,
            arc,
            incomingTangent,
            outgoingTangent,
            false,
            tolerance,
          );
          if (joint == null) continue;
          final score = delta.length;
          if (best == null || score < best.score) {
            best = _Candidate(joint, score);
          }
        }
      }
    }
    return best?.joint;
  }

  _FilletJoint? _jointNumeric(
    int incomingIndex,
    RegionCurve incoming,
    RegionCurve outgoing,
    Vec2 corner,
    Vec2 bisector,
    double radius,
    double tolerance,
  ) {
    final first = _ParamCurve.of(incoming);
    final second = _ParamCurve.of(outgoing);
    const firstSeeds = [0.999, 0.95, 0.85, 0.7, 0.5, 0.3];
    const secondSeeds = [0.001, 0.05, 0.15, 0.3, 0.5, 0.7];
    _Candidate? best;
    final residual = math.max(tolerance * 0.1, 1e-9);
    for (final sideIn in const [1.0, -1.0]) {
      for (final sideOut in const [1.0, -1.0]) {
        for (final uSeed in firstSeeds) {
          for (final vSeed in secondSeeds) {
            final root = _solveOffset(
              first,
              second,
              uSeed,
              vSeed,
              sideIn,
              sideOut,
              radius,
              residual,
            );
            if (root == null) continue;
            final center = _offsetPoint(first, root.u, sideIn, radius);
            final other = _offsetPoint(second, root.v, sideOut, radius);
            if (center.distanceTo(other) > residual * 50) continue;
            final delta = center - corner;
            if (delta.lengthSquared < 1e-20 || delta.dot(bisector) <= 0) {
              continue;
            }
            final tangentIn = first.pointAt(root.u);
            final tangentOut = second.pointAt(root.v);
            final trimmedIn = first.isSpline
                ? _trimSpline(first, 0, root.u, tolerance)
                : _trimEnd(incoming, tangentIn, tolerance);
            final trimmedOut = second.isSpline
                ? _trimSpline(second, root.v, 1, tolerance)
                : _trimStart(outgoing, tangentOut, tolerance);
            if (trimmedIn == null || trimmedOut == null) continue;
            final arc = _arcBetween(center, radius, tangentIn, tangentOut);
            if (arc == null) continue;
            final joint = _makeJoint(
              incomingIndex,
              trimmedIn,
              trimmedOut,
              arc,
              first.tangentAt(root.u),
              second.tangentAt(root.v),
              trimmedIn is RegionPolyline || trimmedOut is RegionPolyline,
              tolerance,
            );
            if (joint == null) continue;
            final score = delta.length;
            if (best == null || score < best.score) {
              best = _Candidate(joint, score);
            }
          }
        }
      }
    }
    return best?.joint;
  }

  _FilletJoint? _makeJoint(
    int incomingIndex,
    RegionCurve incoming,
    RegionCurve outgoing,
    RegionConicArc arc,
    Vec2 incomingTangent,
    Vec2 outgoingTangent,
    bool approximated,
    double tolerance,
  ) {
    if (incoming.length <= tolerance * 10 ||
        outgoing.length <= tolerance * 10) {
      return null;
    }
    if (arc.start.distanceTo(incoming.end) > tolerance * 10 ||
        arc.end.distanceTo(outgoing.start) > tolerance * 10) {
      return null;
    }
    final startTangent = _tangentAtStart(arc);
    final endTangent = _tangentAtEnd(arc);
    if (startTangent == null || endTangent == null) return null;
    if (startTangent.dot(incomingTangent) < 0.5 ||
        endTangent.dot(outgoingTangent) < 0.5) {
      return null;
    }
    return _FilletJoint(
      incomingIndex: incomingIndex,
      incoming: incoming,
      outgoing: outgoing,
      arc: arc,
      approximated: approximated,
    );
  }

  _Root? _solveOffset(
    _ParamCurve first,
    _ParamCurve second,
    double u,
    double v,
    double sideIn,
    double sideOut,
    double radius,
    double residual,
  ) {
    for (var iteration = 0; iteration < 60; iteration++) {
      final a = _offsetPoint(first, u, sideIn, radius);
      final b = _offsetPoint(second, v, sideOut, radius);
      final error = a - b;
      if (error.length <= residual) return _Root(u, v);
      const step = 1e-5;
      final uHigh = math.min(1.0, u + step);
      final uLow = math.max(0.0, u - step);
      final vHigh = math.min(1.0, v + step);
      final vLow = math.max(0.0, v - step);
      if (uHigh - uLow < 1e-12 || vHigh - vLow < 1e-12) return null;
      final du =
          (_offsetPoint(first, uHigh, sideIn, radius) -
              _offsetPoint(first, uLow, sideIn, radius)) /
          (uHigh - uLow);
      final dv =
          (_offsetPoint(second, vHigh, sideOut, radius) -
              _offsetPoint(second, vLow, sideOut, radius)) /
          (vHigh - vLow);
      final j11 = du.x;
      final j12 = -dv.x;
      final j21 = du.y;
      final j22 = -dv.y;
      final determinant = j11 * j22 - j12 * j21;
      if (determinant.abs() < 1e-12) return null;
      var deltaU = (-error.x * j22 + j12 * error.y) / determinant;
      var deltaV = (-j11 * error.y + error.x * j21) / determinant;
      if (!deltaU.isFinite || !deltaV.isFinite) return null;
      if (deltaU.abs() > 0.25) deltaU = deltaU.sign * 0.25;
      if (deltaV.abs() > 0.25) deltaV = deltaV.sign * 0.25;
      u = (u + deltaU).clamp(0.0, 1.0).toDouble();
      v = (v + deltaV).clamp(0.0, 1.0).toDouble();
    }
    final a = _offsetPoint(first, u, sideIn, radius);
    final b = _offsetPoint(second, v, sideOut, radius);
    return (a - b).length <= residual * 10 ? _Root(u, v) : null;
  }

  Vec2 _offsetPoint(
    _ParamCurve curve,
    double parameter,
    double side,
    double radius,
  ) {
    final tangent = curve.tangentAt(parameter);
    return curve.pointAt(parameter) + tangent.perpendicular * (side * radius);
  }

  bool _filletable(RegionCurve curve) {
    if (curve is RegionLine) return curve.length > 1e-9;
    if (curve is RegionConicArc) {
      return curve.u.length > 1e-9 && curve.v.length > 1e-9;
    }
    if (curve is RegionSpline) {
      return curve.controlPointCount >= 2;
    }
    return false;
  }

  bool _isSimple(RegionCurve curve) {
    if (curve is RegionLine) return true;
    return curve is RegionConicArc && _circleOf(curve) != null;
  }

  List<_Locus> _offsetLoci(RegionCurve curve, double distance) {
    switch (curve) {
      case RegionLine(:final start, :final end):
        final normal = (end - start).normalized().perpendicular * distance;
        return [
          _LineLocus(start + normal, end + normal),
          _LineLocus(start - normal, end - normal),
        ];
      case RegionConicArc():
        final circle = _circleOf(curve);
        if (circle == null) return const [];
        return [
          _CircleLocus(circle.center, circle.radius + distance),
          if (circle.radius >= distance)
            _CircleLocus(circle.center, circle.radius - distance),
        ];
      case RegionPolyline():
      case RegionSpline():
        return const [];
    }
    return const [];
  }

  List<Vec2> _intersections(_Locus first, _Locus second) {
    if (first is _LineLocus && second is _LineLocus) {
      final hit = Intersect.lineLine(
        first.start,
        first.end,
        second.start,
        second.end,
      );
      return hit == null ? const [] : [hit];
    }
    if (first is _LineLocus && second is _CircleLocus) {
      return Intersect.lineCircle(
        first.start,
        first.end,
        second.center,
        second.radius,
      );
    }
    if (first is _CircleLocus && second is _LineLocus) {
      return Intersect.lineCircle(
        second.start,
        second.end,
        first.center,
        first.radius,
      );
    }
    if (first is _CircleLocus && second is _CircleLocus) {
      return Intersect.circleCircle(
        first.center,
        first.radius,
        second.center,
        second.radius,
      );
    }
    return const [];
  }

  /// The point on [curve] nearest [center]; null when the height is not the
  /// requested radius or the point falls outside the curve's own span.
  Vec2? _tangentPoint(
    RegionCurve curve,
    Vec2 center,
    double radius,
    double tolerance,
  ) {
    switch (curve) {
      case RegionLine(:final start, :final end):
        final direction = end - start;
        final length = direction.length;
        if (length < 1e-12) return null;
        final along = (center - start).dot(direction) / length;
        if (along < -tolerance || along > length + tolerance) return null;
        final point = start + direction.normalized() * along;
        if ((point.distanceTo(center) - radius).abs() > tolerance * 10) {
          return null;
        }
        return point;
      case RegionConicArc():
        final circle = _circleOf(curve);
        if (circle == null) return null;
        final delta = center - circle.center;
        final distance = delta.length;
        if (distance < 1e-12) return null;
        final point = circle.center + delta * (circle.radius / distance);
        if ((point.distanceTo(center) - radius).abs() > tolerance * 10) {
          return null;
        }
        final parameter = _parameterOf(curve, point);
        if (parameter == null || _relative(curve, parameter) == null) {
          return null;
        }
        return point;
      case RegionPolyline():
      case RegionSpline():
        return null;
    }
    return null;
  }

  RegionCurve? _trimEnd(RegionCurve curve, Vec2 point, double tolerance) {
    if (curve is RegionLine) {
      if (curve.start.distanceTo(point) <= tolerance) return null;
      return RegionLine(start: curve.start, end: point);
    }
    if (curve is RegionConicArc) {
      final parameter = _parameterOf(curve, point);
      if (parameter == null) return null;
      final delta = _relative(curve, parameter);
      if (delta == null) return null;
      final swept = delta.abs();
      final total = curve.sweep.abs();
      if (swept <= 1e-9 || swept >= total - 1e-9) return null;
      return RegionConicArc(
        center: curve.center,
        u: curve.u,
        v: curve.v,
        startParameter: curve.startParameter,
        sweep: curve.sweep < 0 ? -swept : swept,
      );
    }
    return null;
  }

  RegionCurve? _trimStart(RegionCurve curve, Vec2 point, double tolerance) {
    if (curve is RegionLine) {
      if (curve.end.distanceTo(point) <= tolerance) return null;
      return RegionLine(start: point, end: curve.end);
    }
    if (curve is RegionConicArc) {
      final parameter = _parameterOf(curve, point);
      if (parameter == null) return null;
      final delta = _relative(curve, parameter);
      if (delta == null) return null;
      final swept = delta.abs();
      final total = curve.sweep.abs();
      final remaining = total - swept;
      if (swept <= 1e-9 || remaining <= 1e-9) return null;
      return RegionConicArc(
        center: curve.center,
        u: curve.u,
        v: curve.v,
        startParameter: parameter,
        sweep: curve.sweep < 0 ? -remaining : remaining,
      );
    }
    return null;
  }

  RegionCurve? _trimSpline(
    _ParamCurve curve,
    double from,
    double to,
    double tolerance,
  ) {
    final source = curve.curve;
    if (source is RegionSpline) {
      final span = source.rangeEnd - source.rangeStart;
      final start = source.rangeStart + span * from.clamp(0.0, 1.0);
      final end = source.rangeStart + span * to.clamp(0.0, 1.0);
      final trimmed = source.withRange(start, end);
      if (trimmed.length > tolerance * 10) return trimmed;
    }
    final points = curve.pointsBetween(from, to);
    if (points.length < 2) return null;
    final buffer = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      buffer[i * 2] = points[i].x;
      buffer[i * 2 + 1] = points[i].y;
    }
    final polyline = RegionPolyline(buffer);
    if (polyline.length <= tolerance * 10) return null;
    return polyline;
  }

  RegionConicArc? _arcBetween(
    Vec2 center,
    double radius,
    Vec2 start,
    Vec2 end,
  ) {
    final startAngle = (start - center).angle;
    final endAngle = (end - center).angle;
    final forward = angularSweep(startAngle, endAngle);
    final sweep = forward <= math.pi ? forward : forward - math.pi * 2;
    if (sweep.abs() < 1e-9) return null;
    return RegionConicArc(
      center: center,
      u: Vec2(radius, 0),
      v: Vec2(0, radius),
      startParameter: startAngle,
      sweep: sweep,
    );
  }

  Vec2? _tangentAtStart(RegionCurve curve) => _tangent(curve, atStart: true);

  Vec2? _tangentAtEnd(RegionCurve curve) => _tangent(curve, atStart: false);

  Vec2? _tangent(RegionCurve curve, {required bool atStart}) {
    switch (curve) {
      case RegionLine(:final start, :final end):
        final direction = end - start;
        return direction.lengthSquared < 1e-20 ? null : direction.normalized();
      case RegionConicArc():
        final parameter = atStart
            ? curve.startParameter
            : curve.startParameter + curve.sweep;
        final derivative =
            curve.u * -math.sin(parameter) + curve.v * math.cos(parameter);
        final direction = curve.sweep < 0 ? -derivative : derivative;
        return direction.lengthSquared < 1e-20 ? null : direction.normalized();
      case RegionSpline():
        final samples = curve.samplePoints(1e-3);
        if (samples.length < 2) return null;
        final direction = atStart
            ? samples[1] - samples.first
            : samples.last - samples[samples.length - 2];
        return direction.lengthSquared < 1e-20 ? null : direction.normalized();
      case RegionPolyline():
        return null;
    }
    return null;
  }

  double? _parameterOf(RegionConicArc curve, Vec2 point) {
    final u = curve.u;
    final v = curve.v;
    final determinant = u.x * v.y - u.y * v.x;
    if (determinant.abs() < 1e-20) return null;
    final delta = point - curve.center;
    final cosine = (delta.x * v.y - delta.y * v.x) / determinant;
    final sine = (u.x * delta.y - u.y * delta.x) / determinant;
    if (cosine.abs() < 1e-12 && sine.abs() < 1e-12) return null;
    return math.atan2(sine, cosine);
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

  _FilletCircle? _circleOf(RegionConicArc curve) {
    final u = curve.u;
    final v = curve.v;
    final ul = u.length;
    final vl = v.length;
    if (ul < 1e-12 || vl < 1e-12) return null;
    if ((ul - vl).abs() > 1e-8 * math.max(ul, vl)) return null;
    if (u.dot(v).abs() > 1e-8 * ul * vl) return null;
    return _FilletCircle(curve.center, (ul + vl) / 2);
  }

  List<RegionCurve>? _expand(List<RegionCurve> curves) {
    final out = <RegionCurve>[];
    for (final curve in curves) {
      if (curve is! RegionPolyline) {
        out.add(curve);
        continue;
      }
      final count = curve.pointCount;
      for (var i = 0; i < count; i++) {
        final start = Vec2(curve.points[i * 2], curve.points[i * 2 + 1]);
        final next = (i + 1) % count;
        final end = Vec2(curve.points[next * 2], curve.points[next * 2 + 1]);
        if (start.distanceTo(end) < 1e-12) continue;
        out.add(RegionLine(start: start, end: end));
      }
    }
    return out;
  }
}

/// A curve with a local `[0, 1]` parameter and a consistent tangent.
///
/// The sampled list is only populated for splines; every other type evaluates
/// its real curve. That keeps ellipse trimming exact while giving the numeric
/// solver a usable tangent for a spline.
class _ParamCurve {
  _ParamCurve._(this.curve, this._samples);

  factory _ParamCurve.of(RegionCurve curve) {
    if (curve is RegionSpline) {
      final tolerance = math.max(1e-6, curve.bounds.diagonal * 1e-5);
      return _ParamCurve._(curve, curve.samplePoints(tolerance));
    }
    return _ParamCurve._(curve, const []);
  }

  final RegionCurve curve;
  final List<Vec2> _samples;

  bool get isSpline => curve is RegionSpline;

  Vec2 pointAt(double parameter) {
    final u = parameter.clamp(0.0, 1.0).toDouble();
    final line = curve;
    if (line is RegionLine) return line.start.lerp(line.end, u);
    final conic = curve;
    if (conic is RegionConicArc) {
      return conic.pointAt(conic.startParameter + conic.sweep * u);
    }
    if (_samples.length >= 2) {
      final position = u * (_samples.length - 1);
      final index = position.floor().clamp(0, _samples.length - 2);
      return _samples[index].lerp(_samples[index + 1], position - index);
    }
    return curve.start;
  }

  Vec2 tangentAt(double parameter) {
    final u = parameter.clamp(0.0, 1.0).toDouble();
    final line = curve;
    if (line is RegionLine) {
      return (line.end - line.start).normalized();
    }
    final conic = curve;
    if (conic is RegionConicArc) {
      final t = conic.startParameter + conic.sweep * u;
      final derivative = conic.u * -math.sin(t) + conic.v * math.cos(t);
      final direction = conic.sweep < 0 ? -derivative : derivative;
      return direction.normalized();
    }
    const step = 1e-4;
    final low = math.max(0.0, u - step);
    final high = math.min(1.0, u + step);
    var direction = pointAt(high) - pointAt(low);
    if (direction.lengthSquared < 1e-20 && _samples.length >= 2) {
      final position = u * (_samples.length - 1);
      final index = position.floor().clamp(0, _samples.length - 2);
      direction = _samples[index + 1] - _samples[index];
    }
    return direction.normalized();
  }

  List<Vec2> pointsBetween(double from, double to) {
    final start = pointAt(from);
    final end = pointAt(to);
    final out = <Vec2>[start];
    if (_samples.length >= 2) {
      final count = _samples.length - 1;
      for (var i = 1; i < _samples.length - 1; i++) {
        final u = i / count;
        if (u > from + 1e-9 && u < to - 1e-9) {
          final point = _samples[i];
          if (out.last.distanceTo(point) > 1e-12) out.add(point);
        }
      }
    }
    if (out.last.distanceTo(end) > 1e-12) out.add(end);
    return out;
  }
}

class _Root {
  const _Root(this.u, this.v);

  final double u;
  final double v;
}

sealed class _Locus {
  const _Locus();
}

final class _LineLocus extends _Locus {
  const _LineLocus(this.start, this.end);

  final Vec2 start;
  final Vec2 end;
}

final class _CircleLocus extends _Locus {
  const _CircleLocus(this.center, this.radius);

  final Vec2 center;
  final double radius;
}

class _FilletCircle {
  const _FilletCircle(this.center, this.radius);

  final Vec2 center;
  final double radius;
}

class _Candidate {
  const _Candidate(this.joint, this.score);

  final _FilletJoint joint;
  final double score;
}

class _FilletJoint {
  const _FilletJoint({
    required this.incomingIndex,
    required this.incoming,
    required this.outgoing,
    required this.arc,
    required this.approximated,
  });

  final int incomingIndex;
  final RegionCurve incoming;
  final RegionCurve outgoing;
  final RegionConicArc arc;
  final bool approximated;
}

class _FilletLoopResult {
  const _FilletLoopResult(this.loop, this.approximated);

  final RegionLoop loop;
  final bool approximated;
}

class _Corner {
  const _Corner(this.index, this.point);

  final int index;
  final Vec2 point;
}

class _LocatedCorner {
  const _LocatedCorner(this.component, this.loop, this.corner);

  final int component;
  final int loop;
  final _Corner corner;
}
