import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an inward offset that collapses the axes cannot invent an ellipse', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(ellipse.offsetBy(4, const Vec2.zero()), isNull);
  });

  test('reversing a full ellipse cannot invent a start', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(ellipse.reversed(), isNull);
  });

  test('a window miss cannot invent an ellipse stretch', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(
      ellipse.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(2, 0)),
      isNull,
    );
  });

  test('a full ellipse boxes its axes without flattening', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(ellipse.computeBounds(), const Bounds2(-4, -2, 4, 2));
  });

  test('an elliptical arc boxes the endpoints and the extrema it covers', () {
    const quarter = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
      startParam: 0,
      endParam: 1.5707963267948966,
    );
    final box = quarter.computeBounds();
    expect(box.minX, closeTo(0, 1e-9));
    expect(box.minY, closeTo(0, 1e-9));
    expect(box.maxX, closeTo(4, 1e-9));
    expect(box.maxY, closeTo(2, 1e-9));
  });
}
