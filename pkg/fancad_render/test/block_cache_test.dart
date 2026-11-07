import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two inserts share one flattened block definition', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      )
      ..addEntity(
        const InsertEntity(id: 3, blockName: 'TICK', position: Vec2(200, 100)),
      );
    final builder = WorldSceneBuilder(palette: AciPalette.dark);
    final scene = builder.build(
      document,
      const CadViewport(
        center: Vec2(150, 100),
        scale: 2,
        size: ui.Size(400, 200),
      ),
    )!;

    expect(scene.segmentCount, 2);
    expect(builder.blockCache, isNotNull);
    expect(builder.blockCache!.misses, 1);
    expect(builder.blockCache!.hits, 1);
  });

  test('the exact scene builder shares a block definition too', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      )
      ..addEntity(
        const InsertEntity(id: 3, blockName: 'TICK', position: Vec2(200, 100)),
      );
    final builder = SceneBuilder(palette: AciPalette.dark);
    final scene = builder.build(
      document,
      const CadViewport(
        center: Vec2(150, 100),
        scale: 2,
        size: ui.Size(400, 200),
      ),
    );

    expect(scene.segmentCount, 2);
    expect(builder.blockCache!.misses, 1);
    expect(builder.blockCache!.hits, 1);
  });

  test('a block insert is not copied into the per-entity cache', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      );
    final tessellation = TessellationCache();
    final builder = WorldSceneBuilder(
      palette: AciPalette.dark,
      cache: tessellation,
    );
    builder.build(
      document,
      const CadViewport(
        center: Vec2(100, 100),
        scale: 10,
        size: ui.Size(200, 200),
      ),
    )!;

    // The insert itself must not be flattened into the per-entity cache; its
    // contents belong to the shared block display cache.
    expect(tessellation.entryCount, 0);
    expect(builder.blockCache!.misses, 1);
  });

  test('an unrelated edit keeps the block display cache', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      );
    final builder = WorldSceneBuilder(palette: AciPalette.dark);
    const view = CadViewport(
      center: Vec2(100, 100),
      scale: 10,
      size: ui.Size(200, 200),
    );
    builder.build(document, view)!;
    expect(builder.blockCache!.misses, 1);

    document.addEntity(
      const LineEntity(id: 10, start: Vec2.zero(), end: Vec2(1, 0)),
    );
    builder.build(document, view)!;
    expect(builder.blockCache!.misses, 1);
    expect(builder.blockCache!.hits, greaterThan(0));
  });

  test('moving a block base point invalidates its cached display', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      );
    final builder = WorldSceneBuilder(palette: AciPalette.dark);
    const view = CadViewport(
      center: Vec2(100, 100),
      scale: 10,
      size: ui.Size(200, 200),
    );
    builder.build(document, view)!;
    expect(builder.blockCache!.misses, 1);

    document.putBlock(
      const BlockRecord(name: 'TICK', basePoint: Vec2(1, 0), entityIds: [1]),
    );
    builder.build(document, view)!;
    expect(builder.blockCache!.misses, 2);
  });

  test('editing a block definition invalidates its cached display', () {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'TICK',
    );
    document
      ..putBlock(const BlockRecord(name: 'TICK', entityIds: [1]))
      ..addEntity(
        const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
      );
    final builder = WorldSceneBuilder(palette: AciPalette.dark);
    const view = CadViewport(
      center: Vec2(100, 100),
      scale: 10,
      size: ui.Size(200, 200),
    );
    builder.build(document, view)!;
    expect(builder.blockCache!.misses, 1);

    document.addEntity(
      const LineEntity(id: 11, start: Vec2(0, 2), end: Vec2(8, 2)),
      blockName: 'TICK',
    );
    document.putBlock(const BlockRecord(name: 'TICK', entityIds: [1, 11]));
    builder.build(document, view)!;
    expect(builder.blockCache!.misses, 2);
  });
}
