import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a leftover that would vanish cannot invent a lengthen', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.lengthenLine(line, const Vec2(10, 0), total: 0),
      isNull,
    );
    expect(
      Construct.lengthenLine(line, const Vec2(10, 0), delta: -10),
      isNull,
    );
  });
}
