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

  test('an image only the origin grip moves the placement', () {
    const image = ImageEntity(
      id: 1,
      reference: 'sheet.png',
      origin: Vec2.zero(),
      uVector: Vec2(10, 0),
      vVector: Vec2(0, 6),
    );
    expect(image.grips(), const [
      Vec2.zero(),
      Vec2(10, 0),
      Vec2(10, 6),
      Vec2(0, 6),
    ]);
    expect(
      image.withGrip(0, const Vec2(2, 1)).origin,
      const Vec2(2, 1),
    );

    final moved = image.transformed(const Mat3.translation(5, 0));
    expect(moved.origin, const Vec2(5, 0));
    expect(moved.uVector, const Vec2(10, 0));

    final sink = PolylineSink();
    image.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.images.single.reference, 'sheet.png');
    expect(sink.images.single.origin, const Vec2.zero());
  });
}
