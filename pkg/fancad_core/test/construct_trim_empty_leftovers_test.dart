import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty crossings cannot invent a trim remnant', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(Construct.trimLine(line, const [], const Vec2(5, 0)), isNull);
    expect(
      Construct.trimPolyline(
        PolylineEntity.fromPoints(
          id: 2,
          points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
        ),
        const [],
        const Vec2(5, 0),
      ),
      isNull,
    );
  });
}
