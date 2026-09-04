import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a sub-pixel insert still leaves a mark so it does not vanish', () {
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
    expect(
      scene.lineBatches.isNotEmpty || scene.pointBatches.isNotEmpty,
      isTrue,
    );
  });

  test('a visible insert collapses members smaller than a pixel', () {
    final document = CadDocument();
    // A 200-unit frame stays several pixels at this zoom; the 4-unit ticks
    // inside it are well under 1.5 px and must not dump as linework.
    document
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(200, 0)),
        blockName: 'CELL',
      )
      ..addEntity(
        const LineEntity(id: 2, start: Vec2(200, 0), end: Vec2(200, 200)),
        blockName: 'CELL',
      )
      ..addEntity(
        const LineEntity(id: 3, start: Vec2(200, 200), end: Vec2(0, 200)),
        blockName: 'CELL',
      )
      ..addEntity(
        const LineEntity(id: 4, start: Vec2.zero(), end: Vec2(0, 200)),
        blockName: 'CELL',
      );
    for (var i = 0; i < 40; i++) {
      document.addEntity(
        LineEntity(
          id: 10 + i,
          start: Vec2(10.0 + i * 4, 10),
          end: Vec2(12.0 + i * 4, 12),
        ),
        blockName: 'CELL',
      );
    }
    document
      ..putBlock(
        BlockRecord(
          name: 'CELL',
          entityIds: [1, 2, 3, 4, for (var i = 0; i < 40; i++) 10 + i],
        ),
      )
      ..addEntity(
        const InsertEntity(id: 100, blockName: 'CELL', position: Vec2.zero()),
      );
    const view = CadViewport(
      center: Vec2(100, 100),
      scale: 0.2,
      size: Size(200, 200),
    );
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.lineBatches, isNotEmpty);
    expect(scene.segmentCount, lessThan(10));
    expect(scene.pointBatches, isNotEmpty);
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

  test('hover pick reuses tessellation without collapsing an insert', () {
    final document = CadDocument();
    document.addEntity(
      const CircleEntity(id: 1, center: Vec2.zero(), radius: 8),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2.zero()),
      );
    final cache = TessellationCache();
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 0.1,
      size: Size(200, 200),
    );
    SceneBuilder(palette: AciPalette.dark, cache: cache).build(document, view);
    cache.resetStatistics();

    final picker = Picker(cache: cache);
    expect(picker.pickTopmost(document, view, const Vec2.zero()), isNotNull);
    expect(cache.misses, greaterThan(0));
    final misses = cache.misses;
    cache.resetStatistics();
    expect(picker.pickTopmost(document, view, const Vec2.zero()), isNotNull);
    expect(cache.hits, greaterThan(0));
    expect(cache.misses, 0);
    expect(misses, greaterThan(0));
  });
}
