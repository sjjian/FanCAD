import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an atlas run becomes ready after one page build', () {
    final cache = ParagraphCache();
    final atlas = TextAtlas(paragraphs: cache, fallbackFamily: 'Roboto');
    addTearDown(atlas.dispose);

    const item = TextItem(
      text: 'NOTE 12',
      origin: ui.Offset.zero,
      pixelHeight: 12,
      rotation: 0,
      color: ui.Color(0xFFFFFFFF),
      hAlign: 0,
      vAlign: 0,
    );
    atlas.beginFrame();
    final sprite = atlas.tryObtain(item, fontFamily: 'Roboto');
    expect(sprite, isNotNull);
    expect(sprite!.isReady, isFalse);
    expect(atlas.hasPendingWork, isTrue);
    expect(atlas.length, 1);

    expect(atlas.buildOnePage(), isTrue);
    expect(sprite.isReady, isTrue);
    expect(sprite.image, isNotNull);
    expect(atlas.hasPendingWork, isFalse);
    expect(atlas.pageCount, 1);
  });

  test('an atlas reuses a run and keeps its width factor', () {
    final cache = ParagraphCache();
    final atlas = TextAtlas(paragraphs: cache, fallbackFamily: 'Roboto');
    addTearDown(atlas.dispose);

    const item = TextItem(
      text: 'A-42',
      origin: ui.Offset.zero,
      pixelHeight: 10,
      rotation: 0,
      color: ui.Color(0xFFFFFFFF),
      hAlign: 0,
      vAlign: 0,
      widthFactor: 0.65,
    );
    atlas.beginFrame();
    final first = atlas.tryObtain(item, fontFamily: 'Roboto');
    expect(first, isNotNull);
    atlas.buildOnePage();
    expect(first!.isReady, isTrue);

    atlas.beginFrame();
    final second = atlas.tryObtain(item, fontFamily: 'Roboto');
    expect(second, isNotNull);
    expect(second!.rect, first.rect);
    expect(atlas.length, 1);
    expect(atlas.createdThisFrame, 0);
  });

  test('the world painter warms labels into its atlas', () async {
    final document = CadDocument()
      ..addEntity(
        const TextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'NOTE',
          height: 5,
        ),
      );
    const viewport = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: ui.Size(200, 200),
    );
    final scene = WorldSceneBuilder(
      palette: AciPalette.dark,
    ).build(document, viewport)!;
    final painter = WorldScenePainter(paragraphs: ParagraphCache());
    addTearDown(painter.dispose);

    for (var i = 0; i < 4; i++) {
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), scene, viewport);
      recorder.endRecording().dispose();
    }

    expect(painter.textAtlas.length, 1);
    expect(painter.textAtlas.hasPendingWork, isFalse);

    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), scene, viewport);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    var inked = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] != 0) inked++;
    }
    expect(inked, greaterThan(0));
  });
}
