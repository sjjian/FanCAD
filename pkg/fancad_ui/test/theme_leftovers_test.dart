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
    expect(FanCadTokens.titleBarHeight, 36);
    expect(FanCadTokens.activityBarWidth, 48);
    expect(FanCadTokens.tabBarHeight, 34);
    expect(FanCadTokens.commandLineHeight, 30);
    expect(FanCadTokens.statusBarHeight, 24);
    expect(FanCadTokens.rowHeight, 26);
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
