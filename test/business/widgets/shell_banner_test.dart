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
}
