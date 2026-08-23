import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('duplicate vertices cannot invent a wide stroke', () {
    expect(
      Flatten.wideStroke(
        Float64List.fromList([0, 0, 0, 0]),
        2,
        closed: false,
      ),
      isNull,
    );
    expect(
      Flatten.wideStroke(
        Float64List.fromList([0, 0, 0, 0, 0, 0]),
        2,
        closed: true,
      ),
      isNull,
    );
  });
}
