import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the spacing grid stays on a 4-unit step so dense panels cannot drift',
    () {
      expect(FanCadTokens.space1, 4);
      expect(FanCadTokens.space2, FanCadTokens.space1 * 2);
      expect(FanCadTokens.space3, FanCadTokens.space1 * 3);
      expect(FanCadTokens.space4, FanCadTokens.space1 * 4);
      expect(FanCadTokens.space5, FanCadTokens.space1 * 6);
      expect(FanCadTokens.radiusSmall, FanCadTokens.space1);
      expect(
        FanCadTokens.sidePanelWidth,
        inInclusiveRange(
          FanCadTokens.sidePanelMinWidth,
          FanCadTokens.sidePanelMaxWidth,
        ),
      );
    },
  );

  test('chrome heights are fixed so a font change cannot steal the canvas', () {
    expect(FanCadTokens.titleBarHeight, 32);
    expect(FanCadTokens.tabBarHeight, 32);
    expect(FanCadTokens.commandLineHeight, 24);
    expect(FanCadTokens.statusBarHeight, 24);
    expect(FanCadTokens.rowHeight, 26);
    expect(FanCadTokens.macTrafficLightsWidth, 78);
    expect(FanCadTokens.activityBarWidth, 48);
    expect(FanCadTokens.splitterHit, 7);
    expect(FanCadTokens.iconSmall, 12);
    expect(FanCadTokens.iconMedium, 16);
    expect(FanCadTokens.iconLarge, 20);
    expect(FanCadTokens.sidePanelWidth, 240);
    expect(FanCadTokens.sidePanelMinWidth, 180);
  });

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

  testWidgets('a leftover hairline is a 1px strong rule', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const SizedBox(
          width: 80,
          height: 40,
          child: Column(
            children: [
              SizedBox(height: 10),
              ShellHairline(),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
    final hairline = tester.widget<ShellHairline>(find.byType(ShellHairline));
    expect(hairline.strong, isTrue);
    expect(hairline.axis, Axis.horizontal);
    expect(tester.getSize(find.byType(ShellHairline)).height, 1);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(ShellHairline),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, FanCadTokens.dark.borderStrong);
  });

  test('dark and light type styles keep token colours and tabular figures', () {
    const dark = FanCadTokens.dark;
    const light = FanCadTokens.light;

    expect(dark.bodyStyle.color, dark.text);
    expect(light.bodyStyle.color, light.text);
    expect(dark.labelStyle.color, dark.textMuted);
    expect(dark.sectionTitleStyle.letterSpacing, 0.6);
    expect(dark.monoStyle.fontFamily, FanCadTokens.monoFontFamily);
    expect(dark.monoStyle.fontFeatures, const [FontFeature.tabularFigures()]);
    expect(FanCadTokens.uiFontFamily, isNull);
  });
}
