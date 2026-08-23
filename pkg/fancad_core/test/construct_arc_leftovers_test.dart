import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('collinear points cannot invent an arc', () {
    expect(
      Construct.arcThrough(
        const Vec2.zero(),
        const Vec2(1, 1),
        const Vec2(2, 2),
      ),
      isNull,
    );
    expect(
      Construct.arcThrough(
        const Vec2.zero(),
        const Vec2.zero(),
        const Vec2(4, 0),
      ),
      isNull,
    );
  });
}
