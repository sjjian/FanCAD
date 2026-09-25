import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover splitter is a transparent overlay mask', (
    tester,
  ) async {
    const paneKey = Key('pane');
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: SizedBox(
          width: 200,
          height: 80,
          child: Stack(
            children: [
              const Row(
                children: [
                  SizedBox(width: 40, height: 80),
                  Expanded(child: SizedBox(key: paneKey, height: 80)),
                ],
              ),
              Positioned(
                left: FanCadSplitter.overlayOrigin(40),
                top: 0,
                bottom: 0,
                width: CommandLineLayout.splitterHit,
                child: FanCadSplitter(axis: Axis.vertical, onDrag: (_) {}),
              ),
            ],
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(FanCadSplitter));
    expect(size.width, CommandLineLayout.splitterHit);
    expect(tester.getTopLeft(find.byKey(paneKey)).dx, 40);
    expect(tester.getTopLeft(find.byType(FanCadSplitter)).dx, 37);
    expect(FanCadSplitter.overlayOrigin(288), 285);
    expect(
      FanCadSplitter.overlayOrigin(288) + (CommandLineLayout.splitterHit ~/ 2),
      288,
    );
  });

  testWidgets('a drag resizes the pane and leaves it unbuilt', (tester) async {
    final builds = _BuildCounter(boxKey: const Key('fixed'));
    final flexBuilds = _BuildCounter(boxKey: const Key('flex'));
    final controller = FanCadSplitController(
      extent: 120,
      minExtent: 80,
      maxExtent: 240,
    );
    var notices = 0;
    controller.addListener(() => notices += 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: SizedBox(
          width: 400,
          height: 80,
          child: FanCadSplit(
            controller: controller,
            handleKey: const Key('sash'),
            first: builds,
            second: flexBuilds,
          ),
        ),
      ),
    );
    expect(builds.count, 1);
    expect(flexBuilds.count, 1);
    expect(tester.getSize(find.byKey(const Key('fixed'))).width, 120);
    final flexBefore = tester.getSize(find.byKey(const Key('flex'))).width;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sash'))),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(builds.count, 1);
    expect(flexBuilds.count, 1);
    expect(controller.extent, 150);
    expect(notices, greaterThan(0));
    expect(tester.getSize(find.byKey(const Key('fixed'))).width, 150);
    expect(
      tester.getSize(find.byKey(const Key('flex'))).width,
      flexBefore - 30,
    );

    await gesture.up();
    await tester.pump();
    expect(builds.count, 1);
    expect(flexBuilds.count, 1);
    expect(controller.extent, 150);
  });

  testWidgets('the flexible pane keeps its minimum and the fixed pane yields', (
    tester,
  ) async {
    final controller = FanCadSplitController(
      extent: 160,
      minExtent: 80,
      maxExtent: 240,
    );
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(200, 40));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 40,
          child: FanCadSplit(
            controller: controller,
            flexMinExtent: 100,
            first: const SizedBox(key: Key('fixed')),
            second: const SizedBox(key: Key('flex')),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('fixed'))).width, 100);
    expect(tester.getSize(find.byKey(const Key('flex'))).width, 100);
    expect(controller.extent, 160);
  });

  test('dragging past the maximum waits until the pointer comes back', () {
    final controller = FanCadSplitController(
      extent: 200,
      minExtent: 80,
      maxExtent: 240,
    );
    addTearDown(controller.dispose);
    controller.applyDelta(80);
    expect(controller.extent, 240);

    controller.applyDelta(-10);
    expect(controller.extent, 240);

    controller.applyDelta(-40);
    expect(controller.extent, 230);

    controller.applyDelta(50);
    expect(controller.extent, 240);
    controller.endDrag();
    controller.applyDelta(-10);
    expect(controller.extent, 230);
  });
}

class _BuildCounter extends StatefulWidget {
  _BuildCounter({required this.boxKey});

  final Key boxKey;
  int count = 0;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.count += 1;
    return SizedBox(key: widget.boxKey);
  }
}
