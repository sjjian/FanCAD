import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed span cannot invent a break', () {
    const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(Construct.breakLine(collapsed, const Vec2.zero()), isNull);

    const zeroRadius = ArcEntity(
      id: 2,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: math.pi,
    );
    expect(Construct.breakArc(zeroRadius, const Vec2.zero()), isNull);
  });

  test('a lone vertex or zero-radius circle cannot invent a remnant', () {
    expect(
      Construct.breakPolyline(
        PolylineEntity.fromPoints(id: 1, points: const [Vec2.zero()]),
        const Vec2.zero(),
      ),
      isNull,
    );

    expect(
      Construct.breakCircle(
        const CircleEntity(id: 2, center: Vec2.zero(), radius: 0),
        const Vec2(1, 0),
        const Vec2(0, 1),
      ),
      isNull,
    );
    expect(
      Construct.breakCircle(
        const CircleEntity(id: 3, center: Vec2.zero(), radius: 10),
        const Vec2(10, 0),
        const Vec2(10, 0),
      ),
      isNull,
    );
  });
}
