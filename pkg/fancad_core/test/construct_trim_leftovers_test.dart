import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed span cannot invent a remnant', () {
    const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(
      Construct.trimLine(collapsed, const [Vec2.zero()], const Vec2.zero()),
      isNull,
    );

    const zeroRadius = ArcEntity(
      id: 2,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: 1,
    );
    expect(
      Construct.trimArc(zeroRadius, const [Vec2.zero()], const Vec2(1, 0)),
      isNull,
    );
  });

  test('an endpoint-only crossing or lone vertex cannot invent a remnant', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.trimLine(line, const [Vec2.zero()], const Vec2(5, 0)),
      isNull,
    );
    expect(
      Construct.trimLine(line, const [Vec2(10, 0)], const Vec2(5, 0)),
      isNull,
    );

    expect(
      Construct.trimPolyline(
        PolylineEntity.fromPoints(id: 3, points: const [Vec2.zero()]),
        const [Vec2.zero()],
        const Vec2.zero(),
      ),
      isNull,
    );
  });
}
