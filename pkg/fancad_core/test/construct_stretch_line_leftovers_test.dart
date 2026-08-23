import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a window miss cannot invent a line stretch', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.stretch(
        line,
        const Bounds2(100, 100, 101, 101),
        const Vec2(0, 4),
      ),
      isNull,
    );
    expect(
      Construct.stretch(line, const Bounds2(-1, -1, 1, 1), Vec2.zero()),
      isNull,
    );
  });
}
