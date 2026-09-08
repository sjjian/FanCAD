import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range dimension grip cannot invent a definition point', () {
    const dim = DimensionEntity(
      id: 1,
      definitionPoints: [Vec2.zero(), Vec2(4, 0)],
      textPosition: Vec2(2, 2),
      measurement: 4,
    );
    expect(dim.withGrip(-1, const Vec2(1, 1)), same(dim));
    expect(dim.withGrip(99, const Vec2(1, 1)), same(dim));
  });
}
