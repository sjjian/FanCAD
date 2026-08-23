import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty polyline cannot invent a closest-point hit', () {
    expect(
      Intersect.closestPointOnPolyline(const Vec2.zero(), Float64List(0)),
      isNull,
    );
  });
}
