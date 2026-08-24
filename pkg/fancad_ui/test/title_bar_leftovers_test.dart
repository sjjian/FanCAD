import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native traffic lights keep the first title-bar icon out of their slot',
    () {
      expect(
        TitleBar.leadingInset(usesNativeTrafficLights: true),
        FanCadTokens.macTrafficLightsWidth,
      );
      expect(
        TitleBar.leadingInset(usesNativeTrafficLights: false),
        FanCadTokens.space2,
      );
      expect(
        TitleBar.usesCustomWindowButtons(usesNativeTrafficLights: true),
        isFalse,
      );
      expect(
        TitleBar.usesCustomWindowButtons(usesNativeTrafficLights: false),
        isTrue,
      );
      // The traffic-light cluster is about 70px; the reserved slot must
      // clear it without eating the activity bar.
      expect(FanCadTokens.macTrafficLightsWidth, greaterThanOrEqualTo(70));
      expect(
        FanCadTokens.macTrafficLightsWidth,
        lessThan(FanCadTokens.activityBarWidth * 2),
      );
    },
  );

  test('a single drawing is not repeated in the title bar', () {
    expect(TitleBar.chromeTitle(tabCount: 0), 'FanCAD');
    expect(
      TitleBar.chromeTitle(tabCount: 1, activeTitle: 'part.dwg', dirty: true),
      'FanCAD',
    );
    expect(
      TitleBar.chromeTitle(tabCount: 2, activeTitle: 'part.dwg', dirty: true),
      '● part.dwg — FanCAD',
    );
  });
}
