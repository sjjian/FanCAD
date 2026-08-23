import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('collapsed hatch loops cannot invent pattern strokes', () {
    final hatch = HatchEntity(
      id: 1,
      solid: false,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 0, 0, 0, 0])),
      ],
    );
    expect(const HatchGenerator().generate(hatch), isEmpty);
  });
}
