import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed span cannot invent an offset or a reverse', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(line.offsetBy(2, const Vec2(0, 1)), isNull);
    expect(line.reversed(), isNull);
    expect(line.pathLength, 0);
  });

  test('a window miss cannot invent a line stretch', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      line.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(0, 4)),
      isNull,
    );
    expect(line.stretchBy(const Bounds2(-1, -1, 1, 1), Vec2.zero()), isNull);
  });

  test('missing line JSON cannot invent a span', () {
    final line = LineEntity.fromGeometry(0, EntityProps.defaults, const {});
    expect(line.start, const Vec2.zero());
    expect(line.end, const Vec2.zero());
    expect(line.length, 0);
  });
}
