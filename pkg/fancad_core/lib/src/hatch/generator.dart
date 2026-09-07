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

    // A file that carries its own definition lines has already resolved the
    // pattern: the angles are final and the offsets are in drawing units. The
    // built-in table is the fallback for hatches that only name a pattern,
    // and only then does the entity's own angle and scale apply.
    final fromFile = hatch.patternLines.isNotEmpty;
    final lines = fromFile
        ? hatch.patternLines
        : HatchPattern.named(hatch.patternName).lines;
    if (lines.isEmpty) return const [];

    var box = const Bounds2.empty();
    for (final loop in hatch.loops) {
      box = box.union(Bounds2.fromXY(loop.vertices));
    }
    if (box.isEmpty) return const [];

    final strokes = <Float64List>[];
    final scale = fromFile
        ? 1.0
        : (hatch.patternScale == 0 ? 1.0 : hatch.patternScale);
    final extraAngle = fromFile ? 0.0 : hatch.patternAngle;
    for (final line in lines) {
      strokes.addAll(
        _family(
          line: line,
          box: box,
          loops: hatch.loops,
          extraAngle: extraAngle,
          scale: scale,
          pixelSize: pixelSize,
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
    required double pixelSize,
  }) {
    final angle = line.angle + extraAngle;
    final dir = Vec2(math.cos(angle), math.sin(angle));
    final normal = Vec2(-dir.y, dir.x);
    final spacing = (line.deltaY.abs() < 1e-9 ? 3.175 : line.deltaY.abs()) * scale;
    final origin = Vec2(line.originX, line.originY) * scale;
    final dashes = [for (final dash in line.dashes) dash * scale];
    final shiftStep = line.deltaX * scale;
    final dotLength = pixelSize > 0 ? pixelSize : 0.5;

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
      for (final clipped in _clipSegment(a, b, loops)) {
        out.addAll(
          _applyDashes(
            clipped,
            origin: origin,
            along: along,
            dir: dir,
            dashes: dashes,
            shift: i * shiftStep,
            dotLength: dotLength,
          ),
        );
      }
    }
    return out;
  }

  /// Walks the AutoCAD dash array along a clipped pattern line.
  ///
  /// Positive lengths are pen-down, negative are gaps, and zero is a dot.
  /// Skipping this and stroking the whole clip is what turned AR-CONC into a
  /// dense smear: its stones are short dashes and its aggregate is dots.
  List<Float64List> _applyDashes(
    Float64List clipped, {
    required Vec2 origin,
    required Vec2 along,
    required Vec2 dir,
    required List<double> dashes,
    required double shift,
    required double dotLength,
  }) {
    if (clipped.length < 4) return const [];
    final a = Vec2(clipped[0], clipped[1]);
    final b = Vec2(clipped[2], clipped[3]);
    if (dashes.isEmpty) {
      return [clipped];
    }
    var period = 0.0;
    for (final dash in dashes) {
      period += dash.abs();
    }
    if (period < 1e-12) {
      return [clipped];
    }
    var s0 = (a - origin).dot(dir);
    var s1 = (b - origin).dot(dir);
    if (s1 < s0) {
      final swap = s0;
      s0 = s1;
      s1 = swap;
    }
    final lengths = [for (final dash in dashes) dash.abs()];
    final down = [for (final dash in dashes) dash >= 0];
    final strokes = <Float64List>[];
    var pattern = (s0 - shift) % period;
    if (pattern < 0) pattern += period;
    var s = s0 - pattern;
    while (s < s1 - 1e-12) {
      for (var i = 0; i < dashes.length; i++) {
        final len = lengths[i];
        final start = s;
        final end = s + len;
        s = end;
        if (len < 1e-12) {
          if (down[i] && start >= s0 - 1e-12 && start <= s1 + 1e-12) {
            final mid = along + dir * start;
            final half = dir * (dotLength * 0.5);
            final p0 = mid - half;
            final p1 = mid + half;
            strokes.add(Float64List.fromList([p0.x, p0.y, p1.x, p1.y]));
          }
          continue;
        }
        final lo = math.max(start, s0);
        final hi = math.min(end, s1);
        if (hi - lo <= 1e-12 || !down[i]) continue;
        final p0 = along + dir * lo;
        final p1 = along + dir * hi;
        strokes.add(Float64List.fromList([p0.x, p0.y, p1.x, p1.y]));
      }
      if (period < 1e-12) break;
    }
    return strokes;
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
