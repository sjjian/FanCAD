import 'dart:math' as math;
import 'dart:typed_data';

import '../model/entity.dart';
import 'flatten.dart';
import 'intersect.dart';
import 'vector.dart';

/// Finds the hatch loops that enclose a pick, the way BHATCH does.
///
/// Commands hand this a pile of curves and a point. It splits every curve
/// at the intersections, walks the faces of that arrangement, and returns
/// the smallest loop that contains the pick plus any islands inside it.
/// Hatch fill already uses even-odd, so a hole in an island becomes solid
/// again without a second rule.
class Boundary {
  const Boundary._();

  /// Outer loop and islands around [pick], or empty when nothing encloses it.
  static List<HatchLoop> fromPick(
    Iterable<CadEntity> entities,
    Vec2 pick, {
    double tolerance = 1e-3,
  }) {
    final chains = <_Chain>[];
    for (final entity in entities) {
      for (final chain in _chainsOf(entity, tolerance)) {
        if (chain.points.length >= 2) chains.add(chain);
      }
    }
    if (chains.isEmpty) return const [];

    final segments = _splitAtCrossings(chains);
    if (segments.isEmpty) return const [];

    final cycles = _facesOf(segments);
    if (cycles.isEmpty) return const [];

    _Face? outer;
    for (final face in cycles) {
      if (!Intersect.polygonContains(face.xy, pick)) continue;
      if (outer == null || face.area < outer.area) outer = face;
    }
    if (outer == null) return const [];

    final loops = <HatchLoop>[
      HatchLoop(vertices: outer.xy),
    ];
    for (final face in cycles) {
      if (identical(face, outer)) continue;
      if (face.area >= outer.area - 1e-12) continue;
      if (!_cycleInside(face, outer)) continue;
      if (Intersect.polygonContains(face.xy, pick)) continue;
      loops.add(HatchLoop(vertices: face.xy, isOuter: false));
    }
    return loops;
  }

  static List<_Chain> _chainsOf(CadEntity entity, double tolerance) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        if (start.distanceSquaredTo(end) < 1e-20) return const [];
        return [_Chain([start, end], closed: false)];
      case PolylineEntity():
        if (entity.vertexCount < 2) return const [];
        final xy = Flatten.polylineWithBulges(
          vertices: entity.vertices,
          closed: entity.closed,
          tolerance: tolerance,
        );
        return [_Chain(_pointsOf(xy), closed: entity.closed)];
      case CircleEntity(:final center, :final radius):
        if (radius <= 0) return const [];
        return [
          _Chain(
            _pointsOf(
              Flatten.circle(
                center: center,
                radius: radius,
                tolerance: tolerance,
              ),
            ),
            closed: true,
          ),
        ];
      case ArcEntity():
        return [
          _Chain(
            _pointsOf(
              Flatten.arc(
                center: entity.center,
                radius: entity.radius,
                startAngle: entity.startAngle,
                endAngle: entity.endAngle,
                tolerance: tolerance,
              ),
            ),
            closed: false,
          ),
        ];
      case EllipseEntity():
        return [
          _Chain(
            _pointsOf(
              Flatten.ellipse(
                center: entity.center,
                major: entity.majorAxis,
                ratio: entity.ratio,
                startParam: entity.startParam,
                endParam: entity.endParam,
                tolerance: tolerance,
              ),
            ),
            closed: entity.isFullEllipse,
          ),
        ];
      case SplineEntity():
        return [
          _Chain(
            _pointsOf(
              Flatten.bspline(
                controlPoints: entity.controlPoints,
                knots: entity.knots,
                degree: entity.degree,
                weights: entity.weights,
                tolerance: tolerance,
                closed: entity.closed,
              ),
            ),
            closed: entity.closed,
          ),
        ];
      case RayEntity(:final origin, :final direction):
        final length = math.max(1.0, origin.distanceTo(const Vec2.zero()) * 4);
        final unit = direction.lengthSquared < 1e-20
            ? const Vec2(1, 0)
            : direction.normalized();
        return [_Chain([origin, origin + unit * length], closed: false)];
      case XLineEntity(:final origin, :final direction):
        final length = math.max(1.0, origin.distanceTo(const Vec2.zero()) * 4);
        final unit = direction.lengthSquared < 1e-20
            ? const Vec2(1, 0)
            : direction.normalized();
        return [
          _Chain([origin - unit * length, origin + unit * length], closed: false),
        ];
      default:
        return const [];
    }
  }

  static List<Vec2> _pointsOf(Float64List xy) {
    final out = <Vec2>[];
    for (var i = 0; i + 1 < xy.length; i += 2) {
      final point = Vec2(xy[i], xy[i + 1]);
      if (out.isEmpty || out.last.distanceSquaredTo(point) > 1e-24) {
        out.add(point);
      }
    }
    return out;
  }

  /// Splits every chord at every crossing so the graph is planar.
  static List<_Seg> _splitAtCrossings(List<_Chain> chains) {
    final raw = <_Seg>[];
    for (final chain in chains) {
      final count = chain.points.length;
      final segments = chain.closed ? count : count - 1;
      for (var i = 0; i < segments; i++) {
        final a = chain.points[i];
        final b = chain.points[(i + 1) % count];
        if (a.distanceSquaredTo(b) < 1e-20) continue;
        raw.add(_Seg(a, b));
      }
    }

    final cuts = [for (var i = 0; i < raw.length; i++) <Vec2>[raw[i].a, raw[i].b]];
    for (var i = 0; i < raw.length; i++) {
      for (var j = i + 1; j < raw.length; j++) {
        final hit = Intersect.segmentSegment(
          raw[i].a,
          raw[i].b,
          raw[j].a,
          raw[j].b,
        );
        if (hit != null) {
          _addCut(cuts[i], hit);
          _addCut(cuts[j], hit);
          continue;
        }
        // Collinear overlaps produce no crossing, but the shared span
        // still has to become graph vertices or the face walk misses
        // rooms that share a wall.
        _splitCollinear(raw[i], raw[j], cuts[i], cuts[j]);
      }
    }

    final out = <_Seg>[];
    for (var i = 0; i < raw.length; i++) {
      final points = cuts[i]
        ..sort((p, q) {
          final ta = (p - raw[i].a).dot(raw[i].b - raw[i].a);
          final tb = (q - raw[i].a).dot(raw[i].b - raw[i].a);
          return ta.compareTo(tb);
        });
      for (var k = 0; k + 1 < points.length; k++) {
        if (points[k].distanceSquaredTo(points[k + 1]) < 1e-20) continue;
        out.add(_Seg(points[k], points[k + 1]));
      }
    }
    return out;
  }

  static void _addCut(List<Vec2> cuts, Vec2 hit) {
    for (final point in cuts) {
      if (point.distanceSquaredTo(hit) < 1e-16) return;
    }
    cuts.add(hit);
  }

  /// Inserts the interior projections of two collinear overlapping segments.
  static void _splitCollinear(_Seg a, _Seg b, List<Vec2> cutsA, List<Vec2> cutsB) {
    final da = a.b - a.a;
    final db = b.b - b.a;
    final la = da.lengthSquared;
    final lb = db.lengthSquared;
    if (la < 1e-20 || lb < 1e-20) return;
    final parallel = da.cross(db).abs();
    if (parallel > 1e-8 * math.sqrt(la * lb)) return;
    if ((b.a - a.a).cross(da).abs() > 1e-8 * math.sqrt(la)) return;

    void project(Vec2 point, Vec2 origin, Vec2 delta, double lengthSquared, List<Vec2> cuts) {
      final t = (point - origin).dot(delta) / lengthSquared;
      if (t <= 1e-9 || t >= 1 - 1e-9) return;
      _addCut(cuts, origin + delta * t);
    }

    project(b.a, a.a, da, la, cutsA);
    project(b.b, a.a, da, la, cutsA);
    project(a.a, b.a, db, lb, cutsB);
    project(a.b, b.a, db, lb, cutsB);
  }

  static List<_Face> _facesOf(List<_Seg> segments) {
    final snap = _Snap(1e-7);
    final adj = <int, List<int>>{};
    void addEdge(Vec2 a, Vec2 b) {
      final i = snap.id(a);
      final j = snap.id(b);
      if (i == j) return;
      (adj[i] ??= []).add(j);
      (adj[j] ??= []).add(i);
    }

    for (final segment in segments) {
      addEdge(segment.a, segment.b);
    }
    for (final neighbours in adj.values) {
      final seen = <int>{};
      neighbours.retainWhere(seen.add);
    }

    final used = <(int, int)>{};
    final faces = <_Face>[];
    for (final start in adj.keys) {
      for (final next in adj[start]!) {
        if (used.contains((start, next))) continue;
        final cycle = _walk(adj, snap, start, next, used);
        if (cycle == null) continue;
        faces.add(cycle);
      }
    }
    return faces;
  }

  /// Walks the face whose interior sits to the left of [from]→[to].
  ///
  /// At each vertex the next edge is the neighbour immediately clockwise
  /// from the incoming one. Bounded faces come out counter-clockwise
  /// (positive area); the unbounded complement is clockwise and dropped.
  static _Face? _walk(
    Map<int, List<int>> adj,
    _Snap snap,
    int from,
    int to,
    Set<(int, int)> used,
  ) {
    final ids = <int>[from];
    var prev = from;
    var curr = to;
    used.add((from, to));
    for (var step = 0; step < 8192; step++) {
      if (curr == from) break;
      ids.add(curr);
      final neighbours = adj[curr];
      if (neighbours == null || neighbours.isEmpty) return null;
      final next = _clockwiseNext(snap, curr, prev, neighbours);
      if (used.contains((curr, next))) return null;
      used.add((curr, next));
      prev = curr;
      curr = next;
    }
    if (curr != from || ids.length < 3) return null;
    var area = 0.0;
    for (var i = 0; i < ids.length; i++) {
      final a = snap.points[ids[i]];
      final b = snap.points[ids[(i + 1) % ids.length]];
      area += a.x * b.y - b.x * a.y;
    }
    area /= 2;
    if (area <= 1e-12) return null;
    final xy = Float64List(ids.length * 2);
    for (var i = 0; i < ids.length; i++) {
      final point = snap.points[ids[i]];
      xy[i * 2] = point.x;
      xy[i * 2 + 1] = point.y;
    }
    return _Face(xy, area.abs());
  }

  static int _clockwiseNext(
    _Snap snap,
    int curr,
    int prev,
    List<int> neighbours,
  ) {
    if (neighbours.length == 1) return neighbours.first;
    final origin = snap.points[curr];
    neighbours.sort((a, b) {
      final pa = snap.points[a] - origin;
      final pb = snap.points[b] - origin;
      return pa.angle.compareTo(pb.angle);
    });
    final index = neighbours.indexOf(prev);
    if (index < 0) return neighbours.first;
    return neighbours[(index - 1 + neighbours.length) % neighbours.length];
  }

  static bool _cycleInside(_Face inner, _Face outer) {
    for (var i = 0; i < inner.xy.length; i += 2) {
      if (!Intersect.polygonContains(
        outer.xy,
        Vec2(inner.xy[i], inner.xy[i + 1]),
      )) {
        return false;
      }
    }
    return true;
  }
}

class _Chain {
  const _Chain(this.points, {required this.closed});

  final List<Vec2> points;
  final bool closed;
}

class _Seg {
  const _Seg(this.a, this.b);

  final Vec2 a;
  final Vec2 b;
}

class _Face {
  const _Face(this.xy, this.area);

  final Float64List xy;
  final double area;
}

/// Merges vertices that landed on top of each other after a split.
class _Snap {
  _Snap(this.eps);

  final double eps;
  final List<Vec2> points = [];

  int id(Vec2 point) {
    for (var i = 0; i < points.length; i++) {
      if (points[i].distanceSquaredTo(point) <= eps * eps) return i;
    }
    points.add(point);
    return points.length - 1;
  }
}
