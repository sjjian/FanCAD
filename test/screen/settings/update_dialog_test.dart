import 'package:fancad/fancad.dart';
import 'package:fancad_updater/fancad_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('update dialog explains the version and offers both choices', (
    tester,
  ) async {
    var upgraded = false;
    var skipped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateAvailableDialog(
                context,
                release: const ReleaseInfo(
                  sourceId: 'github',
                  version: '0.6.0',
                  notes: 'Fixed the line tool.',
                ),
                currentVersion: '0.5.0',
                onUpgrade: () => upgraded = true,
                onSkip: () => skipped = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('FanCAD 0.6.0 is available'), findsOneWidget);
    expect(find.text('You are on 0.5.0'), findsOneWidget);
    expect(find.text('Fixed the line tool.'), findsOneWidget);

    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();
    expect(upgraded, isTrue);
    expect(skipped, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();
    expect(skipped, isTrue);
  });
}
