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

  test('a line midpoint grip moves the whole segment', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(line.grips(), const [Vec2.zero(), Vec2(5, 0), Vec2(10, 0)]);
    final moved = line.withGrip(1, const Vec2(5, 4)) as LineEntity;
    expect(moved.start, const Vec2(0, 4));
    expect(moved.end, const Vec2(10, 4));
    expect(line.withGrip(9, const Vec2(1, 1)), line);
    expect(line.withId(2).id, 2);
    expect(line.withProps(const EntityProps(layer: 'A')).props.layer, 'A');
  });
}
