import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('collinear points cannot invent a circle', () {
    expect(
      Construct.circleThrough(
        const Vec2.zero(),
        const Vec2(2, 0),
        const Vec2(4, 0),
      ),
      isNull,
    );
    expect(
      Construct.circleThrough(
        const Vec2.zero(),
        const Vec2.zero(),
        const Vec2.zero(),
      ),
      isNull,
    );
  });
}
