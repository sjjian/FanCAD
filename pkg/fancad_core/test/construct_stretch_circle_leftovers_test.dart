import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a window miss cannot invent a circle move', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(
      Construct.stretch(
        circle,
        const Bounds2(20, 20, 21, 21),
        const Vec2(4, 0),
      ),
      isNull,
    );
  });
}
