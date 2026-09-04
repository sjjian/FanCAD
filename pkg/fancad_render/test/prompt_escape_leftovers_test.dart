import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const view = CadViewport(center: Vec2(5, 0), scale: 1, size: Size(800, 600));

  PointerDownEvent down(Offset local) => PointerDownEvent(
    pointer: 1,
    position: local,
    buttons: kPrimaryMouseButton,
  );

  PointerMoveEvent move(Offset local) => PointerMoveEvent(
    pointer: 1,
    position: local,
    buttons: kPrimaryMouseButton,
  );

  PointerUpEvent up(Offset local) =>
      PointerUpEvent(pointer: 1, position: local);

  ToolController controllerFor() {
    final controller = ToolController(
      session: DocumentSession(id: 't', document: CadDocument()),
      viewportProvider: () => view,
    );
    controller.defaultTool = SelectionTool();
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'a leftover pointer drag does not swallow Escape on a point prompt',
    () async {
      final controller = controllerFor();
      // LINE's next prompt is pushed while the first-point button is still
      // down. The leftover drag must not count as a cancellable gesture.
      controller.onPointerDown(const Vec2(20, 20), down(const Offset(20, 20)));
      final prompt = PointPromptTool(
        message: 'Specify next point:',
        anchor: Vec2.zero(),
      );
      controller.push(prompt);
      controller.onPointerMove(const Vec2(40, 20), move(const Offset(40, 20)));
      expect(controller.hasCancellableGesture, isFalse);

      expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
      await expectLater(prompt.result, throwsA(isA<CommandCancelled>()));
      expect(controller.isPrompting, isFalse);
    },
  );

  test(
    'escape drops a window first corner before it cancels the tool',
    () async {
      final controller = controllerFor();
      final prompt = WindowPromptTool(message: 'Specify first corner:');
      controller.push(prompt);

      controller.onPointerDown(const Vec2(0, 0), down(Offset.zero));
      controller.onPointerUp(const Vec2(0, 0), up(Offset.zero));
      expect(controller.hasCancellableGesture, isTrue);

      controller.onPointerMove(const Vec2(8, 4), move(const Offset(8, 4)));
      expect(prompt.buildPreview(controller), isNotEmpty);

      expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
      expect(controller.hasCancellableGesture, isFalse);
      expect(prompt.buildPreview(controller), isEmpty);
      expect(controller.isPrompting, isTrue);

      expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
      await expectLater(prompt.result, throwsA(isA<CommandCancelled>()));
      expect(controller.isPrompting, isFalse);
    },
  );

  test('escape drops a selection-prompt window and keeps the picks', () async {
    final session = DocumentSession(id: 't', document: CadDocument());
    session.document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    final controller = ToolController(
      session: session,
      viewportProvider: () => view,
    );
    controller.defaultTool = SelectionTool();
    addTearDown(controller.dispose);

    final prompt = SelectionPromptTool(message: 'Select objects:');
    controller.push(prompt);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    expect(
      prompt.buildHighlights(controller),
      contains(session.document.entities.single.id),
    );

    controller.onPointerDown(const Vec2(20, 20), down(const Offset(20, 20)));
    controller.onPointerMove(const Vec2(40, 40), move(const Offset(40, 40)));
    expect(controller.hasCancellableGesture, isTrue);
    expect(prompt.buildPreview(controller), isNotEmpty);

    expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
    expect(controller.hasCancellableGesture, isFalse);
    expect(prompt.buildPreview(controller), isEmpty);
    expect(controller.isPrompting, isTrue);
    expect(
      prompt.buildHighlights(controller),
      contains(session.document.entities.single.id),
    );
  });
}
