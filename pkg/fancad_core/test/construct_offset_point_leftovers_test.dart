import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a point or text cannot invent an offset', () {
    expect(
      Construct.offset(
        const PointEntity(id: 1, position: Vec2.zero()),
        2,
        const Vec2(1, 1),
      ),
      isNull,
    );
    expect(
      Construct.offset(
        const TextEntity(id: 2, position: Vec2.zero(), content: 'A'),
        2,
        const Vec2(1, 1),
      ),
      isNull,
    );
  });
}
