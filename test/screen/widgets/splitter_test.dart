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
}
