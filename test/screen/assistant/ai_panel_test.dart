import 'dart:async';

import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

final _aiContainers = Expando<ProviderContainer>();

AiController panelAi({SettingsStore? settings}) {
  final store =
      settings ??
      SettingsStore.inMemory({
        SettingsKeys.aiApiKeyRef: 'FANCAD_TEST_MISSING_KEY',
        SettingsKeys.aiApiKey: '',
      });
  final app = Headless(settings: store, document: false);
  final created = app.container.read(assistantNotifierProvider.notifier);
  _aiContainers[created] = app.container;
  return created;
}

Future<void> pumpAiPanel(WidgetTester tester, AiController ai, {Widget? home}) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: _aiContainers[ai]!,
      child: MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home:
            home ??
            Scaffold(
              body: SizedBox(width: 360, child: AiPanel(controller: ai)),
            ),
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
    expect(find.text('Thought'), findsOneWidget);
    expect(find.text('plan the tail'), findsNothing);
    expect(find.byType(AssistantMarkdown), findsOneWidget);
    expect(find.textContaining('Drew it.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-thinking-card')));
    await tester.pump();
    expect(find.textContaining('plan the tail'), findsOneWidget);
    expect(find.byType(AssistantMarkdown), findsNWidgets(2));
    expect(find.text('Working…'), findsNothing);

    final transcript = tester.getSize(find.byKey(assistantTranscriptKey));
    final tail = tester.widget<SizedBox>(
      find.byKey(assistantTranscriptTailKey),
    );
    expect(tail.height, greaterThan(FanCadTokens.space2));
    expect(tail.height, assistantTranscriptTail(transcript.height));
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
    expect(card.left - panel.left, closeTo(assistantPromptInset, 1));
    expect(panel.right - card.right, closeTo(assistantPromptInset, 1));
    expect(panel.bottom - card.bottom, closeTo(assistantPromptInset, 1));
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
      closeTo(canvasHudPadding.right + FanCadTokens.space1, 2),
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
          of: find.byKey(assistantTranscriptKey),
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
        isA<FanCadTab>(),
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

  testWidgets('a configured composer shows pin controls', (tester) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    await pumpAiPanel(tester, ai);

    expect(find.byKey(const Key('assistant-pin-selection')), findsOneWidget);
    expect(find.byIcon(Icons.tag), findsOneWidget);
    expect(find.byKey(const Key('assistant-mention-drawing')), findsOneWidget);
    final pin = tester.widget<FanCadIconButton>(
      find.byKey(const Key('assistant-pin-selection')),
    );
    expect(pin.size, 24);
    expect(pin.iconSize, FanCadTokens.iconMedium);
    expect(
      tester.getSize(find.byKey(const Key('assistant-composer-send'))),
      const Size(24, 24),
    );
    expect(
      tester.getSize(find.byKey(const Key('assistant-composer-context'))),
      const Size(24, 24),
    );
  });

  testWidgets('pinning the selection inserts an inline mention in the field', (
    tester,
  ) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    final tab = ai.workspace.newDocument();
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    final id = tab.document.entities.single.id;
    tab.selection.replace([id]);
    ai.pinSelection();
    await pumpAiPanel(tester, ai);
    await tester.pump();

    expect(find.byKey(const Key('assistant-pin-0')), findsOneWidget);
    expect(find.text('1 objects'), findsOneWidget);
    expect(find.text('1 line'), findsNothing);
    final chip = tester.getRect(find.byKey(const Key('assistant-pin-0')));
    final field = tester.getRect(find.byType(TextField));
    expect(field.overlaps(chip), isTrue);
    expect(find.byKey(const Key('assistant-pin-remove-0')), findsNothing);
    expect(
      tester
          .widget<MouseRegion>(
            find
                .ancestor(
                  of: find.byKey(const Key('assistant-pin-0')),
                  matching: find.byType(MouseRegion),
                )
                .first,
          )
          .cursor,
      SystemMouseCursors.click,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('assistant-pin-0'))),
    );
    await tester.pump();
    expect(find.byKey(const Key('assistant-pin-remove-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-pin-remove-0')));
    await tester.pump();
    expect(ai.pins, isEmpty);
    expect(find.byKey(const Key('assistant-pin-0')), findsNothing);
  });

  testWidgets(
    'typing @ lists open drawings and pinning one keeps an inline chip',
    (tester) async {
      final ai = panelAi(
        settings: SettingsStore.inMemory({
          SettingsKeys.aiModel: 'deepseek-chat',
          SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
          SettingsKeys.aiApiKey: 'sk-one',
        }),
      );
      ai.workspace.newDocument(title: 'Alpha');
      final beta = ai.workspace.newDocument(title: 'Beta');
      await pumpAiPanel(tester, ai);

      final cardBefore = tester.getRect(
        find.byKey(const Key('assistant-composer-card')),
      );
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('assistant-mention-list')), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      final list = tester.getRect(
        find.byKey(const Key('assistant-mention-list')),
      );
      final card = tester.getRect(
        find.byKey(const Key('assistant-composer-card')),
      );
      expect(card.top, closeTo(cardBefore.top, 0.5));
      expect(list.bottom, lessThanOrEqualTo(card.top));
      expect(list.left, closeTo(card.left, 0.5));
      expect(list.right, closeTo(card.right, 0.5));

      await tester.enterText(find.byType(TextField), '@Be');
      await tester.pump();
      await tester.pump();
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(
        find.byKey(Key('assistant-mention-row-${beta.session.id}')),
      );
      await tester.pump();
      expect(find.byKey(const Key('assistant-mention-list')), findsNothing);
      expect(ai.pins, hasLength(1));
      expect(ai.pins.single.kind, ComposerPinKind.drawing);
      expect(ai.pins.single.tabId, beta.session.id);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        composerMentionToken,
      );
      expect(find.byKey(const Key('assistant-pin-0')), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    },
  );

  testWidgets('a session.ask popup waits for continue', (tester) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    const question = SessionQuestion(
      question: 'Fillet or chamfer?',
      options: [
        SessionAskOption(id: 'fillet', label: 'Fillet 10'),
        SessionAskOption(id: 'chamfer', label: 'Chamfer'),
      ],
    );
    final future = ai.debugAskQuestion(question);
    await pumpAiPanel(tester, ai);
    await tester.pump();

    expect(find.byKey(const Key('assistant-ask-card')), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('Fillet 10'), findsOneWidget);
    expect(find.text('Chamfer'), findsOneWidget);
    expect(find.byKey(const Key('assistant-ask-custom')), findsOneWidget);
    expect(find.text('Other…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-ask-fillet')));
    await tester.pump();
    expect(find.byKey(const Key('assistant-ask-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-ask-submit')));
    await tester.pump();
    expect(await future, {
      'status': 'ok',
      'id': 'fillet',
      'label': 'Fillet 10',
    });
    expect(find.byKey(const Key('assistant-ask-card')), findsNothing);
  });

  testWidgets('a multiple ask waits until continue', (tester) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    const question = SessionQuestion(
      question: 'Which of these?',
      multiple: true,
      options: [
        SessionAskOption(id: 'fillet', label: 'Fillet 10'),
        SessionAskOption(id: 'chamfer', label: 'Chamfer'),
      ],
    );
    final future = ai.debugAskQuestion(question);
    await pumpAiPanel(tester, ai);
    await tester.pump();

    await tester.tap(find.byKey(const Key('assistant-ask-fillet')));
    await tester.pump();
    expect(find.byKey(const Key('assistant-ask-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-ask-chamfer')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-ask-submit')));
    await tester.pump();
    expect(await future, {
      'status': 'ok',
      'multiple': true,
      'id': 'fillet',
      'label': 'Fillet 10',
      'ids': ['fillet', 'chamfer'],
      'labels': ['Fillet 10', 'Chamfer'],
    });
  });

  testWidgets('an ask option tag becomes a pin chip', (tester) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    const question = SessionQuestion(
      question: 'Which batch?',
      options: [
        SessionAskOption(id: 'these', label: 'These @objects[tab=7 ids=1,2,3]'),
        SessionAskOption(id: 'other', label: 'Something else'),
      ],
    );
    unawaited(ai.debugAskQuestion(question));
    await pumpAiPanel(tester, ai);
    await tester.pump();

    expect(find.byKey(const Key('assistant-pin-chip')), findsOneWidget);
    expect(find.textContaining('@objects'), findsNothing);
    expect(find.textContaining('3 objects'), findsOneWidget);
  });

  testWidgets('hovering an ask option highlights only that batch', (
    tester,
  ) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    final tab = ai.workspace.newDocument();
    final question = SessionQuestion(
      question: 'Which turtle?',
      options: [
        SessionAskOption(
          id: 'left',
          label: 'Left @objects[tab=${tab.session.id} ids=1,2]',
        ),
        SessionAskOption(
          id: 'right',
          label: 'Right @objects[tab=${tab.session.id} ids=9]',
        ),
      ],
      ids: const [1, 2, 9],
    );
    unawaited(ai.debugAskQuestion(question));
    await pumpAiPanel(tester, ai);
    await tester.pump();
    expect(ai.workspace.pendingHighlightIds, isEmpty);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('assistant-ask-left'))),
    );
    await tester.pump();
    expect(ai.workspace.pendingHighlightIds, [1, 2]);

    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('assistant-ask-right'))),
    );
    await tester.pump();
    expect(ai.workspace.pendingHighlightIds, [9]);
  });

  testWidgets('a user bubble keeps chips instead of raw tags', (tester) async {
    final ai = panelAi(
      settings: SettingsStore.inMemory({
        SettingsKeys.aiModel: 'deepseek-chat',
        SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
        SettingsKeys.aiApiKey: 'sk-one',
      }),
    );
    ai.conversation.addUser('offset @objects[tab=7 ids=1,2,3]');
    await pumpAiPanel(tester, ai);

    expect(find.byKey(const Key('assistant-pin-chip')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PinAwareText),
        matching: find.textContaining('@objects'),
      ),
      findsNothing,
    );
    expect(find.textContaining('offset'), findsWidgets);
  });

  testWidgets('a user leftover spans the composer width', (tester) async {
    final ai = panelAi();
    ai.conversation.addUser('hi');
    await pumpAiPanel(tester, ai);
    await tester.pump();

    final panel = tester.getRect(find.byType(AiPanel));
    final user = tester.getRect(find.byKey(assistantUserBlockKey));
    final composer = tester.getRect(
      find.byKey(const Key('assistant-composer-card')),
    );
    expect(user.left, closeTo(composer.left, 1));
    expect(user.right, closeTo(composer.right, 1));
    expect(user.left - panel.left, closeTo(assistantPromptInset, 1));
    expect(assistantPromptInset, lessThan(assistantPaneInset));

    final fill = assistantPromptFill(FanCadTokens.dark);
    expect(fill, isNot(FanCadTokens.dark.surface));
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const Key('assistant-composer-card')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      fill,
    );
    final bubble =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(assistantUserBlockKey),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Container &&
                          widget.decoration is BoxDecoration,
                    ),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(bubble.color, fill);
    expect(bubble.border, isNotNull);
    expect(user.height, greaterThan(36));
  });

  testWidgets('a long user leftover stays two lines until tapped', (
    tester,
  ) async {
    final ai = panelAi();
    ai.conversation.addUser('第一行\n第二行\n第三行\n第四行');
    await pumpAiPanel(tester, ai);
    await tester.pump();

    final collapsed = tester.getSize(find.byKey(assistantUserBlockKey)).height;
    expect(collapsed, lessThan(80));

    await tester.tap(find.byKey(assistantUserBlockKey));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(assistantUserBlockKey)).height,
      greaterThan(collapsed + 8),
    );
  });

  testWidgets('the last user leftover pins to the top of the thread', (
    tester,
  ) async {
    final ai = panelAi();
    ai.conversation.addUser('再看看');
    ai.conversation.addAssistant('${'此前的回复。' * 24}\n' * 8);
    ai.conversation.addUser('分析下为啥失败了');
    ai.conversation.addAssistant('${'后面的回复。' * 24}\n' * 8);

    await pumpAiPanel(
      tester,
      ai,
      home: Scaffold(
        body: SizedBox(width: 360, height: 420, child: AiPanel(controller: ai)),
      ),
    );
    await tester.pump();

    final thread = tester.getRect(find.byKey(assistantTranscriptKey));
    final last = tester.getRect(find.byKey(assistantUserBlockKey));
    expect(find.text('分析下为啥失败了'), findsOneWidget);
    expect(last.left, closeTo(thread.left + assistantPromptInset, 1));
    expect(last.right, closeTo(thread.right - assistantPromptInset, 1));
    expect(last.top, closeTo(thread.top + FanCadTokens.space4, 2));

    await tester.drag(
      find.byKey(assistantTranscriptKey),
      const Offset(0, -180),
    );
    await tester.pump();
    expect(
      tester.getRect(find.byKey(assistantUserBlockKey)).top,
      closeTo(thread.top + FanCadTokens.space4, 2),
    );

    final scroll = tester
        .widget<CustomScrollView>(find.byKey(assistantTranscriptKey))
        .controller!;
    scroll.jumpTo(0);
    await tester.pump();
    final first = find.descendant(
      of: find.byKey(assistantTranscriptKey),
      matching: find.text('再看看'),
    );
    expect(first, findsOneWidget);
    expect(
      tester
          .getRect(find.ancestor(of: first, matching: find.byType(Tooltip)))
          .top,
      closeTo(thread.top + FanCadTokens.space4, 2),
    );
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
