import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a coincident vertex or collapsed sweep cannot invent an angular dim', () {
    expect(
      Construct.angularDimension(
        const Vec2.zero(),
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(4, 4),
      ),
      isNull,
    );
    expect(
      Construct.angularDimension(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(10, 0),
        const Vec2(4, 4),
      ),
      isNull,
    );
    expect(
      Construct.angularDimension(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(20, 0),
        const Vec2.zero(),
      ),
      isNull,
    );
  });
}
