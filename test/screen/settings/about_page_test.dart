import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('about page shows the product, version and update card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWithValue(settings)],
        child: MaterialApp(
          theme: FanCadTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AboutPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FanCAD'), findsOneWidget);
    expect(find.textContaining('GPL-3.0'), findsOneWidget);
    expect(find.text('0.0.0-dev'), findsOneWidget);
    expect(find.byKey(const Key('settings-update-auto-check')), findsOneWidget);
    expect(find.text('Not checked yet'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });
}
