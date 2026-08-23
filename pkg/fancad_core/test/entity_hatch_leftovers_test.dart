import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing loop or out-of-range grip cannot invent a vertex', () {
    const empty = HatchEntity(id: 1, loops: []);
    expect(empty.withGrip(0, const Vec2(1, 1)), same(empty));

    final hatch = HatchEntity(
      id: 2,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3])),
      ],
    );
    expect(hatch.withGrip(99, const Vec2(1, 1)), same(hatch));
  });
}
