import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed span cannot invent a lengthened remnant', () {
    const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
    expect(
      Construct.lengthenLine(collapsed, const Vec2.zero(), total: 10),
      isNull,
    );

    expect(
      Construct.lengthenPolyline(
        PolylineEntity.fromPoints(id: 2, points: const [Vec2.zero()]),
        const Vec2.zero(),
        total: 10,
      ),
      isNull,
    );
    expect(
      Construct.lengthenPolyline(
        PolylineEntity.fromPoints(
          id: 3,
          points: const [Vec2.zero(), Vec2.zero()],
        ),
        const Vec2.zero(),
        total: 10,
      ),
      isNull,
    );

    const zeroArc = ArcEntity(
      id: 4,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(
      Construct.lengthenArc(zeroArc, const Vec2.zero(), total: 10),
      isNull,
    );
  });

  test('a non-finite or closed result cannot invent a length change', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(
      Construct.lengthenLine(line, const Vec2(10, 0), total: double.nan),
      isNull,
    );
    expect(
      Construct.lengthenLine(line, const Vec2(10, 0), total: double.infinity),
      isNull,
    );

    final elbow = PolylineEntity.fromPoints(
      id: 2,
      points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
    );
    expect(
      Construct.lengthenPolyline(elbow, const Vec2(10, 10), total: double.nan),
      isNull,
    );

    const quarter = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(
      Construct.lengthenArc(quarter, const Vec2(0, 10), total: double.infinity),
      isNull,
    );
    expect(
      Construct.lengthenArc(
        const ArcEntity(
          id: 4,
          center: Vec2.zero(),
          radius: 10,
          startAngle: 0,
          endAngle: 0,
        ),
        const Vec2(10, 0),
        total: 10,
      ),
      isNull,
    );
  });
}
