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
                left: ShellSplitter.overlayOrigin(40),
                top: 0,
                bottom: 0,
                width: FanCadTokens.splitterHit,
                child: ShellSplitter(axis: Axis.vertical, onDrag: (_) {}),
              ),
            ],
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(ShellSplitter));
    expect(size.width, FanCadTokens.splitterHit);
    expect(tester.getTopLeft(find.byKey(paneKey)).dx, 40);
    expect(tester.getTopLeft(find.byType(ShellSplitter)).dx, 37);
    expect(ShellSplitter.overlayOrigin(288), 285);
    expect(
      ShellSplitter.overlayOrigin(288) + (FanCadTokens.splitterHit ~/ 2),
      288,
    );
  });
}
