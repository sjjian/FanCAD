import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(800, 600);

  group('CadViewport', () {
    test('the Y axis points up in drawing space', () {
      const view = CadViewport(center: Vec2.zero(), scale: 1, size: size);
      // Moving up in the drawing moves up the screen, which means a smaller
      // screen Y. Getting this backwards is the classic CAD rendering bug.
      expect(view.toScreen(const Vec2(0, 10)).dy, lessThan(300));
      expect(view.toScreen(const Vec2(0, -10)).dy, greaterThan(300));
    });

    test('screen and drawing coordinates round trip', () {
      const view = CadViewport(
        center: Vec2(120, -45),
        scale: 3.75,
        size: size,
      );
      const point = Vec2(133.25, -12.5);
      final back = view.toWorld(view.toScreen(point));
      expect(back.x, closeTo(point.x, 1e-9));
      expect(back.y, closeTo(point.y, 1e-9));
    });

    test('the matrices agree with the point helpers', () {
      const view = CadViewport(
        center: Vec2(5, 7),
        scale: 2.5,
        size: size,
      );
      const point = Vec2(-3, 11);
      final byMatrix = view.worldToScreen.transform(point);
      final byHelper = view.toScreen(point);
      expect(byMatrix.x, closeTo(byHelper.dx, 1e-9));
      expect(byMatrix.y, closeTo(byHelper.dy, 1e-9));

      final inverse = view.screenToWorld.transform(byMatrix);
      expect(inverse.x, closeTo(point.x, 1e-9));
      expect(inverse.y, closeTo(point.y, 1e-9));
    });

    test('zoom keeps the drawing point under the cursor fixed', () {
      const view = CadViewport(
        center: Vec2(10, 10),
        scale: 4,
        size: size,
      );
      const anchor = Offset(200, 150);
      final before = view.toWorld(anchor);
      final zoomed = view.zoomed(2.5, anchor);
      final after = zoomed.toWorld(anchor);
      expect(after.x, closeTo(before.x, 1e-9));
      expect(after.y, closeTo(before.y, 1e-9));
      expect(zoomed.scale, closeTo(10, 1e-12));
    });

    test('zoom is clamped to a usable range', () {
      const view = CadViewport(center: Vec2.zero(), scale: 1, size: size);
      expect(view.copyWith(scale: 1e30).scale, CadViewport.maxScale);
      expect(view.copyWith(scale: 1e-30).scale, CadViewport.minScale);
    });

    test('fit frames the bounds with a margin', () {
      const bounds = Bounds2(0, 0, 400, 200);
      final view = CadViewport.fit(bounds, size);
      expect(view.center.x, closeTo(200, 1e-9));
      expect(view.center.y, closeTo(100, 1e-9));
      expect(view.visibleBounds.containsBox(bounds), isTrue);
    });

    test('fit survives a zero-extent drawing', () {
      final view = CadViewport.fit(const Bounds2(5, 5, 5, 5), size);
      expect(view.scale.isFinite, isTrue);
      expect(view.scale, greaterThan(0));
    });

    test('a pan moves the centre against the drag direction', () {
      const view = CadViewport(center: Vec2.zero(), scale: 2, size: size);
      // Dragging the paper right moves the camera left.
      final panned = view.panned(const Offset(20, 0));
      expect(panned.center.x, closeTo(-10, 1e-12));
    });

    test('tolerance shrinks as the zoom grows', () {
      const near = CadViewport(center: Vec2.zero(), scale: 100, size: size);
      const far = CadViewport(center: Vec2.zero(), scale: 1, size: size);
      expect(near.tolerance, lessThan(far.tolerance));
      // Half a device pixel at the current scale.
      expect(near.tolerance, closeTo(0.005, 1e-12));
    });
  });

  group('ViewportController', () {
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
  });

  group('trackpadPinchFactor', () {
    test('a missing or zero interval stays 1:1', () {
      expect(trackpadPinchFactor(1.4, null), 1.4);
      expect(trackpadPinchFactor(1.4, Duration.zero), 1.4);
      expect(trackpadPinchFactor(1, const Duration(milliseconds: 8)), 1);
      expect(trackpadPinchFactor(0, const Duration(milliseconds: 8)), 1);
    });

    test('the same ratio covers more when the pinch is faster', () {
      const raw = 1.02;
      final slow = trackpadPinchFactor(raw, const Duration(milliseconds: 80));
      final fast = trackpadPinchFactor(raw, const Duration(milliseconds: 8));
      expect(slow, closeTo(raw, 1e-9));
      expect(fast, greaterThan(slow));
    });

    test('a fast pinch out also travels further', () {
      const raw = 0.98;
      final slow = trackpadPinchFactor(raw, const Duration(milliseconds: 80));
      final fast = trackpadPinchFactor(raw, const Duration(milliseconds: 8));
      expect(slow, closeTo(raw, 1e-9));
      expect(fast, lessThan(slow));
    });
  });
}
