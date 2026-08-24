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
