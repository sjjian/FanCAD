import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ViewportController controller;

  setUp(() {
    controller = ViewportController();
  });

  tearDown(() => controller.dispose());

  Future<Offset> pumpCanvas(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(document: CadDocument(), controller: controller),
        ),
      ),
    );
    // Size is applied on the next frame.
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    return tester.getCenter(find.byType(CadCanvas));
  }

  testWidgets('a mouse-wheel notch zooms about the cursor', (tester) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.scale;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();

    expect(controller.viewport.scale, greaterThan(before));

    // A notch has no gesture end, so the camera counts as moving until the
    // settle timer fires and asks for a crisp rebuild.
    expect(controller.quality, RenderQuality.interactive);
    await tester.pump(ViewportController.settleDelay);
    expect(controller.quality, RenderQuality.crisp);
  });

  testWidgets('a trackpad pinch zooms about the cursor', (tester) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.scale;

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(location));
    await tester.sendEventToBinding(pointer.panZoomUpdate(location, scale: 2));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    // The first sample has no dt, so the raw scale is applied 1:1.
    expect(controller.viewport.scale, closeTo(before * 2, 1e-9));
  });

  testWidgets('a fast trackpad pinch covers more than the raw scale', (
    tester,
  ) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.scale;

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(location));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(
        location,
        scale: 1.1,
        timeStamp: const Duration(milliseconds: 16),
      ),
    );
    await tester.pump();
    expect(controller.viewport.scale, closeTo(before * 1.1, 1e-9));
    final afterFirst = controller.viewport.scale;

    await tester.sendEventToBinding(
      pointer.panZoomUpdate(
        location,
        scale: 1.4,
        timeStamp: const Duration(milliseconds: 24),
      ),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    const raw = 1.4 / 1.1;
    expect(
      controller.viewport.scale,
      closeTo(
        afterFirst * trackpadPinchFactor(raw, const Duration(milliseconds: 8)),
        1e-6,
      ),
    );
    expect(controller.viewport.scale, greaterThan(afterFirst * raw));
  });

  testWidgets('a two-finger trackpad drag pans the view', (tester) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.center;

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(location));
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(location, pan: const Offset(40, 0)),
    );
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(controller.viewport.center.x, isNot(closeTo(before.x, 1e-9)));
    expect(controller.viewport.scale, closeTo(1, 1e-9));
  });

  testWidgets('a primary double-click reports the gesture', (tester) async {
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: CadDocument(),
            controller: controller,
            onDoubleClick: (_) => clicks++,
          ),
        ),
      ),
    );
    await tester.pump();
    final location = tester.getCenter(find.byType(CadCanvas));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(pointer.up());
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();
    expect(clicks, 1);
  });

  testWidgets('a right-click without a drag opens the context menu', (
    tester,
  ) async {
    Offset? menuAt;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: CadDocument(),
            controller: controller,
            onContextMenu: (at) => menuAt = at,
          ),
        ),
      ),
    );
    await tester.pump();
    final location = tester.getCenter(find.byType(CadCanvas));
    final before = controller.viewport.center;

    final pointer = TestPointer(
      1,
      PointerDeviceKind.mouse,
      null,
      kSecondaryMouseButton,
    );
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(menuAt, isNotNull);
    expect(controller.viewport.center.x, closeTo(before.x, 1e-9));
  });

  testWidgets('a right-button drag pans the view', (tester) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.center;

    final pointer = TestPointer(
      1,
      PointerDeviceKind.mouse,
      null,
      kSecondaryMouseButton,
    );
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(
      pointer.move(location + const Offset(30, 0)),
    );
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(controller.viewport.center.x, isNot(closeTo(before.x, 1e-9)));
  });

  testWidgets('revertInteraction restores the camera and stops a live pan', (
    tester,
  ) async {
    final location = await pumpCanvas(tester);
    final origin = controller.viewport.center;

    final pointer = TestPointer(
      1,
      PointerDeviceKind.mouse,
      null,
      kSecondaryMouseButton,
    );
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(
      pointer.move(location + const Offset(30, 0)),
    );
    await tester.pump();
    expect(controller.isInteracting, isTrue);
    expect(controller.viewport.center.x, isNot(closeTo(origin.x, 1e-9)));

    controller.revertInteraction();
    await tester.pump();
    expect(controller.isInteracting, isFalse);
    expect(controller.viewport.center.x, closeTo(origin.x, 1e-9));

    await tester.sendEventToBinding(
      pointer.move(location + const Offset(80, 0)),
    );
    await tester.pump();
    expect(controller.viewport.center.x, closeTo(origin.x, 1e-9));
    await tester.sendEventToBinding(pointer.up());
  });
}
