import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range solid grip cannot invent a corner', () {
    const solid = SolidEntity(
      id: 1,
      corners: [Vec2.zero(), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
    );
    expect(solid.withGrip(-1, const Vec2(1, 1)), same(solid));
    expect(solid.withGrip(99, const Vec2(1, 1)), same(solid));
  });
}
