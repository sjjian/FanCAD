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
}
