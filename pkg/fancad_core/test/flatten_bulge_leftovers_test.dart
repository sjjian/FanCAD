import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
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

  test('tessellation follows the included sweep, not the complementary arc', () {
    // ±1 is omitted: both halves have the same length, so the side test
    // above is what pins a semicircle.
    for (final bulge in [
      -0.008,
      0.008,
      -math.tan(math.pi / 8),
      math.tan(3 * math.pi / 8),
    ]) {
      final arc = Flatten.bulgeArc(const Vec2.zero(), const Vec2(0, 100), bulge)!;
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
  });

  test('a closed polyline with a repeated close vertex cannot invent an arc', () {
    const bulge = -0.008;
    final points = Flatten.polylineWithBulges(
      vertices: Float64List.fromList([
        0, 0, 0,
        10, 0, 0,
        10, 10, bulge,
        0, 10, 0,
        0, 0, bulge,
      ]),
      closed: true,
      tolerance: 0.1,
    );
    expect(_spanX(points), lessThan(12));
    expect(_maxY(points) - _minY(points), lessThan(12));
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
