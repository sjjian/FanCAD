import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a collapsed rectangle or non-positive radius cannot invent a primitive',
    () {
      expect(Construct.rectangle(const Vec2.zero(), const Vec2(10, 0)), isNull);
      expect(Construct.rectangle(const Vec2.zero(), const Vec2.zero()), isNull);
      expect(
        Construct.ellipse(
          center: const Vec2.zero(),
          axisEnd: const Vec2(10, 0),
          otherRadius: 0,
        ),
        isNull,
      );
      expect(
        Construct.ellipse(
          center: const Vec2.zero(),
          axisEnd: const Vec2(10, 0),
          otherRadius: double.nan,
        ),
        isNull,
      );
    },
  );

  test('a non-finite tangent radius cannot invent a circle', () {
    const vertical = LineEntity(id: 1, start: Vec2(0, 10), end: Vec2.zero());
    const horizontal = LineEntity(id: 2, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.circleTangentRadius(
        vertical,
        horizontal,
        -2,
        const Vec2(0, 5),
        const Vec2(5, 0),
      ),
      isNull,
    );
    expect(
      Construct.circleTangentRadius(
        vertical,
        horizontal,
        double.nan,
        const Vec2(0, 5),
        const Vec2(5, 0),
      ),
      isNull,
    );
    expect(
      Construct.circleTangentRadius(
        const LineEntity(id: 3, start: Vec2.zero(), end: Vec2(10, 0)),
        const LineEntity(id: 4, start: Vec2(0, 4), end: Vec2(10, 4)),
        2,
        const Vec2(5, 1),
        const Vec2(5, 5),
      ),
      isNull,
    );
  });
}
