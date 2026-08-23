import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a window miss cannot invent a hatch stretch', () {
    final hatch = HatchEntity(
      id: 1,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    );
    expect(
      Construct.stretch(
        hatch,
        const Bounds2(100, 100, 101, 101),
        const Vec2(4, 0),
      ),
      isNull,
    );
  });
}
