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
}
