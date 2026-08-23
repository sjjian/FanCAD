import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('fewer than two segments cannot invent divide points', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    expect(Construct.divideLine(line, 0), isEmpty);
    expect(Construct.divideLine(line, 1), isEmpty);

    final polyline = PolylineEntity.fromPoints(
      id: 2,
      points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
    );
    expect(Construct.dividePolyline(polyline, 1), isEmpty);

    const arc = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    expect(Construct.divideArc(arc, 1), isEmpty);
    expect(
      Construct.divideCircle(
        const CircleEntity(id: 4, center: Vec2.zero(), radius: 5),
        1,
      ),
      isEmpty,
    );
  });

  test('a collapsed or zero-radius curve cannot invent divide points', () {
    expect(
      Construct.dividePolyline(
        PolylineEntity.fromPoints(id: 1, points: const [Vec2.zero()]),
        4,
      ),
      isEmpty,
    );
    expect(
      Construct.dividePolyline(
        PolylineEntity.fromPoints(
          id: 2,
          points: const [Vec2.zero(), Vec2.zero()],
        ),
        4,
      ),
      isEmpty,
    );

    const zeroArc = ArcEntity(
      id: 3,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: math.pi,
    );
    expect(Construct.divideArc(zeroArc, 4), isEmpty);

    const zeroSweep = ArcEntity(
      id: 4,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: 0,
    );
    expect(Construct.divideArc(zeroSweep, 4), isEmpty);

    expect(
      Construct.divideCircle(
        const CircleEntity(id: 5, center: Vec2.zero(), radius: 0),
        4,
      ),
      isEmpty,
    );
  });
}
