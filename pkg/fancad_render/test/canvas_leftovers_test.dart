import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ViewportController controller;

  setUp(() {
    controller = ViewportController();
  });

  tearDown(() => controller.dispose());

  Future<Offset> pumpCanvas(
    WidgetTester tester, {
    void Function(RenderScene scene)? onSceneBuilt,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: CadDocument(),
            controller: controller,
            onSceneBuilt: onSceneBuilt,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    return tester.getCenter(find.byType(CadCanvas));
  }

  testWidgets('a middle-button drag pans the view', (tester) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.center;

    final pointer = TestPointer(
      1,
      PointerDeviceKind.mouse,
      null,
      kMiddleMouseButton,
    );
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(
      pointer.move(location + const Offset(30, 0)),
    );
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(controller.viewport.center.x, isNot(closeTo(before.x, 1e-9)));
  });

  testWidgets('space plus a left drag pans instead of starting a tool', (
    tester,
  ) async {
    final location = await pumpCanvas(tester);
    final before = controller.viewport.center;

    await simulateKeyDownEvent(LogicalKeyboardKey.space);
    addTearDown(() async {
      if (HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.space,
      )) {
        await simulateKeyUpEvent(LogicalKeyboardKey.space);
      }
    });

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(location));
    await tester.sendEventToBinding(
      pointer.move(location + const Offset(30, 0)),
    );
    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(controller.viewport.center.x, isNot(closeTo(before.x, 1e-9)));
  });

  testWidgets(
    'the first paint reports a scene so the status bar is not empty',
    (tester) async {
      RenderScene? scene;
      await pumpCanvas(tester, onSceneBuilt: (built) => scene = built);
      await tester.pump();
      expect(scene, isNotNull);
      expect(scene!.entityCount, 0);
    },
  );
}
