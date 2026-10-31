import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
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
    // Size is applied on the next frame.
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    return tester.getCenter(find.byType(CadCanvas));
  }

  testWidgets('a mouse-wheel notch zooms about the cursor', (tester) async {
    var builds = 0;
    final location = await pumpCanvas(tester, onSceneBuilt: (_) => builds++);
    final before = controller.viewport.scale;
    final firstFrameBuilds = builds;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();

    expect(controller.viewport.scale, greaterThan(before));

    // A notch has no gesture end, so the renderer keeps replaying the
    // recording until its own settle timer decides the camera has stopped.
    expect(builds, firstFrameBuilds);
    await tester.pump(CanvasRenderer.settleDelay);
    expect(builds, greaterThan(firstFrameBuilds));
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

  testWidgets(
    'a prompt click is delivered even when it looks like a double-click',
    (tester) async {
      final handler = _PromptingHandler();
      var doubleClicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: CadCanvas(
              document: CadDocument(),
              controller: controller,
              inputHandler: handler,
              onDoubleClick: (_) => doubleClicks++,
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
      expect(doubleClicks, 0);
      expect(handler.downs, 2);
    },
  );

  testWidgets('starting a prompt replays the last hover, not the view centre', (
    tester,
  ) async {
    final handler = _ReplayHandler();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: CadDocument(),
            controller: controller,
            inputHandler: handler,
          ),
        ),
      ),
    );
    await tester.pump();
    final location = tester.getCenter(find.byType(CadCanvas));
    final hoverAt = location + const Offset(80, -40);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(hoverAt));
    await tester.pump();
    expect(handler.moves, isNotEmpty);
    final expected = handler.moves.last;
    handler.moves.clear();
    handler.prompting = true;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: CadDocument(),
            controller: controller,
            inputHandler: handler,
            overlay: const OverlayModel(cursor: Vec2.zero()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(handler.moves, isNotEmpty);
    expect(handler.moves.last.x, closeTo(expected.x, 1e-6));
    expect(handler.moves.last.y, closeTo(expected.y, 1e-6));
    expect(
      handler.moves.last.x,
      isNot(closeTo(controller.viewport.center.x, 1)),
    );
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

  testWidgets('toggling the leftover grid rebuilds without a resize', (
    tester,
  ) async {
    final document = CadDocument();
    Widget canvas({required bool showGrid}) => MaterialApp(
      home: SizedBox(
        width: 800,
        height: 600,
        child: CadCanvas(
          document: document,
          controller: controller,
          showGrid: showGrid,
        ),
      ),
    );

    CustomPainter drawingPainter() => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(CadCanvas),
            matching: find.byType(CustomPaint),
          ),
        )
        .firstWhere((paint) => paint.painter != null)
        .painter!;

    await tester.pumpWidget(canvas(showGrid: true));
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    final before = drawingPainter();

    await tester.pumpWidget(canvas(showGrid: false));
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    expect(drawingPainter().shouldRepaint(before), isTrue);
  });

  testWidgets(
    'a leftover document version rebuilds the scene without a resize',
    (tester) async {
      final document = CadDocument();
      final scenes = <RenderScene>[];
      Widget canvas() => MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: document,
            controller: controller,
            onSceneBuilt: scenes.add,
          ),
        ),
      );

      await tester.pumpWidget(canvas());
      await tester.pump();
      expect(controller.viewport.size, const Size(800, 600));
      expect(scenes, isNotEmpty);
      expect(scenes.last.entityCount, 0);
      final builtBefore = scenes.length;

      final session = DocumentSession(id: 't', document: document);
      addTearDown(session.dispose);
      session.edit('LINE', (txn) {
        txn.add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(40, 0)));
      });

      await tester.pumpWidget(canvas());
      await tester.pump();
      expect(controller.viewport.size, const Size(800, 600));
      expect(scenes.length, greaterThan(builtBefore));
      expect(scenes.last.entityCount, 1);
    },
  );

  testWidgets('a leftover overlay follows the document without a resize', (
    tester,
  ) async {
    final document = CadDocument();
    final session = DocumentSession(id: 't', document: document);
    addTearDown(session.dispose);
    session.edit('LINE', (txn) {
      txn.add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(40, 0)));
    });
    const overlay = OverlayModel(selectedIds: [0]);

    Widget canvas() => MaterialApp(
      home: SizedBox(
        width: 800,
        height: 600,
        child: CadCanvas(
          document: document,
          controller: controller,
          overlay: overlay,
        ),
      ),
    );

    CustomPainter overlayPainter() {
      final paints = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(CadCanvas),
              matching: find.byType(CustomPaint),
            ),
          )
          .where((paint) => paint.painter != null)
          .toList();
      expect(paints, hasLength(2));
      return paints.last.painter!;
    }

    await tester.pumpWidget(canvas());
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    final before = overlayPainter();

    session.edit('LINE', (txn) {
      txn.add(const LineEntity(id: 1, start: Vec2(0, 10), end: Vec2(40, 10)));
    });

    await tester.pumpWidget(canvas());
    await tester.pump();
    expect(controller.viewport.size, const Size(800, 600));
    expect(overlayPainter().shouldRepaint(before), isTrue);
  });

  testWidgets(
    'a leftover palette change rebuilds the drawing without a resize',
    (tester) async {
      final document = CadDocument();
      Widget canvas({required Color background, required AciPalette palette}) =>
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: CadCanvas(
                document: document,
                controller: controller,
                background: background,
                palette: palette,
              ),
            ),
          );

      CustomPainter drawingPainter() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(CadCanvas),
              matching: find.byType(CustomPaint),
            ),
          )
          .firstWhere((paint) => paint.painter != null)
          .painter!;

      await tester.pumpWidget(
        canvas(
          background: AciPalette.dark.background,
          palette: AciPalette.dark,
        ),
      );
      await tester.pump();
      expect(controller.viewport.size, const Size(800, 600));
      final before = drawingPainter();

      await tester.pumpWidget(
        canvas(
          background: AciPalette.light.background,
          palette: AciPalette.light,
        ),
      );
      await tester.pump();
      expect(controller.viewport.size, const Size(800, 600));
      expect(drawingPainter().shouldRepaint(before), isTrue);
    },
  );

  testWidgets(
    'applyDocumentChange rebuilds a leftover scene without a resize',
    (tester) async {
      final scenes = <RenderScene>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: CadCanvas(
              document: CadDocument(),
              controller: controller,
              onSceneBuilt: scenes.add,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.viewport.size, const Size(800, 600));
      expect(scenes, isNotEmpty);
      final builtBefore = scenes.length;

      tester
          .state<CadCanvasState>(find.byType(CadCanvas))
          .applyDocumentChange(const DocumentChange(tablesChanged: true));
      await tester.pump();
      expect(controller.viewport.size, const Size(800, 600));
      expect(scenes.length, greaterThan(builtBefore));
    },
  );

  testWidgets('a version bump without applyDocumentChange drops tessellation', (
    tester,
  ) async {
    final cache = TessellationCache();
    final renderer = CanvasRenderer(tessellation: cache);
    addTearDown(renderer.dispose);
    final document = CadDocument();
    for (var i = 0; i < 12; i++) {
      document.addEntity(
        CircleEntity(id: 0, center: Vec2(i * 20.0, 0), radius: 8),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: document,
            controller: controller,
            renderer: renderer,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(cache.misses, greaterThan(0));
    cache.resetStatistics();

    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: document,
            controller: controller,
            renderer: renderer,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(cache.hits, 0);
    expect(cache.misses, greaterThan(0));
  });

  testWidgets('applyDocumentChange keeps unrelated tessellation', (
    tester,
  ) async {
    final cache = TessellationCache();
    final renderer = CanvasRenderer(tessellation: cache);
    addTearDown(renderer.dispose);
    final document = CadDocument();
    for (var i = 0; i < 12; i++) {
      document.addEntity(
        CircleEntity(id: 0, center: Vec2(i * 20.0, 0), radius: 8),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: document,
            controller: controller,
            renderer: renderer,
          ),
        ),
      ),
    );
    await tester.pump();
    cache.resetStatistics();

    final added = document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    tester
        .state<CadCanvasState>(find.byType(CadCanvas))
        .applyDocumentChange(DocumentChange(added: [added.id]));
    await tester.pump();
    expect(cache.hits, greaterThan(0));
  });

  testWidgets('the drawing is clipped so a stroke cannot cover the chrome', (
    tester,
  ) async {
    await pumpCanvas(tester);
    expect(
      find.descendant(
        of: find.byType(CadCanvas),
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a drawn crosshair hides the system pointer', (tester) async {
    Future<MouseCursor> cursorFor(
      OverlayModel overlay, {
      CanvasInputHandler? handler,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: CadCanvas(
              document: CadDocument(),
              controller: controller,
              overlay: overlay,
              inputHandler: handler,
            ),
          ),
        ),
      );
      await tester.pump();
      return tester
          .widget<MouseRegion>(
            find.descendant(
              of: find.byType(CadCanvas),
              matching: find.byType(MouseRegion),
            ),
          )
          .cursor;
    }

    final tracking = _TrackingHandler();
    expect(
      await cursorFor(
        const OverlayModel(cursor: Vec2.zero()),
        handler: tracking,
      ),
      SystemMouseCursors.none,
    );
    // A handler that does not move the overlay cursor would leave a frozen
    // crosshair with no pointer at all, so the system cursor has to stay.
    expect(
      await cursorFor(
        const OverlayModel(cursor: Vec2.zero()),
        handler: _PromptingHandler(),
      ),
      SystemMouseCursors.precise,
    );
    expect(
      await cursorFor(
        const OverlayModel(cursor: Vec2.zero(), showCrosshair: false),
        handler: tracking,
      ),
      SystemMouseCursors.precise,
    );
    // No pointer yet: nothing was drawn, so the system pointer stays.
    expect(
      await cursorFor(const OverlayModel(), handler: tracking),
      SystemMouseCursors.precise,
    );
  });

  testWidgets('a pan keeps the drawn crosshair, not a hand', (tester) async {
    final handler = _TrackingHandler();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: CadCanvas(
            document: CadDocument(),
            controller: controller,
            overlay: const OverlayModel(cursor: Vec2.zero()),
            inputHandler: handler,
          ),
        ),
      ),
    );
    await tester.pump();
    final location = tester.getCenter(find.byType(CadCanvas));
    MouseCursor cursor() => tester
        .widget<MouseRegion>(
          find.descendant(
            of: find.byType(CadCanvas),
            matching: find.byType(MouseRegion),
          ),
        )
        .cursor;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.pump();
    expect(cursor(), SystemMouseCursors.none);

    final pan = TestPointer(
      2,
      PointerDeviceKind.mouse,
      null,
      kSecondaryMouseButton,
    );
    await tester.sendEventToBinding(pan.down(location));
    await tester.sendEventToBinding(pan.move(location + const Offset(30, 0)));
    await tester.pump();
    expect(controller.viewport.center.x, isNot(closeTo(0, 1e-6)));
    expect(cursor(), SystemMouseCursors.none);

    await tester.sendEventToBinding(pan.up());
    await tester.pump();
    expect(cursor(), SystemMouseCursors.none);
  });
}

class _TrackingHandler extends _PromptingHandler {
  @override
  bool get tracksOverlayCursor => true;
}

class _PromptingHandler extends CanvasInputHandler {
  int downs = 0;

  @override
  bool get isPrompting => true;

  @override
  bool onPointerDown(Vec2 world, PointerDownEvent event) {
    downs++;
    return true;
  }
}

class _ReplayHandler extends CanvasInputHandler {
  bool prompting = false;
  final moves = <Vec2>[];

  @override
  bool get isPrompting => prompting;

  @override
  bool onPointerMove(Vec2 world, PointerEvent event) {
    moves.add(world);
    return true;
  }
}
