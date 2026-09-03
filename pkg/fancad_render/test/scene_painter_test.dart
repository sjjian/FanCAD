import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter_test/flutter_test.dart';

import 'raster.dart';

/// The painter is deliberately dumb, so these tests are about what the whole
/// chain puts on the pixel grid: build, align, paint.
///
/// Scenes therefore come from a document through [SceneBuilder] rather than
/// being assembled by hand. A hand-built scene would skip the aligner, which
/// is where every decision these tests are checking is made.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const view = CadViewport(center: Vec2.zero(), scale: 1, size: Size(200, 200));

  /// A 40 by 40 window centred on the origin, so a drawing coordinate of 0 is
  /// pixel 20 and the arithmetic in each test stays readable.
  CadViewport window({double dpr = 1}) => CadViewport(
    center: const Vec2.zero(),
    scale: 1,
    size: const Size(40, 40),
    devicePixelRatio: dpr,
  );

  RenderScene build(CadDocument document, CadViewport at) =>
      SceneBuilder(palette: AciPalette.dark).build(document, at);

  /// Horizontal hairlines at the given drawing heights, spanning the window.
  CadDocument rules(List<double> heights, {int color = 3}) {
    final document = CadDocument();
    for (var i = 0; i < heights.length; i++) {
      document.addEntity(
        LineEntity(
          id: i,
          props: EntityProps(color: CadColor.indexed(color)),
          start: Vec2(-16, heights[i]),
          end: Vec2(16, heights[i]),
        ),
      );
    }
    return document;
  }

  RenderScene sceneWithEveryBatch() {
    final lines = LineBatch(const BatchKey(Color(0xFFFFFFFF), 1))
      ..vertices.add4(0, 0, 10, 0);
    final points = PointBatch(const BatchKey(Color(0xFFFF0000), 3))
      ..vertices.add2(5, 5);
    final fills = FillBatch(const BatchKey(Color(0xFF00FF00), 0))
      ..addRing(Float32List.fromList([0, 0, 10, 0, 10, 10, 0, 10]));
    return RenderScene.single(
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

  test('a hairline ACI 7 is one solid row on a dark canvas', () async {
    final scene = build(rules([0], color: 7), window());
    final raster = await rasterise(scene);

    // Drawing height 0 is pixel 20.0, which the aligner moves to the centre of
    // pixel 20 so the pen covers that row and nothing else.
    expect(raster.litRows(Channel.red), [20]);
    expect(
      raster.peakInRow(20, Channel.red, from: 10, to: 30),
      greaterThan(solidCore),
    );
  });

  test('a vertical hairline is one solid column of ACI 3', () async {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(0, -16),
          end: Vec2(0, 16),
        ),
      );
    final raster = await rasterise(build(document, window()));

    expect(raster.litColumns(Channel.green), [20]);
    expect(
      raster.peakInColumn(20, Channel.green, from: 10, to: 30),
      greaterThan(solidCore),
    );
  });

  test('a shallow hairline is not aligned into a staircase', () async {
    // A 0.6 px rise over 32 px. Rounding the ends onto a pixel centre would
    // turn a smear into a visible step, so a run this far off the axis is left
    // exactly where the projection put it.
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(-16, 9.8),
          end: Vec2(16, 9.2),
        ),
      );
    final raster = await rasterise(build(document, window()));

    expect(raster.litRows(Channel.green).length, lessThan(4));
  });

  test('a one-pixel gap between hairlines stays two rows', () async {
    // 1.0 px apart: the two pens land in adjacent pixels whatever the phase,
    // so there is nothing ambiguous to resolve and both rows survive.
    final raster = await rasterise(build(rules([0.5, -0.5]), window()));

    expect(raster.litRows(Channel.green), hasLength(2));
  });

  test('parallels closer than the pen is wide collapse onto one row', () async {
    // 0.54 px apart. At this zoom the gap is narrower than the thinnest line
    // the display can draw, so the honest answer is one row. Keeping two would
    // mean their appearance depended on where the pair fell on the grid, which
    // is the blink.
    final raster = await rasterise(build(rules([0.27, -0.27]), window()));

    expect(raster.litRows(Channel.green), hasLength(1));
    expect(
      raster.peakInRow(
        raster.litRows(Channel.green).single,
        Channel.green,
        from: 10,
        to: 30,
      ),
      greaterThan(solidCore),
    );
  });

  test('a sub-pixel pair straddling a pixel edge is still one row', () async {
    // Pixels 19.6 and 20.4: floor() puts them in different pixels even though
    // they are 0.8 px apart. Deciding by the gap rather than by which pixel
    // each one happens to land in is what keeps this stable under a pan.
    final raster = await rasterise(build(rules([0.4, -0.4]), window()));

    expect(raster.litRows(Channel.green), hasLength(1));
  });

  test('a replayed pan keeps a hairline solid', () async {
    // A pan replays the recording displaced by whole physical pixels, so the
    // alignment baked into it still lands on pixel centres. Displacing it by a
    // fraction is what forced the picture cache to be deleted before, so this
    // goes through [DrawingCache] rather than translating a canvas by hand.
    final from = window();
    final scene = build(rules([0]), from);
    final cache = DrawingCache()
      ..store(scene, ScenePainter().record(scene), 0);
    addTearDown(cache.dispose);

    final to = from.panned(const Offset(0, -2)).pixelLocked();
    final placement = cache.placementFor(to, 0, interactive: false);
    expect(placement, isNotNull);
    expect(placement!.isTranslation, isTrue);
    expect(placement.offset, const Offset(0, -2));

    final raster = await rasterFrom(to, (canvas) {
      cache.replay(canvas, placement, to.devicePixelRatio);
    });

    expect(raster.litRows(Channel.green), [18]);
    expect(
      raster.peakInRow(18, Channel.green, from: 10, to: 30),
      greaterThan(solidCore),
    );
  });

  test('a pan inside the overscan still has the linework that was off screen',
      () async {
    // A vertical hairline sitting in the overscan to the left of a 40 px
    // window. Replaying a pan used to reveal a blank strip there because the
    // recording had been culled to the widget, throwing the extra geometry
    // away even though the batches still held it.
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(-25, -10),
          end: Vec2(-25, 10),
        ),
      );
    final from = window();
    final scene = build(document, from);
    final to = from.panned(const Offset(12, 0)).pixelLocked();
    expect(scene.covers(to), isTrue);

    final cache = DrawingCache()
      ..store(scene, ScenePainter().record(scene), 0);
    addTearDown(cache.dispose);

    final placement = cache.placementFor(to, 0, interactive: false);
    expect(placement, isNotNull);
    final raster = await rasterFrom(to, (canvas) {
      cache.replay(canvas, placement!, to.devicePixelRatio);
    });

    expect(raster.litColumns(Channel.green), isNotEmpty);
    expect(
      raster.peakInColumn(
        raster.litColumns(Channel.green).single,
        Channel.green,
        from: 10,
        to: 30,
      ),
      greaterThan(solidCore),
    );
  });

  test('a hairline at device ratio 2 occupies one physical pixel', () async {
    final document = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(color: CadColor.indexed(3)),
          start: Vec2(0, -16),
          end: Vec2(0, 16),
        ),
      );
    final raster = await rasterise(build(document, window(dpr: 2)));

    expect(raster.width, 80);
    // Drawing coordinate 0 is physical pixel 40. One pixel, not the two a
    // logical-pixel hairline covers on a Retina display.
    expect(raster.litColumns(Channel.green), [40]);
    expect(
      raster.peakInColumn(40, Channel.green, from: 20, to: 60),
      greaterThan(solidCore),
    );
    expect(
      raster.peakInColumn(39, Channel.green, from: 20, to: 60),
      lessThan(litThreshold),
    );
    expect(
      raster.peakInColumn(41, Channel.green, from: 20, to: 60),
      lessThan(litThreshold),
    );
  });
}
