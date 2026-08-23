import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('coincident origins cannot invent a linear or aligned dim', () {
    expect(
      Construct.linearDimension(
        const Vec2.zero(),
        const Vec2.zero(),
        const Vec2(0, 4),
      ),
      isNull,
    );
    expect(
      Construct.alignedDimension(
        const Vec2(3, 3),
        const Vec2(3, 3),
        const Vec2(4, 5),
      ),
      isNull,
    );
  });

  test('a vanished radius cannot invent a radial dim', () {
    expect(
      Construct.radiusDimension(
        const CircleEntity(id: 1, center: Vec2.zero(), radius: 0),
        const Vec2(8, 0),
      ),
      isNull,
    );
    expect(
      Construct.diameterDimension(
        const LineEntity(id: 2, start: Vec2.zero(), end: Vec2(10, 0)),
        const Vec2(8, 0),
      ),
      isNull,
    );
    expect(
      Construct.radiusDimension(
        const CircleEntity(id: 3, center: Vec2.zero(), radius: 5),
        const Vec2.zero(),
      ),
      isNotNull,
    );
  });
}
