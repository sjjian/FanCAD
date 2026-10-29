import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Zoom always redraws" is held to a count: a gesture in flight cannot call
/// [SceneBuilder.build] at all. Counting builds is the direct measurement;
/// `onSceneBuilt` fires once per build.
void main() {
  late ViewportController controller;
  late CadDocument document;

  setUp(() {
    controller = ViewportController();
    document = CadDocument();
    for (var i = 0; i < 40; i++) {
      document.addEntity(
        LineEntity(
          id: i,
          start: Vec2(-200, i * 10 - 200),
          end: Vec2(200, i * 10 - 200),
        ),
      );
    }
  });

  tearDown(() => controller.dispose());

  Future<int Function()> pumpCanvas(WidgetTester tester) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: document,
            controller: controller,
            onSceneBuilt: (_) => builds++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    expect(builds, greaterThan(0), reason: 'the first paint has to build');
    return () => builds;
  }

  testWidgets('a zoom in flight replays the recording', (tester) async {
    final builds = await pumpCanvas(tester);
    final before = builds();

    controller.beginInteraction();
    for (var i = 0; i < 8; i++) {
      controller.zoomBy(1.05, const Offset(400, 300));
      await tester.pump();
    }

    // Eight camera changes, no rebuild: the recording is replayed under a
    // scale, so the linework follows the geometry rather than being realigned
    // eight times.
    expect(builds(), before);

    controller.endInteraction();
    await tester.pump();
    expect(builds(), greaterThan(before));
  });

  testWidgets('a wheel spin settles into one rebuild', (tester) async {
    final builds = await pumpCanvas(tester);
    final before = builds();

    // A wheel has no gesture end, so the settle timer stands in for one.
    for (var i = 0; i < 6; i++) {
      controller.zoomBy(1.1, const Offset(400, 300));
      await tester.pump();
    }
    expect(controller.quality, RenderQuality.interactive);
    expect(builds(), before);

    await tester.pump(ViewportController.settleDelay);
    expect(controller.quality, RenderQuality.crisp);
    expect(builds(), before + 1);
  });

  testWidgets('a pan inside the overscan never rebuilds', (tester) async {
    final builds = await pumpCanvas(tester);
    final before = builds();

    controller.beginInteraction();
    for (var i = 0; i < 6; i++) {
      controller.panBy(const Offset(4.7, -2.3));
      await tester.pump();
    }
    controller.endInteraction();
    await tester.pump();

    // A settled pan does not rebuild either: both cameras are locked to whole
    // physical pixels, so replaying the recording displaced by whole pixels is
    // the same image a rebuild would produce.
    expect(builds(), before);
  });

  testWidgets('a pan past the overscan rebuilds once', (tester) async {
    final builds = await pumpCanvas(tester);
    final before = builds();

    controller.beginInteraction();
    controller.panBy(const Offset(-4000, 0));
    await tester.pump();
    controller.endInteraction();
    await tester.pump();

    expect(builds(), greaterThan(before));
  });

  testWidgets('a zoom past the preview window rebuilds mid-gesture', (
    tester,
  ) async {
    final builds = await pumpCanvas(tester);
    final before = builds();

    controller.beginInteraction();
    // Past a factor of four the recording's tessellation and pen widths belong
    // to a scale too far away to stand in, so it is rebuilt even though the
    // gesture is still running.
    controller.zoomBy(6, const Offset(400, 300));
    await tester.pump();
    expect(builds(), greaterThan(before));

    controller.endInteraction();
    await tester.pump();
  });

  testWidgets('a zoom out past the overscan keeps replaying mid-gesture', (
    tester,
  ) async {
    final builds = await pumpCanvas(tester);
    final before = builds();

    controller.beginInteraction();
    // A third of a screen of overscan runs out well before a factor of four.
    // The uncovered strip stays empty until the camera settles; a rebuild here
    // is the stall the gesture is meant to avoid.
    for (var i = 0; i < 6; i++) {
      controller.zoomBy(1 / 1.2, const Offset(400, 300));
      await tester.pump();
    }
    expect(builds(), before);

    controller.endInteraction();
    await tester.pump();
    expect(builds(), greaterThan(before));
  });

  test('the cache refuses a recording built for another document', () {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(400, 300),
    );
    final painter = ScenePainter();
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    final cache = DrawingCache()..store(scene, painter.record(scene), 7);
    addTearDown(cache.dispose);

    expect(cache.placementFor(view, 7, interactive: false), isNotNull);
    expect(cache.placementFor(view, 8, interactive: false), isNull);
  });

  test('a zoom out that outlasts the overscan grace asks for a rebuild', () {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(400, 300),
    );
    final painter = ScenePainter();
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    final cache = DrawingCache()..store(scene, painter.record(scene), 0);
    addTearDown(cache.dispose);

    // A factor of 2.5 out runs past the overscan the scene was built for.
    final out = view.copyWith(scale: 0.4);
    expect(scene.covers(out), isFalse);
    for (var i = 0; i < DrawingCache.overscanGraceFrames; i++) {
      expect(cache.placementFor(out, 0, interactive: true), isNotNull);
    }

    // A gesture that keeps going gets one rebuild rather than a border of
    // blank canvas that keeps growing.
    expect(cache.placementFor(out, 0, interactive: true), isNull);
  });

  test('a settled zoom is refused and an in-flight one inside the window is '
      'not', () {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(400, 300),
    );
    final painter = ScenePainter();
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    final cache = DrawingCache()..store(scene, painter.record(scene), 0);
    addTearDown(cache.dispose);

    final zoomed = view.copyWith(scale: 1.5);
    expect(cache.placementFor(zoomed, 0, interactive: false), isNull);
    expect(cache.placementFor(zoomed, 0, interactive: true), isNotNull);

    final farther = view.copyWith(scale: 8);
    expect(cache.placementFor(farther, 0, interactive: true), isNull);
  });
}
