import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renderer diagnostics expose scene and cache counters', () {
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
      )
      ..addEntity(
        const TextEntity(
          id: 4,
          position: Vec2(100, 120),
          content: 'NOTE',
          height: 5,
        ),
      );
    final renderer = CanvasRenderer()..bindAppearance(palette: AciPalette.dark);
    addTearDown(renderer.dispose);

    const viewport = CadViewport(
      center: Vec2(150, 110),
      scale: 2,
      size: ui.Size(400, 200),
    );
    for (var i = 0; i < 5; i++) {
      final recorder = ui.PictureRecorder();
      renderer.render(
        ui.Canvas(recorder),
        RenderTarget(document: document, viewport: viewport),
      );
      recorder.endRecording().dispose();
    }

    final diagnostics = renderer.diagnostics;
    expect(diagnostics.retained, isTrue);
    expect(diagnostics.entityCount, greaterThan(0));
    expect(diagnostics.segmentCount, greaterThan(0));
    expect(diagnostics.drawnSegments, greaterThan(0));
    expect(diagnostics.lineDrawCalls, greaterThan(0));
    expect(diagnostics.blockCacheMisses, 1);
    expect(diagnostics.blockCacheEntries, 1);
    expect(diagnostics.textAtlasPages, greaterThanOrEqualTo(0));
    final json = diagnostics.toJson();
    expect(json['blockCache'], isA<Map<String, Object?>>());
    expect(json['textAtlas'], isA<Map<String, Object?>>());
  });
}
