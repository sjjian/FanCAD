import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const arc = ArcEntity(
    id: 1,
    center: Vec2.zero(),
    radius: 10,
    startAngle: 0,
    endAngle: math.pi / 2,
  );

  test('capturing an arc end moves only that angle', () {
    final stretched = Construct.stretch(
      arc,
      const Bounds2(9, -1, 11, 1),
      const Vec2(0, 4),
    )! as ArcEntity;

    expect(stretched.center, const Vec2.zero());
    expect(stretched.radius, 10);
    expect(stretched.startAngle, closeTo(math.atan2(4, 10), 1e-9));
    expect(stretched.endAngle, closeTo(math.pi / 2, 1e-9));
  });

  test('a window miss cannot stretch an arc', () {
    expect(
      Construct.stretch(
        arc,
        const Bounds2(100, 100, 101, 101),
        const Vec2(0, 4),
      ),
      isNull,
    );
  });
}
