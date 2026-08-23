import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a solid hatch cannot invent pattern strokes', () {
    final hatch = HatchEntity(
      id: 1,
      solid: true,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    );
    expect(const HatchGenerator().generate(hatch), isEmpty);
  });
}
