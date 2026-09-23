import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(debugResetSettingsDialog);

  eachCase(
    [
      (
        name: 'preferences',
        panel: 'preferences',
        isPanel: true,
        tab: SettingsTab.general,
      ),
      (
        name: 'preferences:assistant',
        panel: 'preferences:assistant',
        isPanel: true,
        tab: SettingsTab.assistant,
      ),
      (
        name: 'preferences:models',
        panel: 'preferences:models',
        isPanel: true,
        tab: SettingsTab.models,
      ),
      (
        name: 'preferences:general',
        panel: 'preferences:general',
        isPanel: true,
        tab: SettingsTab.general,
      ),
      (
        name: 'preferences:mcp',
        panel: 'preferences:mcp',
        isPanel: true,
        tab: SettingsTab.mcp,
      ),
      (name: 'ai', panel: 'ai', isPanel: false, tab: null),
      (name: 'layers', panel: 'layers', isPanel: false, tab: null),
    ],
    (row) {
      expect(isPreferencesPanel(row.panel), row.isPanel);
      if (row.tab != null) {
        expect(settingsTabFromPanelId(row.panel), row.tab);
      }
    },
    name: (row) => 'panel leftover ${row.name} maps to a settings tab',
  );

  testWidgets('a leftover model id still shows in the free-text field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsStore.inMemory({
      SettingsKeys.aiModel: 'deepseek-chat',
    });
    final tab = ValueNotifier(SettingsTab.models);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(settings),
          drawingFilesProvider.overrideWithValue(
            DrawingFileService(dwgBackend: MemoryDwgBackend()),
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

    expect(find.byKey(const Key('settings-dialog')), findsOneWidget);
    expect(find.byType(FanCadCanvasWindow), findsOneWidget);
    expect(find.byKey(const Key('settings-card')), findsOneWidget);
    expect(find.byKey(const Key('settings-tab-general')), findsOneWidget);
    expect(find.byKey(const Key('settings-tab-assistant')), findsOneWidget);
    expect(find.byKey(const Key('settings-tab-models')), findsOneWidget);
    expect(find.byKey(const Key('settings-tab-mcp')), findsOneWidget);

    expect(find.byKey(const Key('settings-model-field')), findsNothing);
    expect(find.byKey(const Key('settings-add-profile')), findsOneWidget);
    expect(find.byKey(const Key('settings-profile-default')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-profile-edit-default')));
    await tester.pump();
    final field = tester.widget<SettingsTextField>(
      find.byKey(const Key('settings-model-field')),
    );
    expect(field.controller.text, 'deepseek-chat');

    await tester.tap(find.byKey(const Key('settings-add-profile')));
    await tester.pump();
    expect(find.byKey(const Key('settings-profile-default')), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('settings-profile-edit-');
      }),
      findsNWidgets(2),
    );
  });

  testWidgets('MCP can be turned off and its URL copied', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsStore.inMemory();
    final tab = ValueNotifier(SettingsTab.mcp);
    addTearDown(tab.dispose);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(settings),
          drawingFilesProvider.overrideWithValue(
            DrawingFileService(dwgBackend: MemoryDwgBackend()),
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

    expect(find.byKey(const Key('settings-tab-mcp')), findsOneWidget);
    expect(find.byKey(const Key('settings-mcp-enabled')), findsOneWidget);
    expect(find.byKey(const Key('settings-mcp-local')), findsOneWidget);
    expect(find.byKey(const Key('settings-mcp-port')), findsOneWidget);
    expect(find.byKey(const Key('settings-mcp-allowlist')), findsOneWidget);
    expect(find.byKey(const Key('settings-mcp-url')), findsOneWidget);
    expect(find.byKey(const Key('settings-mcp-copy')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('settings-mcp-url'))).data,
      'http://127.0.0.1:17830/mcp',
    );

    await tester.enterText(find.byKey(const Key('settings-mcp-port')), '19001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(settings.getInt(SettingsKeys.mcpPort), 19001);

    await tester.enterText(
      find.byKey(const Key('settings-mcp-allowlist')),
      '10.0.0.2, 10.0.0.3',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(settings.getStringList(SettingsKeys.mcpAllowlist), [
      '10.0.0.2',
      '10.0.0.3',
    ]);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-mcp-local')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    expect(settings.getBool(SettingsKeys.mcpLocal), isFalse);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-mcp-enabled')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    expect(settings.getBool(SettingsKeys.mcpEnabled), isFalse);

    await tester.tap(find.byKey(const Key('settings-mcp-copy')));
    await tester.pump();
    expect(copied, contains('"url": "http://127.0.0.1:19001/mcp"'));
    expect(copied, contains('Authorization'));
  });

  testWidgets('a settings dropdown menu shares both edges with its field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsStore.inMemory();
    final tab = ValueNotifier(SettingsTab.general);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(settings),
          drawingFilesProvider.overrideWithValue(
            DrawingFileService(dwgBackend: MemoryDwgBackend()),
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

    final field = tester.getRect(find.byKey(const Key('settings-language')));
    expect(field.width, greaterThan(fanCadMenuMinWidth));
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    final menu = tester.getRect(
      find.ancestor(
        of: find.byKey(const Key('settings-language-en')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.elevation == 3,
        ),
      ),
    );
    expect(menu.left, closeTo(field.left, 0.5));
    expect(menu.right, closeTo(field.right, 0.5));

    final fieldLabel = tester.getTopLeft(
      find.descendant(
        of: find.byKey(const Key('settings-language')),
        matching: find.text('English'),
      ),
    );
    final enLabel = tester.getTopLeft(
      find.descendant(
        of: find.byKey(const Key('settings-language-en')),
        matching: find.text('English'),
      ),
    );
    expect(enLabel.dx, closeTo(fieldLabel.dx, 1.5));
    expect(
      tester.getTopLeft(find.byIcon(Icons.check)).dx,
      greaterThan(enLabel.dx),
    );
  });

  testWidgets('the models add button does not shift the section rule', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsStore.inMemory();
    final tab = ValueNotifier(SettingsTab.general);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(settings),
          drawingFilesProvider.overrideWithValue(
            DrawingFileService(dwgBackend: MemoryDwgBackend()),
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

    Rect sectionRule() {
      return tester.getRect(
        find.descendant(
          of: find.byType(SettingsSection),
          matching: find.byType(FanCadHairline),
        ),
      );
    }

    final general = sectionRule();
    await tester.tap(find.byKey(const Key('settings-tab-models')));
    await tester.pump();
    expect(sectionRule().top, general.top);
  });

  testWidgets('the assistant page picks a model from a dropdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final settings = SettingsStore.inMemory({
      SettingsKeys.aiProfiles: [
        {
          'id': 'default',
          'label': 'aaa',
          'model': 'deepseek-chat',
          'baseUrl': 'https://api.deepseek.com/v1',
        },
        {
          'id': 'other',
          'label': 'bbb',
          'model': 'gpt-4o-mini',
          'baseUrl': 'https://api.openai.com/v1',
        },
      ],
      SettingsKeys.aiActiveProfile: 'default',
    });
    final tab = ValueNotifier(SettingsTab.assistant);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(settings),
          drawingFilesProvider.overrideWithValue(
            DrawingFileService(dwgBackend: MemoryDwgBackend()),
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

    expect(find.byKey(const Key('settings-model-field')), findsNothing);
    expect(find.byKey(const Key('settings-api-key')), findsNothing);
    expect(find.byKey(const Key('settings-add-profile')), findsNothing);
    expect(find.byKey(const Key('settings-current-model')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-current-model')));
    await tester.pumpAndSettle();
    expect(tab.value, SettingsTab.assistant);
    expect(
      find.byKey(const Key('settings-current-model-other')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings-current-model-other')));
    await tester.pumpAndSettle();
    expect(tab.value, SettingsTab.assistant);
    expect(settings.getString(SettingsKeys.aiActiveProfile), 'other');
    expect(find.byKey(const Key('settings-model-field')), findsNothing);
    expect(find.byKey(const Key('settings-add-profile')), findsNothing);
  });
}
