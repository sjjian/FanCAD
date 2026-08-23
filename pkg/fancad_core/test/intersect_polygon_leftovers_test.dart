import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('fewer than three vertices cannot invent a polygon hit', () {
    expect(
      Intersect.polygonContains(
        Float64List.fromList([0, 0, 4, 0]),
        const Vec2(1, 0),
      ),
      isFalse,
    );
    expect(Intersect.polygonContains(Float64List(0), const Vec2.zero()), isFalse);
  });
}
