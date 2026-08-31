import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range polyline grip cannot invent a vertex', () {
    final polyline = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2.zero(), Vec2(4, 0), Vec2(4, 3)],
    );
    expect(polyline.withGrip(-1, const Vec2(1, 1)), same(polyline));
    expect(polyline.withGrip(99, const Vec2(1, 1)), same(polyline));
  });

  test('a lone vertex cannot invent an offset or a reverse', () {
    final polyline = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2.zero()],
    );
    expect(polyline.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(polyline.reversed(), isNull);
    expect(polyline.signedArea, 0);
  });

  test('a window miss cannot invent a polyline stretch', () {
    final polyline = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2.zero(), Vec2(4, 0)],
    );
    expect(
      polyline.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(0, 2)),
      isNull,
    );
  });
}
