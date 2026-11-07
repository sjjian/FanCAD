import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a world scene keeps geometry far outside the reference camera', () {
    final document = CadDocument()
      ..addEntity(const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)))
      ..addEntity(
        const LineEntity(id: 2, start: Vec2(10000, 0), end: Vec2(10010, 0)),
      )
      ..addEntity(
        const LineEntity(id: 3, start: Vec2(20000, 0), end: Vec2(20010, 0)),
      );
    const reference = CadViewport(
      center: Vec2.zero(),
      scale: 10,
      size: ui.Size(100, 100),
    );
    final scene = WorldSceneBuilder(
      palette: AciPalette.dark,
    ).build(document, reference);

    expect(scene, isNotNull);
    expect(scene!.segmentCount, 3);
    expect(scene.lineBatches, isNotEmpty);
    // The reference camera sees only the first line; the retained scene still
    // holds the other two so zooming out never reveals an empty border.
    expect(scene.bounds.width, greaterThan(20000));
  });

  test('a world scene paints under a zoomed-out camera', () {
    final document = CadDocument()
      ..addEntity(const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)))
      ..addEntity(
        const LineEntity(id: 2, start: Vec2(10000, 0), end: Vec2(10010, 0)),
      );
    const reference = CadViewport(
      center: Vec2.zero(),
      scale: 10,
      size: ui.Size(100, 100),
    );
    final scene = WorldSceneBuilder(
      palette: AciPalette.dark,
    ).build(document, reference)!;
    final painter = WorldScenePainter(paragraphs: ParagraphCache());
    const zoomedOut = CadViewport(
      center: Vec2(5000, 0),
      scale: 0.01,
      size: ui.Size(800, 600),
    );
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), scene, zoomedOut);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(800, 600);
    expect(image.width, 800);
    image.dispose();
    picture.dispose();
  });

  test('a world scene carries text through to the painter', () {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'NOTE',
          height: 5,
        ),
      );
    const reference = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: ui.Size(200, 200),
    );
    final scene = WorldSceneBuilder(
      palette: AciPalette.dark,
    ).build(document, reference)!;
    expect(scene.texts, hasLength(1));
    final painter = WorldScenePainter(paragraphs: ParagraphCache());
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), scene, reference);
    recorder.endRecording().dispose();
  });

  test(
    'a zoom uses the retained scene without rebuilding the exact one',
    () async {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        )
        ..addEntity(
          const LineEntity(id: 2, start: Vec2(1000, 0), end: Vec2(1010, 0)),
        );
      final renderer = CanvasRenderer()
        ..bindAppearance(palette: AciPalette.dark);
      addTearDown(renderer.dispose);
      var builds = 0;
      renderer.onSceneBuilt = (_) => builds++;

      var viewport = const CadViewport(
        center: Vec2(5, 0),
        scale: 10,
        size: ui.Size(200, 100),
      );
      ui.Image render() {
        final recorder = ui.PictureRecorder();
        renderer.render(
          ui.Canvas(recorder),
          RenderTarget(document: document, viewport: viewport),
        );
        final picture = recorder.endRecording();
        final image = picture.toImageSync(200, 100);
        picture.dispose();
        return image;
      }

      render().dispose();
      expect(builds, 1);

      // Zoom out so both the near and far line are visible. This is still a
      // moving camera: the retained scene paints it, and no exact scene is built.
      viewport = const CadViewport(
        center: Vec2(500, 0),
        scale: 0.1,
        size: ui.Size(200, 100),
      );
      final image = render();
      expect(
        builds,
        1,
        reason: 'a zoom frame must not rebuild the exact scene',
      );

      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);
      // The far line lands near x=150. If the frame were still the camera-baked
      // recording it would be missing, so a painted pixel proves the retained
      // scene is what the zoom is showing.
      var farInk = 0;
      for (var x = 148; x <= 152; x++) {
        for (var y = 48; y <= 52; y++) {
          final alpha = bytes!.getUint8((y * 200 + x) * 4 + 3);
          if (alpha > 0) farInk++;
        }
      }
      expect(farInk, greaterThan(0));
      image.dispose();
    },
  );

  test('the retained scene is flattened finer than the reference camera', () {
    // A point-per-object overview is only meant to be seen from far away. If
    // the preview detail is not several times finer than the reference camera,
    // zooming in leaves every small object as the dot it was collapsed to.
    expect(WorldSceneBuilder.previewDetail, greaterThan(1));

    final document = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(0.5, 0)),
      );
    const reference = CadViewport(
      center: Vec2(0.25, 0),
      scale: 1,
      size: ui.Size(100, 100),
    );
    final scene = WorldSceneBuilder(
      palette: AciPalette.dark,
    ).build(document, reference)!;
    expect(scene.segmentCount, 1);
  });
}
