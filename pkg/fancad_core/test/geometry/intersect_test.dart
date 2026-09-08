import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a collapsed line cannot invent a circle crossing', () {
    expect(
      Intersect.lineCircle(
        const Vec2(1, 1),
        const Vec2(1, 1),
        const Vec2.zero(),
        2,
      ),
      isEmpty,
    );
    expect(
      Intersect.segmentSegment(
        const Vec2.zero(),
        const Vec2.zero(),
        const Vec2(-1, 0),
        const Vec2(1, 0),
      ),
      isNull,
    );
  });

  test('a miss cannot invent a circle crossing', () {
    expect(
      Intersect.lineCircle(
        const Vec2(-10, 10),
        const Vec2(10, 10),
        const Vec2.zero(),
        2,
      ),
      isEmpty,
    );
    expect(
      Intersect.circleCircle(const Vec2.zero(), 1, const Vec2(10, 0), 1),
      isEmpty,
    );
  });

  test('parallel lines cannot invent a crossing', () {
    expect(
      Intersect.lineLine(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(0, 4),
        const Vec2(10, 4),
      ),
      isNull,
    );
    expect(
      Intersect.segmentSegment(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(0, 4),
        const Vec2(10, 4),
      ),
      isNull,
    );
  });

  test('an empty polyline cannot invent a window crossing', () {
    expect(Intersect.polylineCrossesRect(Float64List(0), 0, 0, 1, 1), isFalse);
  });

  test('fewer than three vertices cannot invent a polygon hit', () {
    expect(
      Intersect.polygonContains(
        Float64List.fromList([0, 0, 4, 0]),
        const Vec2(1, 0),
      ),
      isFalse,
    );
    expect(
      Intersect.polygonContains(Float64List(0), const Vec2.zero()),
      isFalse,
    );
  });

  test('an empty polyline cannot invent a closest-point hit', () {
    expect(
      Intersect.closestPointOnPolyline(const Vec2.zero(), Float64List(0)),
      isNull,
    );
  });

  test('line and segment crossings honour parallelism and range', () {
    expect(
      Intersect.lineLine(
        const Vec2(0, 0),
        const Vec2(2, 0),
        const Vec2(1, -1),
        const Vec2(1, 1),
      ),
      const Vec2(1, 0),
    );
    expect(
      Intersect.segmentSegment(
        const Vec2(0, 0),
        const Vec2(2, 0),
        const Vec2(1, -1),
        const Vec2(1, 1),
      ),
      const Vec2(1, 0),
    );
    expect(
      Intersect.segmentSegment(
        const Vec2(0, 0),
        const Vec2(1, 0),
        const Vec2(2, -1),
        const Vec2(2, 1),
      ),
      isNull,
    );
  });

  test('circle intersections include tangent and empty cases', () {
    final two = Intersect.lineCircle(
      const Vec2(-2, 0),
      const Vec2(2, 0),
      const Vec2.zero(),
      1,
    );
    expect(two.length, 2);
    expect(two.map((p) => p.x).toList()..sort(), [-1.0, 1.0]);
    expect(
      Intersect.lineCircle(
        const Vec2(-2, 1),
        const Vec2(2, 1),
        const Vec2.zero(),
        1,
      ),
      [const Vec2(0, 1)],
    );
    expect(
      Intersect.circleCircle(
        const Vec2.zero(),
        5,
        const Vec2(8, 0),
        5,
      ).length,
      2,
    );
    expect(
      Intersect.circleCircle(const Vec2.zero(), 5, const Vec2(10, 0), 5),
      [const Vec2(5, 0)],
    );
    expect(
      Intersect.circleCircle(const Vec2.zero(), 1, const Vec2.zero(), 2),
      isEmpty,
    );
  });

  test('closest-point helpers clamp to the segment and polyline', () {
    expect(
      Intersect.closestPointOnSegment(
        const Vec2(5, 3),
        const Vec2(0, 0),
        const Vec2(10, 0),
      ),
      const Vec2(5, 0),
    );
    expect(
      Intersect.closestPointOnSegment(
        const Vec2(-2, 1),
        const Vec2(0, 0),
        const Vec2(10, 0),
      ),
      const Vec2.zero(),
    );
    expect(
      Intersect.distanceToSegment(
        const Vec2(5, 4),
        const Vec2(0, 0),
        const Vec2(10, 0),
      ),
      4,
    );
    final single = Intersect.closestPointOnPolyline(
      const Vec2(3, 4),
      Float64List.fromList([0, 0]),
    )!;
    expect(single.distance, closeTo(5, 1e-12));
    final hit = Intersect.closestPointOnPolyline(
      const Vec2(5, 1),
      Float64List.fromList([0, 0, 10, 0, 10, 10]),
    )!;
    expect(hit.point, const Vec2(5, 0));
    expect(hit.segmentIndex, 0);
  });

  test('polygon containment and window crossing use even-odd hits', () {
    final square = Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]);
    expect(Intersect.polygonContains(square, const Vec2(5, 5)), isTrue);
    expect(Intersect.polygonContains(square, const Vec2(15, 5)), isFalse);
    expect(
      Intersect.polylineCrossesRect(
        Float64List.fromList([0, 0, 10, 10]),
        4,
        4,
        6,
        6,
      ),
      isTrue,
    );
    expect(
      Intersect.polylineCrossesRect(square, -1, -1, 11, 11, closed: true),
      isTrue,
    );
    expect(
      Intersect.polylineCrossesRect(
        Float64List.fromList([20, 20, 30, 20]),
        0,
        0,
        5,
        5,
      ),
      isFalse,
    );
    expect(
      Intersect.polylineCrossesRect(Float64List.fromList([2, 2]), 0, 0, 5, 5),
      isTrue,
    );
  });

  test('line-ellipse hits are the unit-circle hits mapped back', () {
    final axis = Intersect.lineEllipse(
      const Vec2(-4, 0),
      const Vec2(4, 0),
      const Vec2.zero(),
      const Vec2(2, 0),
      0.5,
    );
    expect(axis.length, 2);
    final xs = axis.map((p) => p.x).toList()..sort();
    expect(xs[0], closeTo(-2, 1e-9));
    expect(xs[1], closeTo(2, 1e-9));
    expect(axis.every((p) => p.y.abs() < 1e-9), isTrue);

    final chord = Intersect.lineEllipse(
      const Vec2(-4, 0.5),
      const Vec2(4, 0.5),
      const Vec2.zero(),
      const Vec2(2, 0),
      0.5,
    );
    expect(chord.length, 2);
    for (final hit in chord) {
      expect(hit.y, closeTo(0.5, 1e-9));
      expect(hit.x.abs(), closeTo(math.sqrt(3), 1e-8));
    }
    expect(
      Intersect.segmentEllipse(
        const Vec2(3, -1),
        const Vec2(3, 1),
        const Vec2.zero(),
        const Vec2(2, 0),
        0.5,
      ),
      isEmpty,
    );
  });

  test('line-spline refine lands on the curve, not just a chord', () {
    final controls = Float64List.fromList([0, 0, 1, 3, 3, 3, 4, 0]);
    const knots = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
    final hits = Intersect.lineSpline(
      const Vec2(-1, 1),
      const Vec2(5, 1),
      controls,
      knots: knots,
      degree: 3,
      tolerance: 0.4,
    );
    // y = 9t(1-t) = 1 on this clamped cubic.
    final roots = [
      (9 - math.sqrt(45)) / 18,
      (9 + math.sqrt(45)) / 18,
    ];
    final expected = [
      for (final t in roots)
        Flatten.bsplineEvaluate(
          controlPoints: controls,
          knots: knots,
          degree: 3,
          t: t,
        )!,
    ];
    expect(hits, hasLength(2));
    for (final hit in hits) {
      expect(hit.y, closeTo(1, 1e-9));
      expect(
        expected.map((point) => point.distanceTo(hit)).reduce(math.min),
        lessThan(1e-6),
      );
    }
  });

  test('circle-ellipse includes the two-circle case', () {
    final hits = Intersect.circleEllipse(
      const Vec2(1, 0),
      1,
      const Vec2.zero(),
      const Vec2(1, 0),
      1,
    );
    expect(hits.length, 2);
    for (final hit in hits) {
      expect(hit.x, closeTo(0.5, 1e-6));
      expect(hit.y.abs(), closeTo(math.sqrt(3) / 2, 1e-6));
    }
  });
}
