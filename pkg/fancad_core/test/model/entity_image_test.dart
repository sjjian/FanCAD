import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished image frame cannot invent leftover corners', () {
    const image = ImageEntity(
      id: 1,
      reference: '',
      origin: Vec2.zero(),
      uVector: Vec2.zero(),
      vVector: Vec2.zero(),
    );
    expect(image.grips().toSet(), {const Vec2.zero()});
    expect(image.withGrip(2, const Vec2(4, 4)), same(image));
  });
}
