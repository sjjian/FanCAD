import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('parallel or collapsed lines cannot invent an angular dim', () {
    const left = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    const right = LineEntity(id: 2, start: Vec2(0, 4), end: Vec2(10, 4));
    expect(
      Construct.angularDimensionFromLines(left, right, const Vec2(5, 2)),
      isNull,
    );
    expect(
      Construct.angularDimensionFromLines(
        const LineEntity(id: 3, start: Vec2.zero(), end: Vec2.zero()),
        left,
        const Vec2(5, 2),
      ),
      isNull,
    );
  });
}
