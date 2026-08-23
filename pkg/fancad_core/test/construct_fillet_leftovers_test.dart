import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const vertical = LineEntity(id: 1, start: Vec2(0, 10), end: Vec2.zero());
  const horizontal = LineEntity(id: 2, start: Vec2.zero(), end: Vec2(10, 0));

  test('a negative or non-finite radius cannot invent a fillet', () {
    expect(
      Construct.filletLines(
        vertical,
        horizontal,
        -2,
        const Vec2(0, 5),
        const Vec2(5, 0),
      ),
      isNull,
    );
    expect(
      Construct.filletLines(
        vertical,
        horizontal,
        double.nan,
        const Vec2(0, 5),
        const Vec2(5, 0),
      ),
      isNull,
    );
    expect(
      Construct.filletPolyline(
        Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!,
        double.infinity,
      ),
      isNull,
    );
  });

  test('a zero radius or lone corner cannot invent a rounded vertex', () {
    final square = Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!;
    expect(
      Construct.filletPolylineVertex(square, const Vec2.zero(), 0),
      isNull,
    );
    expect(
      Construct.filletPolylineVertex(
        PolylineEntity.fromPoints(
          id: 1,
          points: const [Vec2.zero(), Vec2(10, 0)],
        ),
        const Vec2(10, 0),
        2,
      ),
      isNull,
    );
  });
}
