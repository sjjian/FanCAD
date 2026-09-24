import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(800, 600);

  test(
    'interaction and a same-size layout do not invent extra notifications',
    () {
      final controller = ViewportController();
      addTearDown(controller.dispose);
      var ticks = 0;
      controller.addListener(() => ticks++);

      controller.setSize(size, 1);
      expect(ticks, 1);
      controller.setSize(size, 1);
      expect(ticks, 1);

      controller.beginInteraction();
      expect(controller.isInteracting, isTrue);
      expect(ticks, 2);
      controller.beginInteraction();
      expect(ticks, 2);
      controller.endInteraction();
      expect(controller.isInteracting, isFalse);
      expect(ticks, 3);
      controller.endInteraction();
      expect(ticks, 3);
    },
  );

  test('revertInteraction puts the camera back and ends the gesture', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(size, 1);
    final origin = controller.viewport;

    controller.beginInteraction();
    controller.panBy(const Offset(40, 0));
    expect(controller.viewport.center, isNot(origin.center));

    expect(controller.revertInteraction(), isTrue);
    expect(controller.isInteracting, isFalse);
    expect(controller.viewport.center.x, closeTo(origin.center.x, 1e-12));
    expect(controller.viewport.center.y, closeTo(origin.center.y, 1e-12));

    expect(controller.revertInteraction(), isFalse);
    expect(controller.viewport.center.x, closeTo(origin.center.x, 1e-12));
  });

  test('a two-finger rest that never moved does not count as a revert', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(size, 1);
    controller.beginInteraction();
    expect(controller.revertInteraction(), isFalse);
    expect(controller.isInteracting, isFalse);
  });

  test('zoom buttons and centerOn move the camera without a pending fit', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(size, 1);
    final start = controller.viewport.scale;

    controller.zoomIn();
    expect(controller.viewport.scale, closeTo(start * 1.25, 1e-12));
    controller.zoomOut();
    expect(controller.viewport.scale, closeTo(start, 1e-9));

    controller.zoomBy(2, const Offset(400, 300));
    expect(controller.viewport.scale, closeTo(start * 2, 1e-12));

    controller.centerOn(const Vec2(12, -3));
    expect(controller.viewport.center, const Vec2(12, -3));

    final before = controller.viewport;
    controller.zoomTo(const Bounds2.empty());
    expect(controller.viewport, before);
  });

  test('a zoom held against the scale limit leaves the camera settled', () {
    // The camera does not move, so there is nothing to smooth and nothing to
    // repaint. Marking the view as moving anyway would put the renderer on the
    // cached recording with no notification to say so, and it would sit there
    // until the settle timer happened to fire.
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(size, 1);
    controller.viewport = controller.viewport.copyWith(
      scale: CadViewport.maxScale,
    );
    expect(controller.quality, RenderQuality.crisp);

    var ticks = 0;
    controller.addListener(() => ticks++);
    final pinned = controller.viewport;

    controller.zoomBy(4, const Offset(400, 300));

    expect(controller.viewport, pinned);
    expect(controller.quality, RenderQuality.crisp);
    expect(ticks, 0);
  });

  test('a fit requested before layout is applied once a size arrives', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);

    controller.zoomTo(const Bounds2(0, 0, 100, 50));
    // No size yet, so nothing could have been computed.
    expect(controller.viewport.size, Size.zero);

    controller.setSize(size, 2);
    expect(controller.viewport.center.x, closeTo(50, 1e-9));
    expect(controller.viewport.center.y, closeTo(25, 1e-9));
    expect(controller.viewport.devicePixelRatio, 2);
  });

  test('an empty drawing still gets a usable scale', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(size, 1);
    controller.zoomToExtents(CadDocument());
    expect(controller.viewport.scale, greaterThan(0));
    expect(controller.viewport.visibleBounds.isNotEmpty, isTrue);
  });

  test('zoom extents fits the uncovered interval, not the covered strips', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(const Size(800, 600), 1);
    const bounds = Bounds2(0, 0, 400, 200);

    controller.zoomTo(bounds, insetLeft: 200, insetRight: 0);

    final view = controller.viewport;
    expect(view.size, const Size(800, 600));
    final hole = view.visibleThrough(left: 200);
    expect(hole.containsBox(bounds), isTrue);
    expect(view.visibleBounds.containsBox(bounds), isTrue);
    // The drawing sits in the open interval, so its centre is right of the
    // widget centre.
    expect(view.toScreen(bounds.center).dx, closeTo(200 + 600 / 2, 1));
  });

  test('a resize without a screen origin keeps the centre', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    controller.setSize(size, 1);
    final center = controller.viewport.center;

    controller.setSize(const Size(640, 600), 1);

    expect(controller.viewport.center.x, closeTo(center.x, 1e-9));
    expect(controller.viewport.center.y, closeTo(center.y, 1e-9));
    expect(controller.quality, RenderQuality.crisp);
  });

  test(
    'dragging either edge keeps a drawing point on the same screen pixel',
    () {
      final controller = ViewportController();
      addTearDown(controller.dispose);
      controller.setSize(size, 1, screenOrigin: Offset.zero);
      const world = Vec2(30, -12);
      final screen = controller.viewport.toScreen(world);

      // Left splitter: the canvas origin moves right and the width shrinks.
      const leftOrigin = Offset(40, 0);
      controller.setSize(const Size(760, 600), 1, screenOrigin: leftOrigin);
      final afterLeft = leftOrigin + controller.viewport.toScreen(world);
      expect(afterLeft.dx, closeTo(screen.dx, 1e-6));
      expect(afterLeft.dy, closeTo(screen.dy, 1e-6));

      // Right splitter: the origin stays, the width shrinks from the right.
      final rightScreen = afterLeft;
      controller.setSize(const Size(700, 600), 1, screenOrigin: leftOrigin);
      final afterRight = leftOrigin + controller.viewport.toScreen(world);
      expect(afterRight.dx, closeTo(rightScreen.dx, 1e-6));
      expect(afterRight.dy, closeTo(rightScreen.dy, 1e-6));
      expect(controller.quality, RenderQuality.interactive);
    },
  );

  test('notifies once per change', () {
    final controller = ViewportController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setSize(size, 1);
    controller.panBy(const Offset(10, 10));
    controller.panBy(Offset.zero);
    expect(notifications, 2);
  });
}
