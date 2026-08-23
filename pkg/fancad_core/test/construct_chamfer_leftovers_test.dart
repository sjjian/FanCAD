import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const vertical = LineEntity(id: 1, start: Vec2(0, 10), end: Vec2.zero());
  const horizontal = LineEntity(id: 2, start: Vec2.zero(), end: Vec2(10, 0));

  test('a negative or non-finite distance cannot invent a chamfer', () {
    expect(
      Construct.chamferLines(
        vertical,
        horizontal,
        -2,
        2,
        const Vec2(0, 5),
        const Vec2(5, 0),
      ),
      isNull,
    );
    expect(
      Construct.chamferLines(
        vertical,
        horizontal,
        2,
        double.nan,
        const Vec2(0, 5),
        const Vec2(5, 0),
      ),
      isNull,
    );
    expect(
      Construct.chamferPolyline(
        Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!,
        dist1: double.infinity,
      ),
      isNull,
    );
  });

  test('a zero distance or lone corner cannot invent a bevel', () {
    final square = Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!;
    expect(
      Construct.chamferPolylineVertex(square, const Vec2.zero(), dist1: 0),
      isNull,
    );
    expect(
      Construct.chamferPolylineVertex(
        PolylineEntity.fromPoints(
          id: 1,
          points: const [Vec2.zero(), Vec2(10, 0)],
        ),
        const Vec2(10, 0),
        dist1: 2,
      ),
      isNull,
    );
  });
}
