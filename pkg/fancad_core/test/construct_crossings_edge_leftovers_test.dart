import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unsupported edge cannot invent a crossing', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.crossingsWith(
        line,
        const PointEntity(id: 2, position: Vec2(5, 0)),
      ),
      isEmpty,
    );
    expect(
      Construct.crossingsWith(
        line,
        const TextEntity(id: 3, position: Vec2.zero(), content: 'A'),
      ),
      isEmpty,
    );
  });
}
