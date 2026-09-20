import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

AiController panelAi({SettingsStore? settings}) {
  final store =
      settings ??
      SettingsStore.inMemory({
        SettingsKeys.aiApiKeyRef: 'FANCAD_TEST_MISSING_KEY',
        SettingsKeys.aiApiKey: '',
      });
  final app = Headless(settings: store, document: false);
  final created = AiController(
    workspace: app.workspace,
    assistant: AssistantSettings(store),
  );
  addTearDown(created.dispose);
  return created;
}

Future<void> pumpAiPanel(WidgetTester tester, AiController ai, {Widget? home}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: FanCadTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home:
          home ??
          Scaffold(
            body: SizedBox(width: 360, child: AiPanel(controller: ai)),
          ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('leftover reasoning paints a thinking card, not the reply', (
    tester,
  ) async {
    final ai = panelAi();
    ai.conversation.appendReasoningDelta('plan the tail');
    ai.conversation.appendAssistantDelta('Drew it.');

    await pumpAiPanel(tester, ai);

    expect(find.byKey(const Key('assistant-thinking-card')), findsOneWidget);
    expect(find.text('Thinking'), findsOneWidget);
    expect(find.text('plan the tail'), findsNothing);
    expect(find.textContaining('Drew it.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-thinking-card')));
    await tester.pump();
    expect(find.text('plan the tail'), findsOneWidget);
    expect(find.text('Working…'), findsNothing);

    final list = tester.widget<ListView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      ),
    );
    final padding = list.padding!.resolve(TextDirection.ltr);
    expect(padding.left, assistantPaneInset);
    expect(padding.right, assistantPaneInset);
    expect(padding.bottom, greaterThan(FanCadTokens.space2));
    expect(
      padding.bottom,
      assistantTranscriptTail(tester.getSize(find.byWidget(list)).height),
    );
  });

  testWidgets('composer leftover shows a send key, not a model picker', (
    tester,
  ) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    await pumpAiPanel(tester, ai);

    expect(find.byKey(const Key('assistant-composer-model')), findsNothing);
    expect(find.byKey(const Key('assistant-composer-send')), findsOneWidget);
    expect(find.byKey(const Key('assistant-open-settings')), findsOneWidget);
    final panel = tester.getRect(find.byType(AiPanel));
    final card = tester.getRect(
      find.byKey(const Key('assistant-composer-card')),
    );
    final settings = tester.getRect(
      find.byKey(const Key('assistant-open-settings')),
    );
    final send = tester.getRect(
      find.byKey(const Key('assistant-composer-send')),
    );
    expect(card.left - panel.left, closeTo(assistantPaneInset, 1));
    expect(panel.right - card.right, closeTo(assistantPaneInset, 1));
    expect(panel.bottom - card.bottom, closeTo(assistantPaneInset, 1));
    expect(
      settings.left - card.left,
      greaterThanOrEqualTo(canvasHudPadding.left),
    );
    expect(
      settings.left - card.left,
      lessThanOrEqualTo(canvasHudPadding.left + 2),
    );
    expect(
      card.right - send.right,
      greaterThanOrEqualTo(canvasHudPadding.right),
    );
    expect(
      card.right - send.right,
      lessThanOrEqualTo(canvasHudPadding.right + 2),
    );
    expect(find.text('ASSISTANT'), findsNothing);
    expect(find.byKey(const Key('assistant-composer-stop')), findsNothing);
    expect(find.byKey(const Key('assistant-composer-context')), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).minLines, 2);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      'Ask the assistant  Enter to send',
    );
  });

  testWidgets('an unconfigured composer says the model is unavailable', (
    tester,
  ) async {
    final ai = panelAi();
    await pumpAiPanel(tester, ai);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(
      field.decoration!.hintText,
      'Model unavailable. Configure it in Settings.',
    );
    expect(field.decoration!.hintText, isNot(contains('Enter to send')));
    _expectEmptyGuideCentered(tester);
  });

  testWidgets('configured empty prompts sit in the middle of the pane', (
    tester,
  ) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    await pumpAiPanel(tester, ai);

    expect(find.text('Try'), findsOneWidget);
    expect(find.text('Draw a 100 mm square at the origin'), findsOneWidget);
    _expectEmptyGuideCentered(tester);
  });

  testWidgets('a leftover busy turn shows stop instead of send', (
    tester,
  ) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    ai.debugSetBusy(true);
    await pumpAiPanel(tester, ai);

    expect(find.byKey(const Key('assistant-composer-stop')), findsOneWidget);
    expect(find.byKey(const Key('assistant-composer-send')), findsNothing);
    expect(find.text('Add a follow-up'), findsOneWidget);
  });

  testWidgets('a leftover usage ring tooltip is compact, not raw JSON', (
    tester,
  ) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    ai.debugSetUsage(const LlmUsage(promptTokens: 12400, completionTokens: 12));
    await pumpAiPanel(tester, ai);

    final meter = tester.widget<AssistantContextMeter>(
      find.byType(AssistantContextMeter),
    );
    expect(meter.usage?.promptTokens, 12400);

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('assistant-composer-context')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, '12.4k / 128k');
    expect(tooltip.message, isNot(contains('prompt_tokens')));
    expect(tooltip.message, isNot(contains('12400')));
  });

  testWidgets(
    'leftover pending args stay off the card; a click outside does not decline',
    (tester) async {
      final ai = panelAi();
      await pumpAiPanel(
        tester,
        ai,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: SizedBox.expand()),
              SizedBox(width: 360, child: AiPanel(controller: ai)),
            ],
          ),
        ),
      );

      ai.conversation.addUser('画个小乌龟');
      final decision = ai.debugAskApproval(_leftoverPending());
      await tester.pump();

      expect(find.text('画个小乌龟'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byKey(const Key('assistant-approval-card')),
        ),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Allow 2 changes?'), findsOneWidget);
      expect(find.text('Ellipse ×2'), findsOneWidget);
      expect(find.textContaining('center'), findsNothing);
      expect(find.textContaining('mystery'), findsNothing);
      expect(find.textContaining('leftover'), findsNothing);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(ai.pendingApproval, isNotNull);
      expect(find.byKey(const Key('assistant-approval-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-approval-continue')));
      await tester.pump();
      expect(await decision, isTrue);
      expect(find.byKey(const Key('assistant-approval-card')), findsNothing);
    },
  );

  testWidgets(
    'new-session leftover sits after the last tab, not the strip end',
    (tester) async {
      final ai = panelAi();

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpAiPanel(tester, ai);

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
    final ai = panelAi();
    ai.conversation.addUser('画个小乌龟');
    final previous = ai.activeChat.id;
    ai.newSession();

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpAiPanel(tester, ai);

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
    final ai = panelAi();
    ai.conversation.addUser('画个小乌龟');
    final previous = ai.activeChat.id;
    ai.newSession();
    ai.conversation.addUser('draw a square');

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpAiPanel(tester, ai);

    await tester.tap(
      find.byKey(Key('assistant-session-close-${ai.activeChat.id}')),
    );
    await tester.pump();
    expect(ai.activeChat.id, previous);
    expect(find.text('画个小乌龟'), findsWidgets);
    expect(find.text('draw a square'), findsNothing);
  });
}

void _expectEmptyGuideCentered(WidgetTester tester) {
  final panel = tester.getRect(find.byType(AiPanel));
  final tabs = tester.getRect(find.byKey(const Key('assistant-session-tabs')));
  final composer = tester.getRect(
    find.byKey(const Key('assistant-composer-card')),
  );
  final guide = tester.getRect(find.byKey(const Key('assistant-empty-guide')));
  expect(guide.center.dx, closeTo(panel.center.dx, 8));
  expect(guide.center.dy, closeTo((tabs.bottom + composer.top) / 2, 12));
}

PendingChangeSet _leftoverPending() => const PendingChangeSet(
  calls: [
    LlmToolCall(
      id: '1',
      name: 'draw_ellipse',
      arguments: {
        'center': [0, 55],
        'mystery': 'leftover',
      },
    ),
    LlmToolCall(
      id: '2',
      name: 'draw_ellipse',
      arguments: {
        'center': [10, 0],
      },
    ),
  ],
  commands: [
    CommandDescriptor(id: 'draw.ellipse', title: 'Ellipse', handler: _noop),
    CommandDescriptor(id: 'draw.ellipse', title: 'Ellipse', handler: _noop),
  ],
);

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();
