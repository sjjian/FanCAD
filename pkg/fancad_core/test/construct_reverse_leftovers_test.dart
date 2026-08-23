import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed span cannot invent a reversed line', () {
    const collapsed = LineEntity(
      id: 1,
      start: Vec2.zero(),
      end: Vec2.zero(),
    );
    expect(Construct.reverse(collapsed), isNull);
  });

  test('an arc or a lone vertex cannot invent a reverse', () {
    const arc = ArcEntity(
      id: 2,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: 1.5,
    );
    expect(Construct.reverse(arc), isNull);
    expect(
      Construct.reverse(
        PolylineEntity.fromPoints(
          id: 3,
          points: const [Vec2.zero()],
        ),
      ),
      isNull,
    );
  });
}
