import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('ray grips move the origin without inventing a box', () {
    const ray = RayEntity(id: 1, origin: Vec2.zero(), direction: Vec2(1, 0));
    expect(ray.computeBounds(), const Bounds2(0, 0, 0, 0));
    expect(ray.indexBounds().maxX, greaterThan(1e6));
    expect(ray.indexBounds().minX, closeTo(0, 1e-9));
    expect(ray.withGrip(0, const Vec2(2, 3)).origin, const Vec2(2, 3));
    expect(
      ray.withGrip(1, const Vec2(0, 4)).direction,
      const Vec2(0, 4),
    );
    final rotated = ray.transformed(Mat3.rotation(math.pi / 2));
    expect(rotated.direction.x, closeTo(0, 1e-9));
    expect(rotated.direction.y, closeTo(1, 1e-9));
  });
}
