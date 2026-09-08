import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an inward offset that reaches the centre cannot invent an arc', () {
    const arc = ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 5,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(arc.offsetBy(5, const Vec2.zero()), isNull);
    expect(arc.offsetBy(9, const Vec2.zero()), isNull);
  });

  test(
    'reversing an arc becomes a polyline that traces the same bulge the other way',
    () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2.zero(),
        radius: 5,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      final reversed = arc.reversed();
      expect(reversed, isA<PolylineEntity>());
      final poly = reversed as PolylineEntity;
      expect(poly.vertexAt(0).distanceTo(arc.endPoint), closeTo(0, 1e-9));
      expect(poly.vertexAt(1).distanceTo(arc.startPoint), closeTo(0, 1e-9));
      expect(poly.bulgeAt(0), closeTo(-math.tan(arc.sweep / 4), 1e-9));
    },
  );

  test('a vanished arc cannot invent a reverse', () {
    const arc = ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(arc.reversed(), isNull);
  });

  test('a window miss cannot invent an arc stretch', () {
    const arc = ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 5,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(
      arc.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(2, 0)),
      isNull,
    );
  });

  test('arc grips change start, radius, end or the centre', () {
    const arc = ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    final grips = arc.grips();
    expect(grips, hasLength(4));
    expect(grips[0].distanceTo(const Vec2(10, 0)), closeTo(0, 1e-9));
    expect(grips[1].distanceTo(Vec2.polar(math.pi / 4, 10)), closeTo(0, 1e-9));
    expect(grips[2].distanceTo(const Vec2(0, 10)), closeTo(0, 1e-9));
    expect(grips[3], const Vec2.zero());

    expect(arc.withGrip(0, const Vec2(0, 10)).startAngle, closeTo(math.pi / 2, 1e-9));
    expect(arc.withGrip(2, const Vec2(10, 0)).endAngle, closeTo(0, 1e-9));
    expect(arc.withGrip(1, const Vec2(20, 0)).radius, closeTo(20, 1e-9));
    expect(arc.withGrip(3, const Vec2(1, 2)).center, const Vec2(1, 2));

    final rotated = arc.transformed(Mat3.rotation(math.pi / 2));
    expect(rotated.center, const Vec2.zero());
    expect(rotated.startAngle, closeTo(math.pi / 2, 1e-9));
    expect(rotated.endAngle, closeTo(math.pi, 1e-9));
  });

  test('arc bounds are exact, not the full circle', () {
    final arc = ArcEntity(
      id: 1,
      center: const Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    final bounds = arc.computeBounds();
    expect(bounds.minX, closeTo(0, 1e-9));
    expect(bounds.minY, closeTo(0, 1e-9));
    expect(bounds.maxX, closeTo(10, 1e-9));
    expect(bounds.maxY, closeTo(10, 1e-9));
  });
}
