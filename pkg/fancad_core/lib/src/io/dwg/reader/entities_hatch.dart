part of '../dwg_reader.dart';

/// A clockwise hatch arc stores its angles in that clockwise frame. Feeding
/// those numbers to a counter-clockwise parametrisation draws the other half
/// of the circle, so a logo outline lands on the far side and stretches the
/// fill into a spike. Negating first puts both frames in one parameter.
@visibleForTesting
double hatchArcAngle(double angle, bool ccw) => ccw ? angle : -angle;

/// Shortest signed sweep from [a0] to [a1], in (-pi, pi]. A hatch edge is a
/// single arc span, never the complementary long way round.
@visibleForTesting
double hatchArcSweep(double a0, double a1) {
  var sweep = a1 - a0;
  while (sweep <= -math.pi) {
    sweep += math.pi * 2;
  }
  while (sweep > math.pi) {
    sweep -= math.pi * 2;
  }
  return sweep;
}

/// Samples per arc, one every pi/16 and capped at 64.
@visibleForTesting
int hatchArcSteps(double sweep) =>
    (sweep.abs() / (math.pi / 16)).toInt().clamp(1, 64);

/// Samples a hatch arc edge as interleaved x/y pairs.
@visibleForTesting
List<double> sampleHatchArc(
  double cx,
  double cy,
  double rx,
  double ry,
  double start,
  double end,
  bool ccw,
) {
  final a0 = hatchArcAngle(start, ccw);
  final a1 = hatchArcAngle(end, ccw);
  final sweep = hatchArcSweep(a0, a1);
  final steps = hatchArcSteps(sweep);
  final out = <double>[];
  for (var i = 0; i <= steps; i++) {
    final t = a0 + sweep * i / steps;
    out
      ..add(cx + math.cos(t) * rx)
      ..add(cy + math.sin(t) * ry);
  }
  return out;
}

/// Samples an elliptical hatch arc edge as interleaved x/y pairs. [mx]/[my]
/// are the major axis relative to the centre and [ratio] scales the minor
/// axis.
@visibleForTesting
List<double> sampleHatchEllipse(
  double cx,
  double cy,
  double mx,
  double my,
  double ratio,
  double start,
  double end,
  bool ccw,
) {
  final a0 = hatchArcAngle(start, ccw);
  final a1 = hatchArcAngle(end, ccw);
  final sweep = hatchArcSweep(a0, a1);
  final steps = hatchArcSteps(sweep);
  final nx = -my * ratio;
  final ny = mx * ratio;
  final out = <double>[];
  for (var i = 0; i <= steps; i++) {
    final t = a0 + sweep * i / steps;
    out
      ..add(cx + mx * math.cos(t) + nx * math.sin(t))
      ..add(cy + my * math.cos(t) + ny * math.sin(t));
  }
  return out;
}

extension on DwgReader {
  List<double> _readHatch(DwgBitReader br) {
    if (_version >= 2004) {
      br.bl(); // is_gradient_fill
      br.bl(); // reserved
      br.bd(); // gradient angle
      br.bd(); // gradient shift
      br.bl(); // single colour gradient
      br.bd(); // gradient tint
      final numColors = br.bl();
      for (var i = 0; i < numColors && i < 1000; i++) {
        br.bd(); // shift
        br.bs(); // colour index
        br.bl(); // true colour
        br.rc(); // colour flag
      }
      _text(br); // gradient name
    }
    br.bd(); // elevation
    br.bd();
    br.bd();
    br.bd(); // extrusion
    final name = _text(br);
    final solid = br.b();
    br.b(); // associative
    final numPaths = br.bl();
    if (numPaths > 10000) throw const _InvalidObject();
    final values = <double>[solid.toDouble(), 0, 1, numPaths.toDouble()];
    final loops = <List<double>>[];
    final pathFlags = <int>[];
    var totalVertices = 0;

    for (var p = 0; p < numPaths && p < 10000; p++) {
      final flag = br.bl();
      pathFlags.add(flag);
      final vertices = <double>[];
      if ((flag & 2) == 0) {
        final numSegs = br.bl();
        for (var i = 0; i < numSegs && i < 100000; i++) {
          final curve = br.rc();
          if (curve == 1) {
            final x1 = br.rd(), y1 = br.rd();
            final x2 = br.rd(), y2 = br.rd();
            vertices
              ..add(x1)
              ..add(y1)
              ..add(x2)
              ..add(y2);
          } else if (curve == 2) {
            final cx = br.rd(), cy = br.rd();
            final r = br.bd();
            final a0 = br.bd(), a1 = br.bd();
            final ccw = br.b() != 0;
            vertices.addAll(sampleHatchArc(cx, cy, r, r, a0, a1, ccw));
          } else if (curve == 3) {
            final cx = br.rd(), cy = br.rd();
            final ex = br.rd(), ey = br.rd();
            final ratio = br.bd();
            final start = br.bd(), end = br.bd();
            final ccw = br.b() != 0;
            vertices.addAll(
              sampleHatchEllipse(cx, cy, ex, ey, ratio, start, end, ccw),
            );
          } else if (curve == 4) {
            br.bl(); // degree
            final rational = br.b() != 0;
            br.b(); // periodic
            final numKnots = br.bl();
            final numCtrl = br.bl();
            for (var k = 0; k < numKnots && k < 100000; k++) {
              br.bd();
            }
            for (var k = 0; k < numCtrl && k < 100000; k++) {
              vertices.add(br.rd());
              vertices.add(br.rd());
              if (rational) br.bd();
            }
          }
        }
      } else {
        final bulges = br.b() != 0;
        br.b(); // closed
        final numVerts = br.bl();
        for (var i = 0; i < numVerts && i < 100000; i++) {
          vertices.add(br.rd());
          vertices.add(br.rd());
          if (bulges) br.bd();
        }
      }
      br.bl(); // boundary handle count (handles live in the handle stream)
      totalVertices += vertices.length ~/ 2;
      if (totalVertices > 500000) throw const _InvalidObject();
      loops.add(vertices);
    }
    _lastHatchPathFlags = pathFlags;

    br.bs(); // style
    br.bs(); // pattern_type
    var angle = 0.0;
    var scale = 1.0;
    final defs = <double>[];
    if (solid == 0) {
      angle = br.bd();
      scale = br.bd();
      br.b(); // double flag
      final numDef = br.bs();
      for (var i = 0; i < numDef && i < 10000; i++) {
        defs.add(br.bd()); // angle
        defs.add(br.bd()); // origin x
        defs.add(br.bd()); // origin y
        defs.add(br.bd()); // delta x
        defs.add(br.bd()); // delta y
        final numDashes = br.bs();
        defs.add(numDashes.toDouble());
        for (var k = 0; k < numDashes && k < 10000; k++) {
          defs.add(br.bd());
        }
      }
    }
    final numSeeds = br.bl();
    if (numSeeds > 0 && numSeeds < 100000) {
      br.skip(numSeeds * 2 * 64);
    }
    values[1] = angle;
    values[2] = scale;
    for (final loop in loops) {
      values.add(loop.length / 2.0);
      values.addAll(loop);
    }
    values.add(defs.length.toDouble());
    values.addAll(defs);
    _lastText = name;
    return values;
  }
}
