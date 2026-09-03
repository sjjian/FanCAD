import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/bounds.dart';
import '../geometry/vector.dart';
import '../model/entity.dart';
import 'pattern.dart';

/// Generates pattern strokes clipped to a hatch boundary.
///
/// A solid hatch is a fill. Everything else is a family of infinite lines
/// clipped to the loops, which is how AutoCAD `.pat` patterns actually work
/// and why a hatch still looks like steel or masonry after a rotate.
class HatchGenerator {
  const HatchGenerator();

  /// Interleaved `[x, y, ...]` polylines, one list per stroke.
  List<Float64List> generate(
    HatchEntity hatch, {
    double pixelSize = 0.5,
  }) {
    if (hatch.solid || hatch.loops.isEmpty) return const [];
    final pattern = HatchPattern.named(hatch.patternName);
    if (pattern.lines.isEmpty) return const [];

    var box = const Bounds2.empty();
    for (final loop in hatch.loops) {
      box = box.union(Bounds2.fromXY(loop.vertices));
    }
    if (box.isEmpty) return const [];

    final strokes = <Float64List>[];
    final scale = hatch.patternScale == 0 ? 1.0 : hatch.patternScale;
    for (final line in pattern.lines) {
      strokes.addAll(
        _family(
          line: line,
          box: box,
          loops: hatch.loops,
          extraAngle: hatch.patternAngle,
          scale: scale,
        ),
      );
    }
    return strokes;
  }

  List<Float64List> _family({
    required HatchPatternLine line,
    required Bounds2 box,
    required List<HatchLoop> loops,
    required double extraAngle,
    required double scale,
  }) {
    final angle = line.angle + extraAngle;
    final dir = Vec2(math.cos(angle), math.sin(angle));
    final normal = Vec2(-dir.y, dir.x);
    final spacing = (line.deltaY.abs() < 1e-9 ? 3.175 : line.deltaY.abs()) * scale;
    final origin = Vec2(line.originX, line.originY) * scale;

    final corners = [
      Vec2(box.minX, box.minY),
      Vec2(box.maxX, box.minY),
      Vec2(box.maxX, box.maxY),
      Vec2(box.minX, box.maxY),
    ];
    var minN = double.infinity;
    var maxN = double.negativeInfinity;
    for (final corner in corners) {
      final n = (corner - origin).dot(normal);
      if (n < minN) minN = n;
      if (n > maxN) maxN = n;
    }

    final out = <Float64List>[];
    final start = (minN / spacing).floor() - 1;
    final end = (maxN / spacing).ceil() + 1;
    // A pathological scale can produce tens of thousands of lines; cap it so
    // a 0.001 pattern scale cannot freeze the UI.
    final count = end - start;
    final step = count > 400 ? (count / 400).ceil() : 1;
    // Each pattern line is infinite; only its offset along the normal is
    // meaningful. Slide the finite stand-in along its own direction until it
    // straddles the boundary, or a hatch far from the pattern origin gets a
    // segment that never reaches its own loops and clips away to nothing.
    final centre = box.center;
    final reach = box.diagonal + spacing;
    for (var i = start; i <= end; i += step) {
      final along = origin + normal * (i * spacing);
      final base = along + dir * (centre - along).dot(dir);
      final a = base - dir * reach;
      final b = base + dir * reach;
      out.addAll(_clipSegment(a, b, loops));
    }
    return out;
  }

  /// Clips [a]–[b] to the even-odd interior of [loops].
  List<Float64List> _clipSegment(Vec2 a, Vec2 b, List<HatchLoop> loops) {
    final hits = <double>[0, 1];
    for (final loop in loops) {
      for (var i = 0; i < loop.pointCount; i++) {
        final j = (i + 1) % loop.pointCount;
        final c = Vec2(loop.vertices[i * 2], loop.vertices[i * 2 + 1]);
        final d = Vec2(loop.vertices[j * 2], loop.vertices[j * 2 + 1]);
        final t = _segmentParameter(a, b, c, d);
        if (t != null) hits.add(t);
      }
    }
    hits.sort();
    final strokes = <Float64List>[];
    for (var i = 0; i < hits.length - 1; i++) {
      final t0 = hits[i];
      final t1 = hits[i + 1];
      if (t1 - t0 < 1e-9) continue;
      final mid = a.lerp(b, (t0 + t1) / 2);
      if (_inside(mid, loops)) {
        final p0 = a.lerp(b, t0);
        final p1 = a.lerp(b, t1);
        strokes.add(Float64List.fromList([p0.x, p0.y, p1.x, p1.y]));
      }
    }
    return strokes;
  }

  static double? _segmentParameter(Vec2 a, Vec2 b, Vec2 c, Vec2 d) {
    final r = b - a;
    final s = d - c;
    final denom = r.cross(s);
    if (denom.abs() < 1e-12) return null;
    final t = (c - a).cross(s) / denom;
    final u = (c - a).cross(r) / denom;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return t;
  }

  static bool _inside(Vec2 point, List<HatchLoop> loops) {
    var crossings = 0;
    for (final loop in loops) {
      for (var i = 0; i < loop.pointCount; i++) {
        final j = (i + 1) % loop.pointCount;
        final ax = loop.vertices[i * 2];
        final ay = loop.vertices[i * 2 + 1];
        final bx = loop.vertices[j * 2];
        final by = loop.vertices[j * 2 + 1];
        if (((ay > point.y) != (by > point.y)) &&
            point.x <
                (bx - ax) * (point.y - ay) / ((by - ay) + 1e-16) + ax) {
          crossings++;
        }
      }
    }
    return crossings.isOdd;
  }
}
