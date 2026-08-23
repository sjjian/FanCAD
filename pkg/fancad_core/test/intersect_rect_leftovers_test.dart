import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty polyline cannot invent a window crossing', () {
    expect(
      Intersect.polylineCrossesRect(Float64List(0), 0, 0, 1, 1),
      isFalse,
    );
  });
}
