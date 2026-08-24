import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(200, 200));

  RenderScene sceneWithEveryBatch() {
    final lines = LineBatch(const BatchKey(Color(0xFFFFFFFF), 1))
      ..vertices.add4(0, 0, 10, 0);
    final points = PointBatch(const BatchKey(Color(0xFFFF0000), 3))
      ..vertices.add2(5, 5);
    final fills = FillBatch(const BatchKey(Color(0xFF00FF00), 0))
      ..addRing(Float32List.fromList([0, 0, 10, 0, 10, 10, 0, 10]));
    return RenderScene(
      viewport: view,
      lineBatches: [lines],
      pointBatches: [points],
      fillBatches: [fills],
      texts: const [
        TextItem(
          text: 'A',
          origin: Offset(4, 4),
          pixelHeight: 12,
          rotation: 0.2,
          color: Color(0xFFFFFFFF),
          hAlign: 1,
          vAlign: 2,
          wrapWidth: 40,
          isMultiline: true,
        ),
        TextItem(
          text: 'B',
          origin: Offset(20, 4),
          pixelHeight: 12,
          rotation: 0,
          color: Color(0xFFFFFFFF),
          hAlign: 2,
          vAlign: 0,
        ),
      ],
      images: const [
        ImageItem(
          reference: 'plate.png',
          origin: Offset(0, 0),
          uVector: Offset(12, 0),
          vVector: Offset(0, 8),
        ),
      ],
      entityCount: 4,
      segmentCount: 1,
      culledCount: 0,
      buildTime: Duration.zero,
      coverage: const Bounds2(0, 0, 20, 20),
    );
  }

  test('record of an empty scene still produces a picture', () {
    final picture = ScenePainter().record(RenderScene.empty(view));
    expect(picture, isA<Picture>());
    picture.dispose();
  });

  test('a recorded scene rasterises at the viewport size', () async {
    final picture = ScenePainter().record(sceneWithEveryBatch());
    final image = await picture.toImage(
      view.size.width.toInt(),
      view.size.height.toInt(),
    );
    expect(image.width, view.size.width.toInt());
    expect(image.height, view.size.height.toInt());
    image.dispose();
    picture.dispose();
  });

  test('paint walks fills, lines, points, text and an image placeholder', () {
    final cache = ParagraphCache();
    final painter = ScenePainter(paragraphs: cache);
    final scene = sceneWithEveryBatch();

    final first = painter.record(scene);
    expect(cache.misses, 2);
    expect(cache.hits, 0);
    first.dispose();

    final second = painter.record(scene);
    expect(cache.hits, 2);
    expect(cache.length, 2);
    second.dispose();
  });
}
