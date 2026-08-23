import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('parallel lines cannot invent a chamfer cut', () {
    const left = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    const right = LineEntity(id: 2, start: Vec2(0, 4), end: Vec2(10, 4));
    expect(
      Construct.chamferLines(
        left,
        right,
        2,
        2,
        const Vec2(5, 0),
        const Vec2(5, 4),
      ),
      isNull,
    );
  });
}
