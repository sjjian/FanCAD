import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished vector cannot invent a unit direction', () {
    expect(const Vec2.zero().normalized(), const Vec2.zero());
    expect(const Vec2.zero().normalized().isFinite, isTrue);
  });

  test('arithmetic, length and angles stay consistent', () {
    const a = Vec2(3, 4);
    const b = Vec2(1, -1);
    expect(a + b, const Vec2(4, 3));
    expect(a - b, const Vec2(2, 5));
    expect(a * 2, const Vec2(6, 8));
    expect(a / 2, const Vec2(1.5, 2));
    expect(-a, const Vec2(-3, -4));
    expect(a.length, closeTo(5, 1e-12));
    expect(a.lengthSquared, 25);
    expect(a.distanceTo(const Vec2.zero()), closeTo(5, 1e-12));
    expect(a.dot(const Vec2(4, -3)), 0);
    expect(const Vec2(1, 0).cross(const Vec2(0, 1)), 1);
    expect(const Vec2(1, 0).perpendicular, const Vec2(0, 1));
    expect(const Vec2(1, 0).angle, closeTo(0, 1e-12));
  });

  test('polar, normalize, rotate and lerp cover the remaining ops', () {
    final polar = Vec2.polar(math.pi / 2, 2);
    expect(polar.x, closeTo(0, 1e-12));
    expect(polar.y, closeTo(2, 1e-12));
    expect(const Vec2(0, 4).normalized(), const Vec2(0, 1));
    final turned = const Vec2(1, 0).rotated(math.pi / 2);
    expect(turned.x, closeTo(0, 1e-12));
    expect(turned.y, closeTo(1, 1e-12));
    expect(const Vec2(0, 0).lerp(const Vec2(10, 4), 0.25), const Vec2(2.5, 1));
    expect(const Vec2(1, 2).toVec3(3), const Vec3(1, 2, 3));
    expect(const Vec2(1, 2).isFinite, isTrue);
    expect(const Vec2(1, double.nan).isFinite, isFalse);
    expect(const Vec2(1, 2), const Vec2(1, 2));
    expect({const Vec2(1, 2)}.contains(const Vec2(1, 2)), isTrue);
    expect(const Vec2(1, 2).toString(), contains('1.0000'));
  });

  test('Vec3 adds, scales and projects onto the drawing plane', () {
    const a = Vec3(1, 2, 3);
    expect(a + const Vec3(1, 1, 1), const Vec3(2, 3, 4));
    expect(a - const Vec3(1, 0, 1), const Vec3(0, 2, 2));
    expect(a * 2, const Vec3(2, 4, 6));
    expect(a.xy, const Vec2(1, 2));
    expect(a.length, closeTo(math.sqrt(14), 1e-12));
    expect(const Vec3.zero(), const Vec3(0, 0, 0));
    expect({a}.contains(const Vec3(1, 2, 3)), isTrue);
    expect(a.toString(), 'Vec3(1.0, 2.0, 3.0)');
  });

  test('normalize wraps into a half-open turn', () {
    expect(normalizeAngle(0), 0);
    expect(normalizeAngle(math.pi * 2), closeTo(0, 1e-12));
    expect(normalizeAngle(-math.pi / 2), closeTo(math.pi * 1.5, 1e-12));
  });

  test('angular sweep is always counter-clockwise and non-negative', () {
    expect(angularSweep(0, math.pi / 2), closeTo(math.pi / 2, 1e-12));
    expect(angularSweep(math.pi / 2, 0), closeTo(math.pi * 1.5, 1e-12));
    expect(angularSweep(0, 0), 0);
  });
}
