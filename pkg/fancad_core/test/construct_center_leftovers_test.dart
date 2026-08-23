import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a zero size or vanished radius cannot invent a center mark', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 8);
    expect(Construct.centerMark(circle, size: 0), isNull);
    expect(Construct.centerMark(circle, size: -2), isNull);
    expect(
      Construct.centerMark(
        const CircleEntity(id: 2, center: Vec2.zero(), radius: 0),
      ),
      isNull,
    );
    expect(
      Construct.centerMark(
        const LineEntity(id: 3, start: Vec2.zero(), end: Vec2(10, 0)),
      ),
      isNull,
    );
  });

  test('a negative extension or collapsed pair cannot invent a centerline', () {
    const left = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    const right = LineEntity(id: 2, start: Vec2(0, 4), end: Vec2(10, 4));
    expect(Construct.centerLine(left, right, extension: -1), isNull);

    const collapsed = LineEntity(id: 3, start: Vec2.zero(), end: Vec2.zero());
    expect(Construct.centerLine(left, collapsed), isNull);

    expect(
      Construct.centerLine(
        left,
        const CircleEntity(id: 4, center: Vec2.zero(), radius: 2),
      ),
      isNull,
    );
  });
}
