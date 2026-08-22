import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const view = CadViewport(
    center: Vec2(5, 0),
    scale: 1,
    size: Size(800, 600),
  );

  PointerDownEvent down(Offset local, {int buttons = kPrimaryMouseButton}) =>
      PointerDownEvent(pointer: 1, position: local, buttons: buttons);

  PointerMoveEvent move(Offset local) =>
      PointerMoveEvent(pointer: 1, position: local, buttons: kPrimaryMouseButton);

  PointerUpEvent up(Offset local) =>
      PointerUpEvent(pointer: 1, position: local);

  DocumentSession sessionWithLine() {
    final document = CadDocument();
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    return DocumentSession(id: 't', document: document);
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

  test('a click selects a line and a miss clears it', () {
    final session = sessionWithLine();
    final controller = controllerFor(session);
    expect(controller.activeTool, isA<SelectionTool>());
    expect(controller.isPrompting, isFalse);

    expect(
      controller.onPointerDown(const Vec2(5, 0), down(Offset.zero)),
      isTrue,
    );
    expect(session.selection.ids, hasLength(1));
    expect(controller.buildOverlay().selectedIds, hasLength(1));

    controller.onPointerDown(const Vec2(80, 80), down(const Offset(10, 10)));
    expect(session.selection.ids, isEmpty);
  });

  test('delete erases the selection and a window drag can rebuild it', () {
    final session = sessionWithLine();
    final controller = controllerFor(session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    expect(controller.handleKey(LogicalKeyboardKey.delete), isTrue);
    expect(session.document.entityCount, 0);
    expect(session.selection.ids, isEmpty);

    session.edit('add', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    });
    controller.onPointerDown(const Vec2(-2, -2), down(Offset.zero));
    controller.onPointerMove(const Vec2(12, 3), move(const Offset(20, 0)));
    controller.onPointerUp(const Vec2(12, 3), up(const Offset(20, 0)));
    expect(session.selection.ids, hasLength(1));
  });

  test('a point prompt returns to select and the middle button is ignored', () async {
    final session = DocumentSession(id: 't', document: CadDocument());
    final controller = controllerFor(session);
    final prompt = PointPromptTool(message: 'From point:');
    controller.push(prompt);
    expect(controller.isPrompting, isTrue);
    expect(controller.activeTool, prompt);

    expect(
      controller.onPointerDown(
        const Vec2(3, 1),
        down(Offset.zero, buttons: kMiddleMouseButton),
      ),
      isFalse,
    );
    expect(prompt.isComplete, isFalse);

    expect(
      controller.onPointerDown(const Vec2(3, 1), down(Offset.zero)),
      isTrue,
    );
    expect(await prompt.result, const Vec2(3, 1));
    expect(controller.isPrompting, isFalse);
    expect(controller.activeTool, isA<SelectionTool>());
  });
}
