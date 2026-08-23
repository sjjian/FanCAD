import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished or closed arc cannot invent an angular dim', () {
    expect(
      Construct.angularDimensionFromArc(
        const ArcEntity(
          id: 1,
          center: Vec2.zero(),
          radius: 0,
          startAngle: 0,
          endAngle: math.pi / 2,
        ),
        const Vec2(4, 4),
      ),
      isNull,
    );
    expect(
      Construct.angularDimensionFromArc(
        const ArcEntity(
          id: 2,
          center: Vec2.zero(),
          radius: 10,
          startAngle: 0,
          endAngle: 0,
        ),
        const Vec2(4, 4),
      ),
      isNull,
    );
  });
}
