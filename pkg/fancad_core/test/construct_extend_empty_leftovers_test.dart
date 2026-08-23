import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty edges cannot invent an extension', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(Construct.extendLine(line, const []), isNull);
    expect(
      Construct.extendPolyline(
        PolylineEntity.fromPoints(
          id: 2,
          points: const [Vec2.zero(), Vec2(10, 0)],
        ),
        const [],
      ),
      isNull,
    );
  });
}
