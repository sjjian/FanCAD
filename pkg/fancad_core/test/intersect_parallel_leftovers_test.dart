import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('parallel lines cannot invent a crossing', () {
    expect(
      Intersect.lineLine(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(0, 4),
        const Vec2(10, 4),
      ),
      isNull,
    );
    expect(
      Intersect.segmentSegment(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(0, 4),
        const Vec2(10, 4),
      ),
      isNull,
    );
  });
}
