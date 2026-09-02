import 'dart:typed_data';

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

  test('a small clockwise bulge cannot inflate the bounds to the other half', () {
    final polyline = PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, -0.008, 0, 100, 0]),
    );
    final box = polyline.computeBounds();
    expect(box.width, lessThan(2));
    expect(box.height, closeTo(100, 0.5));
  });

  test('a closed mix of small opposite bulges stays near its vertices', () {
    final polyline = PolylineEntity(
      id: 1,
      closed: true,
      vertices: Float64List.fromList([
        0, 10, 0,
        30, 10, 0.008,
        30, 0, 0,
        0, 0, -0.008,
      ]),
    );
    final box = polyline.computeBounds();
    expect(box.minX, closeTo(0, 1));
    expect(box.minY, closeTo(0, 1));
    expect(box.maxX, closeTo(30, 1));
    expect(box.maxY, closeTo(10, 1));
  });

  test('mirroring a small bulge keeps a tight box after the sign flip', () {
    final polyline = PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 0.008, 10, 0, 0]),
    );
    final mirrored = polyline.transformed(
      Mat3.mirror(const Vec2.zero(), const Vec2(1, 0)),
    );
    expect(mirrored.bulgeAt(0), closeTo(-0.008, 1e-12));
    expect(mirrored.computeBounds().height, lessThan(1));
  });

  test('reversing a small clockwise bulge keeps a tight box', () {
    final polyline = PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, -0.008, 0, 100, 0]),
    );
    final reversed = polyline.reversed()! as PolylineEntity;
    expect(reversed.bulgeAt(0), closeTo(0.008, 1e-12));
    expect(reversed.computeBounds().width, lessThan(2));
  });
}
