import 'dart:math' as math;

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

  PointerMoveEvent move(Offset local, {int buttons = 0}) =>
      PointerMoveEvent(pointer: 1, position: local, buttons: buttons);

  PointerUpEvent up(Offset local) =>
      PointerUpEvent(pointer: 1, position: local);

  ({DocumentSession session, int id}) sessionWithLine() {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    return (
      session: DocumentSession(id: 't', document: document),
      id: document.entities.single.id,
    );
  }

  ToolController controllerFor(DocumentSession session, {CadViewport? viewport}) {
    final controller = ToolController(
      session: session,
      viewportProvider: () => viewport ?? view,
    );
    controller.defaultTool = SelectionTool();
    addTearDown(controller.dispose);
    return controller;
  }

  test('delete does not erase a leftover selection', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    expect(env.session.selection.ids, hasLength(1));

    expect(controller.handleKey(LogicalKeyboardKey.delete), isFalse);
    expect(controller.handleKey(LogicalKeyboardKey.backspace), isFalse);
    expect(env.session.document.entityCount, 1);
    expect(env.session.selection.ids, [env.id]);
  });

  test('escape clears a selection instead of leaving it stuck', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    expect(env.session.selection.ids, hasLength(1));

    expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
    expect(env.session.selection.ids, isEmpty);
  });

  test('hovering a line highlights it until it is selected', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);

    controller.onPointerMove(const Vec2(5, 0), move(Offset.zero));
    expect(controller.buildOverlay().highlightedIds, [env.id]);

    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    controller.onPointerMove(const Vec2(5, 0), move(Offset.zero));
    expect(controller.buildOverlay().highlightedIds, isEmpty);
  });

  test('a grip click-move-click stretches the endpoint', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    expect(env.session.selection.ids, [env.id]);

    final tool = controller.activeTool as SelectionTool;
    expect(tool.isEditingGrip, isFalse);
    expect(tool.wantsSnap, isFalse);

    controller.onPointerDown(const Vec2(0, 0), down(Offset.zero));
    expect(tool.isEditingGrip, isTrue);
    expect(tool.wantsSnap, isTrue);
    expect(tool.basePoint, const Vec2(0, 0));
    expect(tool.promptText, 'Specify stretch point:');

    controller.onPointerDown(const Vec2(0, 4), down(Offset.zero));
    expect(tool.isEditingGrip, isFalse);
    final line = env.session.document.entities.single as LineEntity;
    expect(line.start, const Vec2(0, 4));
    expect(line.end, const Vec2(10, 0));
  });

  test('escape during a window drag drops the box', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(20, 20), down(const Offset(20, 20)));
    controller.onPointerMove(const Vec2(40, 40), move(const Offset(40, 40)));
    final tool = controller.activeTool as SelectionTool;
    expect(controller.hasCancellableGesture, isTrue);
    expect(tool.buildPreview(controller), isNotEmpty);

    expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
    expect(controller.hasCancellableGesture, isFalse);
    expect(tool.buildPreview(controller), isEmpty);
  });

  test('escape during a grip drag restores the original geometry', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    controller.onPointerDown(const Vec2(0, 0), down(Offset.zero));
    expect((controller.activeTool as SelectionTool).isEditingGrip, isTrue);

    controller.onPointerMove(const Vec2(0, 4), move(const Offset(0, 20)));
    controller.handleKey(LogicalKeyboardKey.escape);

    expect((controller.activeTool as SelectionTool).isEditingGrip, isFalse);
    final line = env.session.document.entities.single as LineEntity;
    expect(line.start, const Vec2.zero());
    expect(line.end, const Vec2(10, 0));
    expect(env.session.selection.ids, [env.id]);
  });

  test('a locked angle keeps a grip target on the ray', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    controller.onPointerDown(const Vec2(0, 0), down(Offset.zero));
    expect((controller.activeTool as SelectionTool).isEditingGrip, isTrue);
    expect(controller.showDynamicInput, isTrue);

    controller.dynamicInput.lockedAngle = 0;
    controller.onPointerMove(const Vec2(4, 6), move(const Offset(4, 6)));
    controller.onPointerDown(const Vec2(4, 6), down(const Offset(4, 6)));

    final line = env.session.document.entities.single as LineEntity;
    expect(line.start.y, closeTo(0, 1e-9));
    expect(line.start.x, closeTo(math.sqrt(16 + 36), 1e-9));
    expect(line.end, const Vec2(10, 0));
  });

  test('escape on an unmoved grip click clears the selection', () {
    final env = sessionWithLine();
    final controller = controllerFor(env.session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    controller.onPointerDown(const Vec2(0, 0), down(Offset.zero));
    expect((controller.activeTool as SelectionTool).isEditingGrip, isTrue);
    expect(controller.hasCancellableGesture, isFalse);

    expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
    expect(env.session.selection.ids, isEmpty);
  });

  test(
    'an enclosing window misses a line that only a crossing window can take',
    () {
      final document = CadDocument();
      document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(20, 0)),
      );
      final session = DocumentSession(id: 't', document: document);
      final controller = controllerFor(session);

      controller.onPointerDown(const Vec2(5, -5), down(Offset.zero));
      controller.onPointerMove(
        const Vec2(15, 5),
        move(const Offset(20, 20), buttons: kPrimaryMouseButton),
      );
      controller.onPointerUp(const Vec2(15, 5), up(const Offset(20, 20)));
      expect(session.selection.ids, isEmpty);

      controller.onPointerDown(const Vec2(15, 5), down(Offset.zero));
      controller.onPointerMove(
        const Vec2(5, -5),
        move(const Offset(20, 20), buttons: kPrimaryMouseButton),
      );
      controller.onPointerUp(const Vec2(5, -5), up(const Offset(20, 20)));
      expect(session.selection.ids, [document.entities.single.id]);
    },
  );

  test(
    'shift-click adds a second line and a shift-miss cannot clear it',
    () async {
      final document = CadDocument();
      document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      document.addEntity(
        const LineEntity(id: 0, start: Vec2(0, 10), end: Vec2(10, 10)),
      );
      final ids = document.entities.map((entity) => entity.id).toList();
      final session = DocumentSession(id: 't', document: document);
      final controller = controllerFor(session);

      controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
      expect(session.selection.ids, [ids[0]]);

      await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      addTearDown(() async {
        if (HardwareKeyboard.instance.isShiftPressed) {
          await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
      });

      controller.onPointerDown(const Vec2(5, 10), down(Offset.zero));
      expect(session.selection.ids, unorderedEquals(ids));

      controller.onPointerDown(const Vec2(80, 80), down(Offset.zero));
      expect(session.selection.ids, unorderedEquals(ids));
    },
  );

  test(
    'a paper viewport frame pick selects the window, not the model line',
    () {
      final document = CadDocument();
      document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(80, 0)),
      );
      document.addLayout(
        const Layout(
          name: 'Layout1',
          blockName: '*Paper_Space',
          tabOrder: 1,
          viewports: [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2(40, 0),
              scale: 1,
            ),
          ],
        ),
      );
      document.setActiveLayout('Layout1');
      final session = DocumentSession(id: 't', document: document);
      final controller = controllerFor(
        session,
        viewport: const CadViewport(
          center: Vec2(105, 80),
          scale: 1,
          size: Size(800, 600),
        ),
      );

      controller.onPointerDown(const Vec2(10, 80), down(Offset.zero));
      expect(session.selection.viewportIndices, {0});
      expect(session.selection.ids, isEmpty);
    },
  );
}
