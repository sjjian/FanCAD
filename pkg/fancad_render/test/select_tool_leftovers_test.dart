import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
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

  PointerMoveEvent move(Offset local) =>
      PointerMoveEvent(pointer: 1, position: local);

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

  ToolController controllerFor(DocumentSession session) {
    final controller = ToolController(
      session: session,
      viewportProvider: () => view,
    );
    controller.defaultTool = SelectionTool();
    addTearDown(controller.dispose);
    return controller;
  }

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
}
