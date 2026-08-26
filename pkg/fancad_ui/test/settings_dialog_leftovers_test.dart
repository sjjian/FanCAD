import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(debugResetSettingsDialog);

  test('preferences panel leftovers map to settings tabs', () {
    expect(isPreferencesPanel('preferences'), isTrue);
    expect(isPreferencesPanel('preferences:assistant'), isTrue);
    expect(isPreferencesPanel('preferences:general'), isTrue);
    expect(isPreferencesPanel('ai'), isFalse);
    expect(isPreferencesPanel('layers'), isFalse);

    expect(settingsTabFromPanelId('preferences'), SettingsTab.general);
    expect(settingsTabFromPanelId('preferences:general'), SettingsTab.general);
    expect(
      settingsTabFromPanelId('preferences:assistant'),
      SettingsTab.assistant,
    );
  });

  testWidgets(
    'a leftover model id still shows in the free-text field',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final settings = SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
      });
      final tab = ValueNotifier(SettingsTab.assistant);
      addTearDown(tab.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWithValue(settings),
            importerProvider.overrideWithValue(
              DrawingImporter(backend: MemoryDrawingBackend()),
            ),
          ],
          child: MaterialApp(
            theme: FanCadTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsDialog(tab: tab),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings-tab-general')), findsOneWidget);
      expect(find.byKey(const Key('settings-tab-assistant')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const Key('settings-tab-general'))),
        isA<ShellTab>(),
      );
      expect(
        tester.widget(find.byKey(const Key('settings-tab-assistant'))),
        isA<ShellTab>(),
      );

      final field = tester.widget<SettingsTextField>(
        find.byKey(const Key('settings-model-field')),
      );
      expect(field.controller.text, 'deepseek-chat');
      expect(find.byKey(const Key('settings-model-gpt-4o')), findsNothing);
      expect(find.byKey(const Key('settings-model-gpt-4o-mini')), findsNothing);
      expect(find.text('gpt-4o-mini'), findsNothing);
      expect(find.text('o4-mini'), findsNothing);

      expect(find.byKey(const Key('settings-add-profile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-add-profile')));
      await tester.pump();
      expect(find.byKey(const Key('settings-profile-default')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const Key('settings-profile-default'))),
        isA<ShellBadge>(),
      );
      expect(find.byKey(const Key('settings-remove-profile')), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              RegExp(r'^settings-profile-(?!label$)').hasMatch(key.value);
        }),
        findsNWidgets(2),
      );
    },
  );
}
