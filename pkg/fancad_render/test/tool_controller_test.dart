import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
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

  test('a window drag can rebuild a selection after erase', () {
    final session = sessionWithLine();
    final controller = controllerFor(session);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    session.edit('Erase', (transaction) {
      transaction.eraseAll(session.selection.ids.toList());
    });
    session.selection.clear();
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

  test('the overlay ray is omitted unless the cursor is on an axis', () {
    const view = CadViewport(
      center: Vec2.zero(),
      scale: 1,
      size: Size(800, 600),
    );
    final controller = ToolController(
      session: DocumentSession(id: 't', document: CadDocument()),
      viewportProvider: () => view,
      snapEngine: SnapEngine(
        modes: {},
        tracking: const TrackingSettings(polar: true),
      ),
    );
    addTearDown(controller.dispose);
    controller.push(
      PointPromptTool(message: 'Specify stretch point:', anchor: Vec2.zero()),
    );

    controller.onPointerMove(
      const Vec2(171, 103),
      const PointerMoveEvent(pointer: 1, position: Offset(171, 103)),
    );
    expect(
      controller.buildOverlay().shapes.whereType<OverlayTrackingLine>(),
      isEmpty,
    );

    controller.onPointerMove(
      const Vec2(200, 5),
      const PointerMoveEvent(pointer: 1, position: Offset(200, 5)),
    );
    final rays = controller
        .buildOverlay()
        .shapes
        .whereType<OverlayTrackingLine>()
        .toList();
    expect(rays, hasLength(1));
    expect(TrackingSettings.isCardinalAngle(rays.single.angle), isTrue);
  });

  test(
    'a leftover pointer drag does not swallow Escape on a point prompt',
    () async {
      final session = DocumentSession(id: 't', document: CadDocument());
      final controller = controllerFor(session);
      // LINE's next prompt is pushed while the first-point button is still
      // down. The leftover drag must not count as a cancellable gesture.
      controller.onPointerDown(
        const Vec2(20, 20),
        down(const Offset(20, 20)),
      );
      final prompt = PointPromptTool(
        message: 'Specify next point:',
        anchor: Vec2.zero(),
      );
      controller.push(prompt);
      controller.onPointerMove(
        const Vec2(40, 20),
        move(const Offset(40, 20)),
      );
      expect(controller.hasCancellableGesture, isFalse);

      expect(controller.handleKey(LogicalKeyboardKey.escape), isTrue);
      await expectLater(prompt.result, throwsA(isA<CommandCancelled>()));
      expect(controller.isPrompting, isFalse);
    },
  );

  test(
    'escape drops a window first corner before it cancels the tool',
    () async {
      final session = DocumentSession(id: 't', document: CadDocument());
      final controller = controllerFor(session);
      final prompt = WindowPromptTool(message: 'Specify first corner:');
      controller.push(prompt);

      controller.onPointerDown(const Vec2(0, 0), down(Offset.zero));
      controller.onPointerUp(const Vec2(0, 0), up(Offset.zero));
      expect(controller.hasCancellableGesture, isTrue);

      controller.onPointerMove(
        const Vec2(8, 4),
        move(const Offset(8, 4)),
      );
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
    final controller = controllerFor(session);

    final prompt = SelectionPromptTool(message: 'Select objects:');
    controller.push(prompt);
    controller.onPointerDown(const Vec2(5, 0), down(Offset.zero));
    expect(
      prompt.buildHighlights(controller),
      contains(session.document.entities.single.id),
    );

    controller.onPointerDown(
      const Vec2(20, 20),
      down(const Offset(20, 20)),
    );
    controller.onPointerMove(
      const Vec2(40, 40),
      move(const Offset(40, 40)),
    );
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
