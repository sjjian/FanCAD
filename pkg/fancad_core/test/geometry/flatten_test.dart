import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a huge arc with a tiny tolerance hits the segment ceiling', () {
    expect(
      Flatten.arcSegmentCount(1e6, math.pi * 2, 1e-6),
      Flatten.maxSegments,
    );
  });

  test('an underflowing sagitta ratio stays at the floor instead of NaN', () {
    expect(Flatten.arcSegmentCount(1e20, math.pi, 1e-20), Flatten.minSegments);
  });

  test(
    'a non-positive spline tolerance samples at the ceiling rather than infinitely',
    () {
      final samples = Flatten.bspline(
        controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]),
        knots: const [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0],
        degree: 3,
        tolerance: 0,
      );
      expect(samples.length, (Flatten.maxSegments + 1) * 2);
      expect(samples[0], closeTo(0, 1e-9));
      expect(samples[samples.length - 2], closeTo(4, 1e-6));
    },
  );

  test('a zero bulge or collapsed chord cannot invent an arc', () {
    expect(Flatten.bulgeArc(const Vec2.zero(), const Vec2(10, 0), 0), isNull);
    expect(Flatten.bulgeArc(const Vec2.zero(), const Vec2.zero(), 1), isNull);
  });

  test('an empty or inverted knot vector cannot invent a sample', () {
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: Float64List(0),
        knots: const [],
        degree: 3,
        t: 0,
      ),
      isNull,
    );
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]),
        knots: const [0, 0, 0, 0, 0, 0, 0, 0],
        degree: 3,
        t: 0.5,
      ),
      isNull,
    );
  });

  test('duplicate vertices cannot invent a wide stroke', () {
    expect(
      Flatten.wideStroke(Float64List.fromList([0, 0, 0, 0]), 2, closed: false),
      isNull,
    );
    expect(
      Flatten.wideStroke(
        Float64List.fromList([0, 0, 0, 0, 0, 0]),
        2,
        closed: true,
      ),
      isNull,
    );
  });

  test('an empty or inverted knot vector cannot invent a spline', () {
    expect(
      Flatten.bspline(
        controlPoints: Float64List(0),
        knots: const [],
        degree: 3,
        tolerance: 0.1,
      ),
      isEmpty,
    );

    final controls = Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]);
    expect(
      Flatten.bspline(
        controlPoints: controls,
        knots: const [0, 0, 0, 0, 0, 0, 0, 0],
        degree: 3,
        tolerance: 0.1,
      ),
      controls,
    );
    expect(
      Flatten.bsplineBasis(
        knots: const [0, 0, 0, 0, 0, 0, 0, 0],
        count: 4,
        degree: 3,
        t: 0,
      ),
      [0.0, 0.0, 0.0, 0.0],
    );
    expect(
      Flatten.bsplineBasis(knots: const [0, 1], count: 4, degree: 3, t: 0),
      [0.0, 0.0, 0.0, 0.0],
    );
  });

  test('a collapsed curve stays at its centre instead of inventing a ring', () {
    final arc = Flatten.arc(
      center: const Vec2(3, 4),
      radius: 0,
      startAngle: 0,
      endAngle: 1,
      tolerance: 0.1,
    );
    expect(arc.length, greaterThanOrEqualTo(2));
    expect(arc[0], closeTo(3, 1e-12));
    expect(arc[1], closeTo(4, 1e-12));
    for (var i = 0; i < arc.length; i += 2) {
      expect(arc[i], closeTo(3, 1e-12));
      expect(arc[i + 1], closeTo(4, 1e-12));
    }

    final ring = Flatten.circle(
      center: const Vec2(3, 4),
      radius: 0,
      tolerance: 0.1,
    );
    expect(ring, Float64List.fromList([3, 4]));

    final oval = Flatten.ellipse(
      center: const Vec2(3, 4),
      major: const Vec2.zero(),
      ratio: 1,
      startParam: 0,
      endParam: 1,
      tolerance: 0.1,
    );
    for (var i = 0; i < oval.length; i += 2) {
      expect(oval[i], closeTo(3, 1e-12));
      expect(oval[i + 1], closeTo(4, 1e-12));
    }
  });

  test('a non-finite bulge cannot invent an arc', () {
    const start = Vec2.zero();
    const end = Vec2(10, 0);
    expect(Flatten.bulgeArc(start, end, double.nan), isNull);
    expect(Flatten.bulgeArc(start, end, double.infinity), isNull);
    expect(Flatten.bulgeArc(start, end, double.negativeInfinity), isNull);
  });

  test('a clockwise quarter stays on the right of the chord', () {
    const start = Vec2(10, 0);
    const end = Vec2(0, 10);
    final bulge = -math.tan(math.pi / 8);
    final arc = Flatten.bulgeArc(start, end, bulge);
    expect(arc, isNotNull);
    expect(arc!.center.x, closeTo(10, 1e-9));
    expect(arc.center.y, closeTo(10, 1e-9));
    expect(arc.radius, closeTo(10, 1e-9));

    final points = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([10, 0, bulge, 0, 10, 0]),
      closed: false,
      tolerance: 1e-3,
    );
    // The minor clockwise quarter stays inside [0, 10]². The complementary
    // 3/4 circle around the origin would leave that square.
    for (var i = 0; i < points.length; i += 2) {
      expect(points[i], inInclusiveRange(-0.5, 10.5));
      expect(points[i + 1], inInclusiveRange(-0.5, 10.5));
    }
  });

  test('a small clockwise bulge does not walk the complementary circle', () {
    const bulge = -0.008;
    final points = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([0, 0, bulge, 0, 100, 0]),
      closed: false,
      tolerance: 0.1,
    );
    expect(_spanX(points), lessThan(2));
  });

  test('a small counter-clockwise bulge stays on the left of the chord', () {
    const bulge = 0.008;
    final points = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([0, 0, bulge, 0, 100, 0]),
      closed: false,
      tolerance: 0.1,
    );
    expect(_spanX(points), lessThan(2));
    for (var i = 0; i < points.length; i += 2) {
      expect(points[i], lessThan(0.5));
    }
  });

  test('a semicircle bulge sits on the signed side of the chord', () {
    // |bulge| == 1 puts the centre on the chord, so both halves share a
    // centre. The walk must follow the signed sense: CCW through (5, -5),
    // CW through (5, 5). Picking the other half is the same class of bug
    // as a flipped minor clockwise bulge.
    final ccw = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([0, 0, 1, 10, 0, 0]),
      closed: false,
      tolerance: 1e-3,
    );
    expect(_minY(ccw), closeTo(-5, 0.05));
    expect(_maxY(ccw), closeTo(0, 0.05));

    final cw = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([0, 0, -1, 10, 0, 0]),
      closed: false,
      tolerance: 1e-3,
    );
    expect(_maxY(cw), closeTo(5, 0.05));
    expect(_minY(cw), closeTo(0, 0.05));
  });

  test('a major bulge walks the long way, not the minor complement', () {
    final major = math.tan(3 * math.pi / 8);
    const start = Vec2(10, 0);
    const end = Vec2(0, 10);

    final ccw = Flatten.bulgeArc(start, end, major);
    expect(ccw, isNotNull);
    expect(ccw!.center.x, closeTo(10, 1e-9));
    expect(ccw.center.y, closeTo(10, 1e-9));
    final ccwPts = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([10, 0, major, 0, 10, 0]),
      closed: false,
      tolerance: 1e-3,
    );
    expect(_maxX(ccwPts), greaterThan(15));
    expect(_maxY(ccwPts), greaterThan(15));

    final cw = Flatten.bulgeArc(start, end, -major);
    expect(cw, isNotNull);
    expect(cw!.center.x, closeTo(0, 1e-9));
    expect(cw.center.y, closeTo(0, 1e-9));
    final cwPts = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([10, 0, -major, 0, 10, 0]),
      closed: false,
      tolerance: 1e-3,
    );
    expect(_minX(cwPts), lessThan(-5));
    expect(_minY(cwPts), lessThan(-5));
  });

  test(
    'tessellation follows the included sweep, not the complementary arc',
    () {
      // ±1 is omitted: both halves have the same length, so the side test
      // above is what pins a semicircle.
      for (final bulge in [
        -0.008,
        0.008,
        -math.tan(math.pi / 8),
        math.tan(3 * math.pi / 8),
      ]) {
        final arc = Flatten.bulgeArc(
          const Vec2.zero(),
          const Vec2(0, 100),
          bulge,
        )!;
        final points = Flatten.polylineWithBulges(
          vertices: Float64List.fromList([0, 0, bulge, 0, 100, 0]),
          closed: false,
          tolerance: 0.05,
        );
        final included = arc.radius * (4 * math.atan(bulge)).abs();
        final complement =
            arc.radius * (2 * math.pi - (4 * math.atan(bulge)).abs());
        expect(_polyLength(points), closeTo(included, included * 0.02 + 0.5));
        expect(
          (_polyLength(points) - complement).abs(),
          greaterThan(arc.radius * 0.5),
        );
      }
    },
  );

  test(
    'a closed polyline with a repeated close vertex cannot invent an arc',
    () {
      const bulge = -0.008;
      final points = Flatten.polylineWithBulges(
        vertices: Float64List.fromList([
          0,
          0,
          0,
          10,
          0,
          0,
          10,
          10,
          bulge,
          0,
          10,
          0,
          0,
          0,
          bulge,
        ]),
        closed: true,
        tolerance: 0.1,
      );
      expect(_spanX(points), lessThan(12));
      expect(_maxY(points) - _minY(points), lessThan(12));
    },
  );

  test('a circle is discretised within tolerance', () {
    const radius = 100.0;
    const tolerance = 0.01;
    final points = Flatten.circle(
      center: const Vec2.zero(),
      radius: radius,
      tolerance: tolerance,
    );
    expect(points.length, greaterThanOrEqualTo(8));
    // Every chord midpoint must stay inside the tolerance band.
    for (var i = 0; i + 3 < points.length; i += 2) {
      final midX = (points[i] + points[i + 2]) / 2;
      final midY = (points[i + 1] + points[i + 3]) / 2;
      final sagitta = radius - math.sqrt(midX * midX + midY * midY);
      expect(sagitta, lessThan(tolerance * 1.5));
    }
  });

  test('a 90 degree bulge produces a quarter arc', () {
    final quarter = Flatten.bulgeArc(
      const Vec2(10, 0),
      const Vec2(0, 10),
      math.tan(math.pi / 8),
    );
    expect(quarter, isNotNull);
    expect(quarter!.center.x, closeTo(0, 1e-9));
    expect(quarter.center.y, closeTo(0, 1e-9));
    expect(quarter.radius, closeTo(10, 1e-9));

    final vertices = Float64List.fromList([
      0, 0, math.tan(math.pi / 8),
      10, 10, 0,
    ]);
    final points = Flatten.polylineWithBulges(
      vertices: vertices,
      closed: false,
      tolerance: 1e-4,
    );
    expect(points.first, closeTo(0, 1e-9));
    expect(points[points.length - 2], closeTo(10, 1e-6));
    expect(points.last, closeTo(10, 1e-6));
    // The arc bulges away from the chord, so some point must sit off it.
    var maxDeviation = 0.0;
    for (var i = 0; i < points.length; i += 2) {
      final deviation = (points[i] - points[i + 1]).abs();
      maxDeviation = math.max(maxDeviation, deviation);
    }
    expect(maxDeviation, greaterThan(1));
  });

  test('a wide open stroke is a strip around the centreline', () {
    final stroke = Flatten.wideStroke(
      Float64List.fromList([0, 0, 10, 0]),
      2,
      closed: false,
    );

    expect(stroke, isNotNull);
    expect(stroke!.hole, isNull);
    for (var i = 1; i < stroke.outer.length; i += 2) {
      expect(stroke.outer[i].abs(), closeTo(1, 1e-9));
    }
  });

  test('a wide closed ring keeps a hole in the middle', () {
    final stroke = Flatten.wideStroke(
      Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
      2,
      closed: true,
    );

    expect(stroke, isNotNull);
    expect(stroke!.hole, isNotNull);
    expect(Bounds2.fromXY(stroke.outer).width, closeTo(12, 1e-6));
    expect(Bounds2.fromXY(stroke.hole!).width, closeTo(8, 1e-6));
  });

  test('arc and ellipse sample the expected endpoints', () {
    expect(Flatten.arcSegmentCount(0, math.pi, 0.1), 1);
    expect(Flatten.arcSegmentCount(10, 0, 0.1), 1);
    expect(Flatten.arcSegmentCount(10, math.pi, 0), Flatten.minSegments);
    final quarter = Flatten.arc(
      center: const Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
      tolerance: 0.05,
    );
    expect(quarter[0], closeTo(10, 1e-9));
    expect(quarter[1], closeTo(0, 1e-9));
    expect(quarter[quarter.length - 2], closeTo(0, 1e-6));
    expect(quarter.last, closeTo(10, 1e-6));
    final oval = Flatten.ellipse(
      center: const Vec2.zero(),
      major: const Vec2(4, 0),
      ratio: 0.5,
      startParam: 0,
      endParam: math.pi * 2,
      tolerance: 0.1,
    );
    expect(oval.length, greaterThan(8));
    expect(oval[0], closeTo(4, 1e-9));
  });

  test('a clamped cubic NURBS evaluates the endpoints', () {
    final controls = Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]);
    const knots = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
    final samples = Flatten.bspline(
      controlPoints: controls,
      knots: knots,
      degree: 3,
      tolerance: 0.1,
    );
    expect(samples[0], closeTo(0, 1e-9));
    expect(samples[1], closeTo(0, 1e-9));
    expect(samples[samples.length - 2], closeTo(4, 1e-6));
    expect(samples.last, closeTo(0, 1e-6));
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: controls,
        knots: knots,
        degree: 3,
        t: 0,
      ),
      const Vec2.zero(),
    );
    expect(
      Flatten.bspline(
        controlPoints: controls,
        knots: const [0, 1],
        degree: 3,
        tolerance: 0.1,
      ),
      controls,
    );
    expect(
      Flatten.bsplineBasis(
        knots: knots,
        count: 4,
        degree: 3,
        t: 0,
      ).first,
      closeTo(1, 1e-12),
    );
  });

  test('wideStroke refuses a zero-width or single-point path', () {
    expect(
      Flatten.wideStroke(Float64List.fromList([0, 0, 1, 0]), 0, closed: false),
      isNull,
    );
    expect(
      Flatten.wideStroke(Float64List.fromList([0, 0]), 2, closed: false),
      isNull,
    );
  });
}

double _polyLength(Float64List points) {
  var total = 0.0;
  for (var i = 2; i < points.length; i += 2) {
    final dx = points[i] - points[i - 2];
    final dy = points[i + 1] - points[i - 1];
    total += math.sqrt(dx * dx + dy * dy);
  }
  return total;
}

double _minX(Float64List points) => _extreme(points, 0, math.min);
double _maxX(Float64List points) => _extreme(points, 0, math.max);
double _minY(Float64List points) => _extreme(points, 1, math.min);
double _maxY(Float64List points) => _extreme(points, 1, math.max);
double _spanX(Float64List points) => _maxX(points) - _minX(points);

double _extreme(
  Float64List points,
  int offset,
  double Function(double, double) pick,
) {
  var value = points[offset];
  for (var i = offset + 2; i < points.length; i += 2) {
    value = pick(value, points[i]);
  }
  return value;
}
