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
}
