import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
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
}
