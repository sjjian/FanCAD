import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty xy buffer cannot invent a box', () {
    expect(Bounds2.fromXY(Float64List(0)).isEmpty, isTrue);
  });
}
