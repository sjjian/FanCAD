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

  PointerMoveEvent move(Offset local) => PointerMoveEvent(
    pointer: 1,
    position: local,
    buttons: kPrimaryMouseButton,
  );

  PointerUpEvent up(Offset local) =>
      PointerUpEvent(pointer: 1, position: local);

  ToolController controllerFor(
    DocumentSession session, {
    CadViewport? viewport,
  }) {
    final controller = ToolController(
      session: session,
      viewportProvider: () => viewport ?? view,
    );
    controller.defaultTool = SelectionTool();
    addTearDown(controller.dispose);
    return controller;
  }

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
      controller.onPointerMove(const Vec2(15, 5), move(const Offset(20, 20)));
      controller.onPointerUp(const Vec2(15, 5), up(const Offset(20, 20)));
      expect(session.selection.ids, isEmpty);

      controller.onPointerDown(const Vec2(15, 5), down(Offset.zero));
      controller.onPointerMove(const Vec2(5, -5), move(const Offset(20, 20)));
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
