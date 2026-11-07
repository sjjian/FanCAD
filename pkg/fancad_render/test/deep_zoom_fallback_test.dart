import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CadDocument drawing() {
    final document = CadDocument();
    for (var i = 0; i < 200; i++) {
      final x = (i % 20) * 10.0;
      final y = (i ~/ 20) * 10.0;
      document.addEntity(
        LineEntity(id: i + 1, start: Vec2(x, y), end: Vec2(x + 8, y + 8)),
      );
    }
    return document;
  }

  void render(CanvasRenderer renderer, CadDocument document, CadViewport view) {
    final recorder = ui.PictureRecorder();
    renderer.render(
      ui.Canvas(recorder),
      RenderTarget(document: document, viewport: view),
    );
    recorder.endRecording().dispose();
  }

  test('a zoom well past the retained detail uses the camera-baked path', () {
    final document = drawing();
    final renderer = CanvasRenderer()..bindAppearance(palette: AciPalette.dark);
    addTearDown(renderer.dispose);

    const overview = CadViewport(
      center: Vec2(95, 45),
      scale: 1,
      size: ui.Size(400, 200),
    );
    for (var i = 0; i < 40; i++) {
      render(renderer, document, overview);
    }
    expect(renderer.diagnostics.retained, isTrue);
    final overviewExact = renderer.cache.scene?.viewport.scale;

    // Within the detail the retained list stores, it stays the display: the
    // camera-baked cache is not rebuilt at the new scale.
    render(
      renderer,
      document,
      const CadViewport(
        center: Vec2(95, 45),
        scale: 4,
        size: ui.Size(400, 200),
      ),
    );
    expect(renderer.cache.scene?.viewport.scale, overviewExact);

    // Sixteen times the build scale: a point marker would be a visible dot, so
    // the camera-baked path takes over and rebuilds at this scale.
    render(
      renderer,
      document,
      const CadViewport(
        center: Vec2(95, 45),
        scale: 16,
        size: ui.Size(400, 200),
      ),
    );
    expect(renderer.cache.scene, isNotNull);
    expect(renderer.cache.scene!.viewport.scale, 16);
    expect(renderer.cache.scene!.entityCount, greaterThan(0));
  });
}
