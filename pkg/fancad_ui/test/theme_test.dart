import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme extensions snap at the midpoint instead of lerping colours', () {
    const dark = FanCadThemeExtension(FanCadTokens.dark);
    const light = FanCadThemeExtension(FanCadTokens.light);

    expect(dark.copyWith().tokens.isDark, isTrue);
    expect(dark.copyWith(tokens: FanCadTokens.light).tokens.isDark, isFalse);
    expect(identical(dark.lerp(null, 0.9), dark), isTrue);
    expect(dark.lerp(light, 0.49).tokens.isDark, isTrue);
    expect(dark.lerp(light, 0.5).tokens.isDark, isFalse);

    expect(FanCadTokens.dark.hover.a, closeTo(0.05, 1e-6));
    expect(FanCadTokens.light.hover.a, closeTo(0.04, 1e-6));
    expect(FanCadTokens.dark.pressed.a, closeTo(0.09, 1e-6));
    expect(FanCadTokens.light.pressed.a, closeTo(0.08, 1e-6));
    expect(FanCadTokens.dark.selection.a, closeTo(0.22, 1e-6));
    expect(FanCadTokens.light.selection.a, closeTo(0.14, 1e-6));
    expect(FanCadTokens.light.selection.r, FanCadTokens.light.accent.r);
  });

  testWidgets('a shell theme publishes tokens; a bare theme falls back to dark',
      (tester) async {
    late FanCadTokens fromLight;
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.light(),
        themeAnimationDuration: Duration.zero,
        home: Builder(
          builder: (context) {
            fromLight = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(fromLight.isDark, isFalse);
    expect(fromLight.canvas, FanCadTokens.light.canvas);
    expect(FanCadTheme.light().visualDensity, VisualDensity.compact);

    late FanCadTokens fromBare;
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        home: Builder(
          builder: (context) {
            fromBare = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(fromBare.canvas, FanCadTokens.dark.canvas);
    expect(FanCadTheme.dark().scaffoldBackgroundColor, FanCadTokens.dark.canvas);
  });
}
