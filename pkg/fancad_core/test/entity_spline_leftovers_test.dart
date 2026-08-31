import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range spline grip cannot invent a control', () {
    final spline = SplineEntity(
      id: 1,
      controlPoints: Float64List.fromList([0, 0, 2, 2, 4, 0]),
      knots: const [0, 0, 0, 1, 1, 1],
      degree: 2,
    );
    expect(spline.withGrip(-1, const Vec2(1, 1)), same(spline));
    expect(spline.withGrip(99, const Vec2(1, 1)), same(spline));
  });

  test('an empty spline cannot invent an offset', () {
    final spline = SplineEntity(id: 1, controlPoints: Float64List(0));
    expect(spline.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(spline.pathLength, 0);
  });

  test('a window miss cannot invent a spline stretch', () {
    final spline = SplineEntity(
      id: 1,
      controlPoints: Float64List.fromList([0, 0, 2, 2, 4, 0]),
      knots: const [0, 0, 0, 1, 1, 1],
      degree: 2,
    );
    expect(
      spline.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(0, 2)),
      isNull,
    );
  });
}
