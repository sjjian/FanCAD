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

  test('reversing an arc becomes a polyline that traces the same bulge the other way', () {
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
  });

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
}
