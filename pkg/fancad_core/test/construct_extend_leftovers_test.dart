import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed span cannot invent an extension', () {
    const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(
      Construct.extendLine(collapsed, [
        const LineEntity(id: 2, start: Vec2(10, -5), end: Vec2(10, 5)),
      ]),
      isNull,
    );

    const zeroRadius = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(
      Construct.extendArc(zeroRadius, [
        const LineEntity(id: 4, start: Vec2(-15, 0), end: Vec2(-5, 0)),
      ]),
      isNull,
    );
  });

  test('a closed loop or lone vertex cannot invent an extension', () {
    expect(
      Construct.extendPolyline(
        PolylineEntity.fromPoints(id: 1, points: const [Vec2.zero()]),
        [const LineEntity(id: 2, start: Vec2(10, -5), end: Vec2(10, 5))],
      ),
      isNull,
    );

    const fullCircle = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi * 2,
    );
    expect(
      Construct.extendArc(fullCircle, [
        const LineEntity(id: 4, start: Vec2(-15, 0), end: Vec2(-5, 0)),
      ]),
      isNull,
    );
  });
}
