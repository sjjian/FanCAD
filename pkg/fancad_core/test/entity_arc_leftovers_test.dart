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
