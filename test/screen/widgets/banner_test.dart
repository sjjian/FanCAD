import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a leftover banner and toast keep warning and success tones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              FanCadBanner(
                tone: FanCadTone.warning,
                message: 'Layer off',
                action: 'Show',
              ),
              FanCadToast(message: 'Saved', tone: FanCadTone.success),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Layer off'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      tester.widget<FanCadBanner>(find.byType(FanCadBanner)).tone,
      FanCadTone.warning,
    );
    expect(
      tester.widget<FanCadToast>(find.byType(FanCadToast)).tone,
      FanCadTone.success,
    );
  });

  testWidgets('an inset banner keeps the dismiss button off the border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: Scaffold(
          body: FanCadBanner(
            tone: FanCadTone.danger,
            inset: true,
            message: 'Open a drawing first.',
            onDismiss: () {},
          ),
        ),
      ),
    );
    final banner = tester.getRect(find.byType(FanCadBanner));
    final button = tester.getRect(find.byType(FanCadIconButton));
    expect(
      banner.right - button.right,
      greaterThanOrEqualTo(FanCadTokens.space1),
    );
    expect(button.top - banner.top, greaterThanOrEqualTo(FanCadTokens.space1));
    expect(
      banner.bottom - button.bottom,
      greaterThanOrEqualTo(FanCadTokens.space1),
    );
  });
}
