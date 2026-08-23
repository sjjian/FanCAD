import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a miss cannot invent a circle crossing', () {
    expect(
      Intersect.lineCircle(
        const Vec2(-10, 10),
        const Vec2(10, 10),
        const Vec2.zero(),
        2,
      ),
      isEmpty,
    );
    expect(
      Intersect.circleCircle(
        const Vec2.zero(),
        1,
        const Vec2(10, 0),
        1,
      ),
      isEmpty,
    );
  });
}
