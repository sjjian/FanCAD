import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vertical linear stack steps the dimension line sideways', () {
    final first = Construct.linearDimension(
      const Vec2.zero(),
      const Vec2(0, 10),
      const Vec2(4, 5),
    )!;
    final next = Construct.baselineDimension(
      first,
      const Vec2(0, 18),
      spacing: 6,
    );

    expect(next, isNotNull);
    expect(next!.measurement, closeTo(18, 1e-9));
    expect(next.definitionPoints[0], const Vec2.zero());
    expect(next.definitionPoints[1], const Vec2(0, 18));
    expect(next.textPosition.x, closeTo(10, 1e-9));
  });
}
