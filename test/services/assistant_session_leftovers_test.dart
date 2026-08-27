import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AiController controller() {
    final settings = SettingsStore.inMemory();
    settings.set(SettingsKeys.aiApiKeyRef, 'FANCAD_TEST_MISSING_KEY');
    settings.set(SettingsKeys.aiApiKey, '');
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(settings),
    );
    final created = AiController(workspace: workspace, assistant: AssistantSettings(settings));
    addTearDown(created.dispose);
    addTearDown(workspace.dispose);
    return created;
  }

  test('a leftover long first line becomes a short session title', () {
    expect(titleFromUserMessage('draw a turtle'), 'draw a turtle');
    expect(titleFromUserMessage('${'x' * 80}\nsecond line'), '${'x' * 39}…');
    expect(titleFromUserMessage('${'x' * 80}'), isNot(contains('second')));
  });

  testWidgets(
    'new-session leftover sits after the last tab, not the strip end',
    (tester) async {
      final ai = controller();

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: FanCadTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 360, child: AiPanel(controller: ai)),
          ),
        ),
      );

      expect(
        tester.widget(find.byKey(Key('assistant-session-${ai.activeChat.id}'))),
        isA<ShellTab>(),
      );
      final tab = tester.getRect(
        find.byKey(Key('assistant-session-${ai.activeChat.id}')),
      );
      final plus = tester.getRect(
        find.byKey(const Key('assistant-new-session')),
      );
      expect(plus.left - tab.right, lessThan(8));
      expect(plus.left, lessThan(200));
    },
  );

  testWidgets('new chat keeps leftover messages on a session tab', (
    tester,
  ) async {
    final ai = controller();
    ai.conversation.addUser('画个小乌龟');
    final previous = ai.activeChat.id;
    ai.newSession();

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 360, child: AiPanel(controller: ai)),
        ),
      ),
    );

    expect(find.byKey(const Key('assistant-session-tabs')), findsOneWidget);
    expect(find.byKey(const Key('assistant-new-session')), findsOneWidget);
    expect(find.byKey(Key('assistant-session-$previous')), findsOneWidget);
    expect(find.text('画个小乌龟'), findsOneWidget);

    await tester.tap(find.byKey(Key('assistant-session-$previous')));
    await tester.pump();
    expect(find.text('画个小乌龟'), findsWidgets);
    expect(ai.messages.single.text, '画个小乌龟');
  });

  testWidgets('closing a leftover tab keeps the other thread', (tester) async {
    final ai = controller();
    ai.conversation.addUser('画个小乌龟');
    final previous = ai.activeChat.id;
    ai.newSession();
    ai.conversation.addUser('draw a square');

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 360, child: AiPanel(controller: ai)),
        ),
      ),
    );

    await tester.tap(
      find.byKey(Key('assistant-session-close-${ai.activeChat.id}')),
    );
    await tester.pump();
    expect(ai.activeChat.id, previous);
    expect(find.text('画个小乌龟'), findsWidgets);
    expect(find.text('draw a square'), findsNothing);
  });
}
