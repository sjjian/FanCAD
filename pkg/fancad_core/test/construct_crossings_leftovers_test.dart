import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a line still reports the crossing used by TRIM', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    const edge = LineEntity(id: 2, start: Vec2(4, -2), end: Vec2(4, 2));
    expect(Construct.crossingsAlong(line, edge), const [Vec2(4, 0)]);
  });

  test('a circle target cannot invent trim points', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    const edge = LineEntity(id: 2, start: Vec2(-10, 0), end: Vec2(10, 0));
    expect(Construct.crossingsAlong(circle, edge), isEmpty);
  });
}
