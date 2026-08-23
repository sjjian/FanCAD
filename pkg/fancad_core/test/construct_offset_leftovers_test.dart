import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a zero or negative distance cannot invent an offset', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(Construct.offset(line, 0, const Vec2(5, 5)), isNull);
    expect(Construct.offset(line, -2, const Vec2(5, 5)), isNull);
  });

  test('a collapsed span or inward arc cannot invent a remnant', () {
    const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(Construct.offset(collapsed, 2, const Vec2(0, 1)), isNull);

    const arc = ArcEntity(
      id: 2,
      center: Vec2.zero(),
      radius: 5,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(Construct.offset(arc, 5, const Vec2.zero()), isNull);
    expect(Construct.offset(arc, 9, const Vec2.zero()), isNull);
  });
}
