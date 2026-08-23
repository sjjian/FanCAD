import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a tiny pattern scale cannot invent unbounded strokes', () {
    final hatch = HatchEntity(
      id: 1,
      solid: false,
      patternName: 'ANSI31',
      patternScale: 0.001,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    );
    final strokes = const HatchGenerator().generate(hatch);
    expect(strokes, isNotEmpty);
    expect(strokes.length, lessThanOrEqualTo(500));
  });
}
