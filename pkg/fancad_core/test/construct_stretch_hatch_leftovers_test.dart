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

  test('a window that covers one hatch vertex only moves that vertex', () {
    final hatch = HatchEntity(
      id: 1,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    );
    final next = Construct.stretch(
      hatch,
      const Bounds2(-1, -1, 1, 1),
      const Vec2(4, 0),
    );
    expect(next, isA<HatchEntity>());
    final stretched = next as HatchEntity;
    expect(stretched.loops.single.vertices[0], closeTo(4, 1e-9));
    expect(stretched.loops.single.vertices[1], closeTo(0, 1e-9));
    expect(stretched.loops.single.vertices[2], closeTo(20, 1e-9));
    expect(stretched.loops.single.vertices[3], closeTo(0, 1e-9));
    expect(stretched.loops.single.vertices[4], closeTo(20, 1e-9));
    expect(stretched.loops.single.vertices[5], closeTo(20, 1e-9));
  });
}
