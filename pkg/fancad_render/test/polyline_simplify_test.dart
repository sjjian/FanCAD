import 'dart:typed_data';

import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a collinear run collapses to its endpoints', () {
    final xy = Float64List.fromList([0, 0, 1, 0, 2, 0, 3, 0, 4, 0]);
    final result = simplifyPolyline(xy, 0.15);
    expect(result, [0, 0, 4, 0]);
  });

  test('a closed ring keeps its corners and closes through the split', () {
    final xy = Float64List.fromList([
      0,
      0,
      1,
      0,
      2,
      0,
      2,
      1,
      2,
      2,
      1,
      2,
      0,
      2,
      0,
      1,
    ]);
    final result = simplifyPolyline(xy, 0.15, closed: true);
    expect(result.length, 8);
    expect(result, [0, 0, 2, 0, 2, 2, 0, 2]);
  });

  test('a non-zero tolerance keeps a genuine corner', () {
    final xy = Float64List.fromList([0, 0, 1, 0, 2, 0, 2, 2]);
    final result = simplifyPolyline(xy, 0.15);
    expect(result, [0, 0, 2, 0, 2, 2]);
  });

  test('a zero tolerance leaves the polyline untouched', () {
    final xy = Float64List.fromList([0, 0, 1, 0, 2, 0, 3, 0]);
    expect(identical(simplifyPolyline(xy, 0), xy), isTrue);
  });
}
