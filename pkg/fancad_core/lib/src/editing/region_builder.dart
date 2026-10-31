import 'dart:math' as math;

import '../document/entity.dart';
import '../geometry/bounds.dart';
import '../geometry/flatten.dart';
import '../geometry/vector.dart';

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
