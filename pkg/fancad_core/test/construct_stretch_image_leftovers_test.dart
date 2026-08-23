import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a window miss cannot invent an image stretch', () {
    const image = ImageEntity(
      id: 1,
      reference: 'photo.png',
      origin: Vec2.zero(),
      uVector: Vec2(10, 0),
      vVector: Vec2(0, 8),
    );
    expect(
      Construct.stretch(
        image,
        const Bounds2(20, 20, 21, 21),
        const Vec2(4, 0),
      ),
      isNull,
    );
  });
}
