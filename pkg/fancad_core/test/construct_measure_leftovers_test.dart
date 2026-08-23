import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a non-positive or non-finite spacing cannot invent measure points', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(Construct.measureLine(line, 0, const Vec2.zero()), isEmpty);
    expect(Construct.measureLine(line, -3, const Vec2.zero()), isEmpty);
    expect(Construct.measureLine(line, double.nan, const Vec2.zero()), isEmpty);
    expect(
      Construct.measureLine(line, double.infinity, const Vec2.zero()),
      isEmpty,
    );

    final polyline = PolylineEntity.fromPoints(
      id: 2,
      points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
    );
    expect(Construct.measurePolyline(polyline, 0, const Vec2.zero()), isEmpty);

    const arc = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(Construct.measureArc(arc, -1, const Vec2(10, 0)), isEmpty);

    const circle = CircleEntity(id: 4, center: Vec2.zero(), radius: 5);
    expect(Construct.measureCircle(circle, 0, const Vec2(5, 0)), isEmpty);
  });

  test('a collapsed or zero-radius curve cannot invent measure points', () {
    expect(
      Construct.measurePolyline(
        PolylineEntity.fromPoints(id: 1, points: const [Vec2.zero()]),
        2,
        const Vec2.zero(),
      ),
      isEmpty,
    );
    expect(
      Construct.measurePolyline(
        PolylineEntity.fromPoints(
          id: 2,
          points: const [Vec2.zero(), Vec2(1, 0)],
        ),
        6,
        const Vec2.zero(),
      ),
      isEmpty,
    );

    const zeroArc = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: math.pi,
    );
    expect(Construct.measureArc(zeroArc, 1, const Vec2.zero()), isEmpty);

    const shortArc = ArcEntity(
      id: 4,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: 0.1,
    );
    expect(Construct.measureArc(shortArc, 20, const Vec2(10, 0)), isEmpty);

    expect(
      Construct.measureCircle(
        const CircleEntity(id: 5, center: Vec2.zero(), radius: 0),
        1,
        const Vec2.zero(),
      ),
      isEmpty,
    );
    expect(
      Construct.measureCircle(
        const CircleEntity(id: 6, center: Vec2.zero(), radius: 1),
        20,
        const Vec2(1, 0),
      ),
      isEmpty,
    );
  });

  test('a pick at the circle center still walks from angle zero', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 10);
    final points = Construct.measureCircle(circle, 10, const Vec2.zero());

    expect(points, isNotEmpty);
    expect(points.first.x, closeTo(10 * math.cos(1), 1e-9));
    expect(points.first.y, closeTo(10 * math.sin(1), 1e-9));
  });
}
