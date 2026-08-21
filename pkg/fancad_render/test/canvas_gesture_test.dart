import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
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
  });

  testWidgets('a trackpad pinch zooms about the cursor', (tester) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.scale;

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(location));
    await tester.sendEventToBinding(pointer.panZoomUpdate(location, scale: 2));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(controller.viewport.scale, closeTo(before * 2, 1e-9));
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
}
