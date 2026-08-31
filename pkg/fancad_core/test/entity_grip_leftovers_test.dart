import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range grip cannot invent a new control point', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(line.withGrip(-1, const Vec2(1, 1)), same(line));
    expect(line.withGrip(99, const Vec2(1, 1)), same(line));

    final unknown = UnknownEntity(id: 2, originalType: 'PROXY');
    expect(unknown.withGrip(0, const Vec2(4, 4)), same(unknown));
  });
}
