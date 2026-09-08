import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an inward offset that reaches the centre cannot invent a circle', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(circle.offsetBy(5, const Vec2.zero()), isNull);
    expect(circle.offsetBy(9, const Vec2.zero()), isNull);
  });

  test('a window miss cannot invent a circle stretch', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(
      circle.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(2, 0)),
      isNull,
    );
  });

  test('reversing a circle cannot invent a start', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(circle.reversed(), isNull);
  });

  test('circle quadrant grips change radius and a non-uniform scale becomes an ellipse', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
    expect(circle.grips(), const [
      Vec2.zero(),
      Vec2(5, 0),
      Vec2(0, 5),
      Vec2(-5, 0),
      Vec2(0, -5),
    ]);
    final stretched = circle.withGrip(1, const Vec2(8, 0));
    expect(stretched.center, const Vec2.zero());
    expect(stretched.radius, 8);
    final north = circle.withGrip(2, const Vec2(0, 3));
    expect(north.radius, 3);
    expect(
      circle.withGrip(0, const Vec2(1, 1)).center,
      const Vec2(1, 1),
    );
    final uniform = circle.transformed(const Mat3.scaling(2, 2)) as CircleEntity;
    expect(uniform.radius, 10);
    expect(uniform.center, const Vec2.zero());
    final tall = circle.transformed(const Mat3.scaling(1, 2)) as EllipseEntity;
    expect(tall.ratio, lessThanOrEqualTo(1));
    expect(tall.majorLength, closeTo(10, 1e-9));
    final wide = circle.transformed(const Mat3.scaling(2, 1)) as EllipseEntity;
    expect(wide.ratio, closeTo(0.5, 1e-12));
  });

  test('a sub-pixel circle collapses to a point', () {
    const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 1);
    final collapsed = PolylineSink();
    circle.emit(const EmitContext(tolerance: 0.1, minExtent: 10), collapsed);
    expect(collapsed.polylines, isEmpty);
    expect(collapsed.points, hasLength(1));

    final ring = PolylineSink();
    circle.emit(const EmitContext(tolerance: 0.1), ring);
    expect(ring.polylines, isNotEmpty);
    expect(ring.points, isEmpty);
  });
}
