import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a selected circle becomes an exact conic region', () {
    final geometry = const RegionBuilder().build([
      const CircleEntity(id: 1, center: Vec2(10, 20), radius: 5),
    ]);
    expect(geometry, isNotNull);
    expect(geometry!.components, hasLength(1));
    expect(geometry.approximated, isFalse);
    expect(geometry.signedArea, closeTo(math.pi * 25, 1e-6));
  });

  test('selected lines chain into a closed region', () {
    final geometry = const RegionBuilder().build([
      const LineEntity(id: 1, start: Vec2(0, 0), end: Vec2(10, 0)),
      const LineEntity(id: 2, start: Vec2(10, 0), end: Vec2(10, 10)),
      const LineEntity(id: 3, start: Vec2(10, 10), end: Vec2(0, 10)),
      const LineEntity(id: 4, start: Vec2(0, 10), end: Vec2(0, 0)),
    ]);
    expect(geometry, isNotNull);
    expect(geometry!.signedArea, closeTo(100, 1e-6));
    expect(geometry.approximated, isFalse);
  });

  test('a bulged polyline keeps its arc', () {
    final vertices = Float64List.fromList([
      0,
      0,
      1,
      10,
      0,
      0,
      10,
      10,
      0,
      0,
      10,
      0,
    ]);
    final geometry = const RegionBuilder().build([
      PolylineEntity(id: 1, vertices: vertices, closed: true),
    ]);
    expect(geometry, isNotNull);
    expect(
      geometry!.components.single.outer.curves.whereType<RegionConicArc>(),
      hasLength(1),
    );
    expect(geometry.signedArea, greaterThan(100));
  });
}
