import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  final spline = Construct.splineFromControls(const [
    Vec2(0, 0),
    Vec2(4, 4),
    Vec2(8, 0),
    Vec2(12, 4),
  ])!;

  test('a window stretch moves only the captured spline control', () {
    final stretched = Construct.stretch(
      spline,
      const Bounds2(-1, -1, 1, 1),
      const Vec2(0, 3),
    )! as SplineEntity;

    expect(stretched.grips()[0], const Vec2(0, 3));
    expect(stretched.grips()[1], const Vec2(4, 4));
    expect(stretched.grips()[2], const Vec2(8, 0));
    expect(stretched.grips()[3], const Vec2(12, 4));
  });

  test('a window miss or zero delta cannot drag the whole spline', () {
    expect(
      Construct.stretch(
        spline,
        const Bounds2(100, 100, 101, 101),
        const Vec2(0, 3),
      ),
      isNull,
    );
    expect(
      Construct.stretch(
        spline,
        const Bounds2(-1, -1, 1, 1),
        Vec2.zero(),
      ),
      isNull,
    );
  });
}
