import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpWindow(
  WidgetTester tester, {
  String title = 'Inspect',
  String name = 'canvas-window',
  Offset origin = const Offset(200, 160),
  Size bounds = const Size(800, 600),
  Size initialSize = const Size(300, 232),
  Widget? child,
  Widget? footer,
  VoidCallback? onClose,
  VoidCallback? onBarrierTap,
}) async {
  tester.view.physicalSize = bounds;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: FanCadTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: [
            ShellCanvasWindow(
              name: name,
              title: title,
              origin: origin,
              bounds: bounds,
              initialSize: initialSize,
              onClose: onClose ?? () {},
              onBarrierTap: onBarrierTap,
              footer: footer,
              child: child ?? const SizedBox.expand(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a canvas window shows a title and close control', (
    tester,
  ) async {
    await pumpWindow(tester);

    expect(find.text('Inspect'), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-card')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-move')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-close')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-n')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-s')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-e')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-w')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-ne')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-nw')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-se')), findsOneWidget);
    expect(find.byKey(const Key('canvas-window-resize-sw')), findsOneWidget);
    final header = tester.widget<MouseRegion>(
      find
          .ancestor(
            of: find.byKey(const Key('canvas-window-move')),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(header.cursor, SystemMouseCursors.grab);
  });

  testWidgets('edges and corners resize the window', (tester) async {
    await pumpWindow(tester);

    final card = find.byKey(const Key('canvas-window-card'));
    final before = tester.getSize(card);
    final beforePos = tester.getTopLeft(card);

    await tester.drag(
      find.byKey(const Key('canvas-window-resize-se')),
      const Offset(80, 40),
    );
    await tester.pump();

    final afterSe = tester.getSize(card);
    expect(afterSe.width, greaterThan(before.width));
    expect(afterSe.height, greaterThan(before.height));
    expect(tester.getTopLeft(card), beforePos);

    await tester.drag(
      find.byKey(const Key('canvas-window-resize-w')),
      const Offset(-50, 0),
    );
    await tester.pump();

    final afterWest = tester.getSize(card);
    final afterWestPos = tester.getTopLeft(card);
    expect(afterWest.width, greaterThan(afterSe.width));
    expect(afterWestPos.dx, lessThan(beforePos.dx));
    expect(afterWestPos.dy, beforePos.dy);

    final seHandle = tester.getRect(
      find.byKey(const Key('canvas-window-resize-se')),
    );
    final cardRect = tester.getRect(card);
    expect(seHandle.right, greaterThanOrEqualTo(cardRect.right));
    expect(seHandle.bottom, greaterThanOrEqualTo(cardRect.bottom));
  });

  testWidgets('the header drag moves the window inside the canvas', (
    tester,
  ) async {
    await pumpWindow(tester);

    final card = find.byKey(const Key('canvas-window-card'));
    final before = tester.getTopLeft(card);
    await tester.drag(
      find.byKey(const Key('canvas-window-move')),
      const Offset(60, 30),
    );
    await tester.pump();

    final after = tester.getTopLeft(card);
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));

    await tester.drag(
      find.byKey(const Key('canvas-window-move')),
      const Offset(-4000, -4000),
    );
    await tester.pump();

    final minCorner = tester.getTopLeft(card);
    expect(minCorner.dx, greaterThanOrEqualTo(8));
    expect(minCorner.dy, greaterThanOrEqualTo(8));

    await tester.drag(
      find.byKey(const Key('canvas-window-move')),
      const Offset(4000, 4000),
    );
    await tester.pump();

    final maxCorner = tester.getTopLeft(card);
    final size = tester.getSize(card);
    expect(maxCorner.dx + size.width, lessThanOrEqualTo(800 - 8));
    expect(maxCorner.dy + size.height, lessThanOrEqualTo(600 - 8));
  });

  testWidgets('close and the barrier call the host', (tester) async {
    var closed = 0;
    var barrier = 0;
    await pumpWindow(
      tester,
      onClose: () => closed++,
      onBarrierTap: () => barrier++,
    );

    await tester.tap(find.byKey(const Key('canvas-window-close')));
    await tester.pump();
    expect(closed, 1);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(barrier, 1);
  });

  testWidgets('initial size is not smaller than minSize', (tester) async {
    await pumpWindow(tester, initialSize: const Size(100, 80));

    expect(
      tester.getSize(find.byKey(const Key('canvas-window-card'))),
      const Size(260, 200),
    );
  });

  testWidgets('a smaller canvas clamps size and position', (tester) async {
    await pumpWindow(tester, origin: const Offset(500, 400));

    await tester.drag(
      find.byKey(const Key('canvas-window-resize-se')),
      const Offset(250, 120),
    );
    await tester.pump();

    await pumpWindow(
      tester,
      origin: const Offset(500, 400),
      bounds: const Size(400, 300),
    );

    final card = tester.getRect(find.byKey(const Key('canvas-window-card')));
    expect(card.left, greaterThanOrEqualTo(8));
    expect(card.top, greaterThanOrEqualTo(8));
    expect(card.right, lessThanOrEqualTo(400 - 8));
    expect(card.bottom, lessThanOrEqualTo(300 - 8));
  });

  testWidgets('close stays tappable over the north-east resize handle', (
    tester,
  ) async {
    var closed = 0;
    await pumpWindow(tester, onClose: () => closed++);

    final close = tester.getRect(find.byKey(const Key('canvas-window-close')));
    await tester.tapAt(Offset(close.right - 8, close.top + 14));
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('the north handle sits outside the title bar', (tester) async {
    await pumpWindow(tester);

    final north = tester.getRect(
      find.byKey(const Key('canvas-window-resize-n')),
    );
    final card = tester.getRect(find.byKey(const Key('canvas-window-card')));
    expect(north.bottom, lessThanOrEqualTo(card.top));
  });

  testWidgets('two windows on one canvas need distinct names', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget twoWindows(String first, String second) {
      return MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              ShellCanvasWindow(
                name: first,
                title: 'Inspect',
                origin: const Offset(40, 40),
                bounds: const Size(800, 600),
                onClose: () {},
                child: const SizedBox.expand(),
              ),
              ShellCanvasWindow(
                name: second,
                title: 'Layers',
                origin: const Offset(400, 40),
                bounds: const Size(800, 600),
                onClose: () {},
                child: const SizedBox.expand(),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(twoWindows('inspect', 'layers'));
    await tester.pump();
    expect(find.byKey(const Key('inspect-card')), findsOneWidget);
    expect(find.byKey(const Key('layers-card')), findsOneWidget);
  });
}
