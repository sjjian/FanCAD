import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed line cannot invent a circle crossing', () {
    expect(
      Intersect.lineCircle(
        const Vec2(1, 1),
        const Vec2(1, 1),
        const Vec2.zero(),
        2,
      ),
      isEmpty,
    );
    expect(
      Intersect.segmentSegment(
        const Vec2.zero(),
        const Vec2.zero(),
        const Vec2(-1, 0),
        const Vec2(1, 0),
      ),
      isNull,
    );
  });
}
