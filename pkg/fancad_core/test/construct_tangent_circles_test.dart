import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('two circles name an external tangent centre', () {
    const left = CircleEntity(id: 1, center: Vec2.zero(), radius: 3);
    const right = CircleEntity(id: 2, center: Vec2(8, 0), radius: 3);
    final circle = Construct.circleTangentRadius(
      left,
      right,
      2,
      const Vec2(0, 8),
      const Vec2(8, 8),
    );

    expect(circle, isNotNull);
    expect(circle!.radius, 2);
    expect(circle.center.x, closeTo(4, 1e-6));
    expect(circle.center.y.abs(), greaterThan(1));
  });

  test('a circle then a line still finds the same tangent', () {
    final circle = Construct.circleTangentRadius(
      const CircleEntity(id: 1, center: Vec2(0, 5), radius: 3),
      const LineEntity(id: 2, start: Vec2(-10, 0), end: Vec2(10, 0)),
      1,
      const Vec2(0, 10),
      const Vec2(0, 1),
    );

    expect(circle, isNotNull);
    expect(circle!.center.x, closeTo(0, 1e-9));
    expect(circle.center.y, closeTo(1, 1e-9));
  });
}
