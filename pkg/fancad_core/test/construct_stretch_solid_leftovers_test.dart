import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const solid = SolidEntity(
    id: 1,
    corners: [
      Vec2(0, 0),
      Vec2(4, 0),
      Vec2(4, 3),
      Vec2(0, 3),
    ],
  );

  test('a window stretch moves only the captured fill corner', () {
    final stretched = Construct.stretch(
      solid,
      const Bounds2(-1, -1, 1, 1),
      const Vec2(0, 2),
    )! as SolidEntity;

    expect(stretched.corners, const [
      Vec2(0, 2),
      Vec2(4, 0),
      Vec2(4, 3),
      Vec2(0, 3),
    ]);
  });

  test('a window miss cannot drag a solid fill', () {
    expect(
      Construct.stretch(
        solid,
        const Bounds2(40, 40, 41, 41),
        const Vec2(0, 2),
      ),
      isNull,
    );
  });
}
