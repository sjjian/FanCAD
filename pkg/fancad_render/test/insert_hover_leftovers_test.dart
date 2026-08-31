import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a small insert still emits its definition, not a collapse point', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(
        const BlockRecord(name: 'TICK', entityIds: [1]),
      )
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      );
    // Zoomed so the 8-unit tick is well under the 1.5 px collapse size.
    const view = CadViewport(
      center: Vec2(100, 100),
      scale: 0.1,
      size: Size(200, 200),
    );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.lineBatches, isNotEmpty);
    expect(scene.pointBatches, isEmpty);
  });

  test('an insert cached against a miss clip still draws later', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2(-40, 0), end: Vec2(40, 0)),
      blockName: 'FRAME',
    );
    document
      ..putBlock(
        const BlockRecord(name: 'FRAME', entityIds: [1]),
      )
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'FRAME', position: Vec2.zero()),
      );
    final cache = TessellationCache();
    final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
    const miss = CadViewport(
      center: Vec2(400, 0),
      scale: 1,
      size: Size(80, 80),
    );
    builder.build(document, miss);
    const hit = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(80, 80),
    );
    final scene = builder.build(document, hit);
    expect(scene.lineBatches, isNotEmpty);
    expect(scene.lineBatches.single.segmentCount, greaterThan(0));
  });
}
