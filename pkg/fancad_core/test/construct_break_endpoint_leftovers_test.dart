import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('breaking at both endpoints cannot invent leftover remnants', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.breakLine(line, const Vec2.zero(), const Vec2(10, 0)),
      isEmpty,
    );
  });
}
