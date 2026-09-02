import 'package:fancad/fancad.dart';
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
    expect(FanCadTokens.filterBarHeight, 28);
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

  testWidgets('a leftover icon button stays 28 and a tab uses selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: Row(
            children: [
              ShellIconButton(icon: Icons.add, onPressed: () {}),
              ShellTab(
                selected: true,
                onTap: () {},
                child: const Text('Model'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ShellIconButton)).width, 28);
    expect(tester.getSize(find.byType(ShellIconButton)).height, 28);
    final tab = tester.widget<ShellTab>(find.byType(ShellTab));
    expect(tab.selected, isTrue);
    expect(tab.style, ShellTabStyle.strip);
    final fill = tester.widget<Container>(
      find.descendant(
        of: find.byType(ShellTab),
        matching: find.byType(Container),
      ),
    );
    expect(
      (fill.decoration! as BoxDecoration).color,
      FanCadTokens.dark.selection,
    );
  });

  test('dark and light type styles keep token colours and tabular figures', () {
    const dark = FanCadTokens.dark;
    const light = FanCadTokens.light;

    expect(dark.bodyStyle.color, dark.text);
    expect(light.bodyStyle.color, light.text);
    expect(dark.borderMuted, const Color(0xFF3A4048));
    expect(light.borderMuted, const Color(0xFFDDE2E8));
    expect(dark.borderMuted, isNot(dark.border));
    expect(dark.borderMuted, isNot(dark.borderStrong));
    expect(dark.labelStyle.color, dark.textMuted);
    expect(dark.sectionTitleStyle.fontSize, 13);
    expect(dark.sectionTitleStyle.fontWeight, FontWeight.w600);
    expect(dark.monoStyle.fontFamily, FanCadTokens.monoFontFamily);
    expect(dark.monoStyle.fontFeatures, const [FontFeature.tabularFigures()]);
    expect(FanCadTokens.uiFontFamily, isNull);
  });

  testWidgets('a leftover empty state is a centered message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const Scaffold(body: ShellEmpty(message: 'Nothing here')),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byType(ShellEmpty), findsOneWidget);
  });

  testWidgets('a leftover badge is an accent tag and a chip when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: Row(
            children: [
              const ShellBadge(text: 'LAST'),
              ShellBadge(text: 'default', selected: true, onTap: () {}),
              const ShellDot(color: Color(0xFF22C55E)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('LAST'), findsOneWidget);
    expect(find.text('default'), findsOneWidget);
    expect(find.byType(ShellBadge), findsNWidgets(2));
    expect(find.byType(ShellDot), findsOneWidget);
  });

  testWidgets('a leftover banner and toast keep warning and success tones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              ShellBanner(
                tone: ShellTone.warning,
                message: 'Layer off',
                action: 'Show',
              ),
              ShellToast(message: 'Saved', tone: ShellTone.success),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Layer off'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      tester.widget<ShellBanner>(find.byType(ShellBanner)).tone,
      ShellTone.warning,
    );
    expect(
      tester.widget<ShellToast>(find.byType(ShellToast)).tone,
      ShellTone.success,
    );
  });

  test('a leftover menu overlay uses the strong border radius', () {
    final shape =
        shellOverlayShape(FanCadTokens.dark) as RoundedRectangleBorder;
    expect(shape.side.color, FanCadTokens.dark.borderStrong);
    expect(shape.borderRadius, BorderRadius.circular(FanCadTokens.radius));
    expect(shellMenuItemHeight, 32);
    expect(shellMenuMinWidth, 180);
    expect(
      resolveShellMenuPlacement(
        requested: ShellMenuPlacement.auto,
        triggerCenterY: 100,
        overlayHeight: 800,
      ),
      ShellMenuPlacement.down,
    );
    expect(
      resolveShellMenuPlacement(
        requested: ShellMenuPlacement.auto,
        triggerCenterY: 500,
        overlayHeight: 800,
      ),
      ShellMenuPlacement.up,
    );
    expect(
      resolveShellMenuPlacement(
        requested: ShellMenuPlacement.up,
        triggerCenterY: 10,
        overlayHeight: 800,
      ),
      ShellMenuPlacement.up,
    );
    final above = shellMenuAnchorRect(
      trigger: const Rect.fromLTWH(10, 700, 40, 24),
      overlaySize: const Size(800, 800),
      placement: ShellMenuPlacement.up,
      menuHeight: 48,
    );
    expect(above.top, 700 - 48);
    expect(above.bottom, 800 - 700);
    final below = shellMenuAnchorRect(
      trigger: const Rect.fromLTWH(10, 40, 40, 24),
      overlaySize: const Size(800, 800),
      placement: ShellMenuPlacement.down,
    );
    expect(below.top, 64);
    expect(
      shellMenuExtent(const [
        PopupMenuItem<int>(value: 1, height: 32, child: SizedBox.shrink()),
        PopupMenuItem<int>(value: 2, height: 32, child: SizedBox.shrink()),
      ]),
      16 + shellMenuItemHeight * 2,
    );
  });
}
