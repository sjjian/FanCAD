import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AssistantNotifier controller({SettingsStore? settings}) {
    final store = settings ?? SettingsStore.inMemory();
    store.set(SettingsKeys.aiApiKeyRef, 'FANCAD_TEST_MISSING_KEY');
    store.set(SettingsKeys.aiApiKey, '');
    return Headless(
      settings: store,
      document: false,
    ).container.read(assistantNotifierProvider.notifier);
  }

  test('model, endpoint and auto-approve persist in settings', () {
    final store = SettingsStore.inMemory();
    store.set(SettingsKeys.aiApiKeyRef, 'FANCAD_TEST_MISSING_KEY');
    store.set(SettingsKeys.aiApiKey, '');
    final app = Headless(settings: store, document: false);
    final ai = app.container.read(assistantNotifierProvider.notifier);
    var ticks = 0;
    app.container.listen(assistantNotifierProvider, (_, _) => ticks++);

    ai.setDraft('draw a line');
    ai.setModel('deepseek-chat');
    ai.setBaseUrl('http://127.0.0.1:9/v1');
    ai.setAutoApprove(true);
    ai.setApiKey('sk-test');

    expect(ai.state.activeChat.draft, 'draw a line');
    expect(ai.state.activeProfile.model, 'deepseek-chat');
    expect(ai.state.activeProfile.baseUrl, 'http://127.0.0.1:9/v1');
    expect(ai.state.autoApprove, isTrue);
    expect(ai.state.activeProfile.apiKey, 'sk-test');
    expect(ai.state.activeProfile.model, 'deepseek-chat');
    expect(ai.state.activeProfile.apiKey, 'sk-test');
    expect(ticks, 5);
  });

  test('selecting a leftover profile swaps model, endpoint and key', () {
    final ai = controller();
    ai.setModel('deepseek-chat');
    ai.setBaseUrl('https://api.deepseek.com/v1');
    ai.setApiKey('sk-one');
    ai.addProfile();
    ai.setModel('gpt-4o-mini');
    ai.setBaseUrl('https://api.openai.com/v1');
    ai.setApiKey('sk-two');

    expect(ai.state.profiles, hasLength(2));
    expect(ai.state.activeProfile.model, 'gpt-4o-mini');

    ai.selectProfile(ai.state.profiles.first.id);
    expect(ai.state.activeProfile.model, 'deepseek-chat');
    expect(ai.state.activeProfile.baseUrl, 'https://api.deepseek.com/v1');
    expect(ai.state.activeProfile.apiKey, 'sk-one');
    expect(ai.state.activeProfile.model, 'deepseek-chat');

    ai.debugSetBusy(true);
    ai.selectProfile(ai.state.profiles.last.id);
    expect(ai.state.activeProfile.model, 'deepseek-chat');
  });

  test('a leftover empty new session is not duplicated', () {
    final ai = controller();
    expect(ai.state.chats, hasLength(1));
    ai.newSession();
    expect(ai.state.chats, hasLength(1));
    expect(ai.state.activeChat.conversation.visible, isEmpty);
  });

  test('new session keeps leftover messages on the previous thread', () {
    final ai = controller();
    ai.state.activeChat.conversation.addUser('draw a turtle');
    ai.newSession();
    expect(ai.state.activeChat.conversation.visible, isEmpty);
    expect(ai.state.chats, hasLength(2));
    final leftover = ai.state.chats.firstWhere(
      (chat) => chat.conversation.visible.isNotEmpty,
    );
    ai.selectSession(leftover.id);
    expect(
      ai.state.activeChat.conversation.visible.single.text,
      'draw a turtle',
    );
    expect(ai.state.activeChat.id, leftover.id);
  });

  test('a leftover stored chat is the active thread', () {
    final store = SettingsStore.inMemory({
      SettingsKeys.aiApiKeyRef: 'FANCAD_TEST_MISSING_KEY',
      SettingsKeys.aiApiKey: '',
      SettingsKeys.aiActiveChat: 'c1',
      SettingsKeys.aiChats: [
        {
          'id': 'c1',
          'title': 'draw a turtle',
          'visible': [
            {'role': 'user', 'text': 'draw a turtle'},
          ],
          'llm': [
            {'role': 'user', 'content': 'draw a turtle'},
          ],
        },
      ],
    });
    final ai = controller(settings: store);
    expect(ai.state.activeChat.id, 'c1');
    expect(
      ai.state.activeChat.conversation.visible.single.text,
      'draw a turtle',
    );
    expect(
      ai.state.activeChat.conversation.visible.single.text,
      isNot(contains('status')),
    );
  });

  test('clear drops leftover usage so the ring starts empty', () {
    final ai = controller();
    ai.debugSetUsage(const LlmUsage(promptTokens: 12400));
    expect(ai.state.activeChat.usage, isNotNull);
    ai.clear();
    expect(ai.state.activeChat.usage, isNull);
  });

  test(
    'an empty send is ignored and a missing key is an error, not a hang',
    () async {
      final ai = controller();
      await ai.send('   ');
      expect(ai.state.error, isNull);
      expect(ai.state.busy, isFalse);
      expect(ai.state.activeChat.conversation.visible, isEmpty);

      ai.setDraft('draw a circle');
      await ai.send();
      expect(ai.isConfigured, isFalse);
      expect(ai.state.error, contains('Paste one in Settings'));
      expect(ai.state.busy, isFalse);
      expect(ai.state.activeChat.draft, 'draw a circle');
    },
  );

  test('clearing a leftover pasted key forgets it', () {
    final ai = controller();
    ai.setApiKey('sk-x');
    expect(ai.state.activeProfile.apiKey, 'sk-x');
    ai.setApiKey('');
    expect(ai.state.activeProfile.apiKey, isEmpty);
    expect(ai.isConfigured, isFalse);
  });

  test('clear drops a leftover error so the next turn starts clean', () async {
    final ai = controller();
    await ai.send('hello');
    expect(ai.state.error, isNotNull);

    ai.clear();
    expect(ai.state.error, isNull);
    expect(ai.state.activeChat.conversation.visible, isEmpty);
  });

  test('leftover pending args stay out of the in-panel approval', () async {
    final ai = controller();
    ai.workspace.newDocument();
    const pending = PendingChangeSet(
      calls: [
        LlmToolCall(
          id: '1',
          name: 'draw_ellipse',
          arguments: {
            'center': [0, 55],
            'mystery': 'leftover',
          },
        ),
      ],
      commands: [
        CommandDescriptor(id: 'draw.ellipse', title: 'Ellipse', handler: _noop),
      ],
      highlightIds: [7, 8],
    );

    final future = ai.debugAskApproval(pending);
    expect(ai.state.approval, isNotNull);
    expect(ai.state.approval!.details, isNot(contains('center')));
    expect(ai.state.approval!.details, isNot(contains('mystery')));
    expect(ai.workspace.state.highlightIds, [7, 8]);

    ai.acceptPending();
    expect(await future, isTrue);
    expect(ai.state.approval, isNull);
    expect(ai.workspace.state.highlightIds, isEmpty);
  });

  test(
    'clear rejects leftover pending approval so the turn does not hang',
    () async {
      final ai = controller();
      const pending = PendingChangeSet(
        calls: [LlmToolCall(id: '1', name: 'draw_circle', arguments: {})],
        commands: [
          CommandDescriptor(id: 'draw.circle', title: 'Circle', handler: _noop),
        ],
      );

      final future = ai.debugAskApproval(pending);
      expect(ai.state.approval, isNotNull);
      ai.clear();
      expect(await future, isFalse);
      expect(ai.state.approval, isNull);
    },
  );

  test('an ask card does not highlight every referenced object', () async {
    final ai = controller();
    const question = SessionQuestion(
      question: 'Which turtle?',
      options: [
        SessionAskOption(id: 'left', label: 'Left'),
        SessionAskOption(id: 'right', label: 'Right'),
      ],
      ids: [1, 2, 3, 4],
    );
    final future = ai.debugAskQuestion(question);
    expect(ai.state.question, isNotNull);
    expect(ai.workspace.state.highlightIds, isEmpty);
    ai.cancelQuestion();
    expect(await future, {'status': 'cancelled'});
  });

  test('testProfile without a key notifies an error', () async {
    final ai = controller();
    await ai.testProfile(ai.state.activeProfile);
    expect(ai.workspace.state.notices, isNotEmpty);
    expect(ai.workspace.state.notices.last.isError, isTrue);
    expect(ai.workspace.state.notices.last.message, contains('No API key'));
  });

  test('pinning the leftover pick records ids for the next send', () {
    final ai = controller();
    final tab = ai.workspace.newDocument();
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    final id = tab.document.entities.single.id;
    tab.selection.replace([id]);
    ai.pinSelection();
    expect(ai.state.pins, hasLength(1));
    expect(ai.state.pins.single.ids, [id]);
    expect(ai.state.pins.single.tabId, tab.session.id);
    final flattened = flattenComposerPins(ai.state.pins, 'offset these');
    expect(flattened, contains('#$id'));
    expect(flattened, contains('tab: ${tab.session.id}'));
    expect(flattened, contains(tab.session.id));
  });

  test('a second selection on the same drawing is its own pin', () {
    final ai = controller();
    final tab = ai.workspace.newDocument();
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
      transaction.add(
        const LineEntity(id: 1, start: Vec2(0, 2), end: Vec2(4, 2)),
      );
    });
    final first = tab.document.entities.first.id;
    final second = tab.document.entities.last.id;
    tab.selection.replace([first]);
    ai.pinSelection();
    tab.selection.replace([second]);
    ai.pinSelection();
    expect(ai.state.pins, hasLength(2));
    expect(ai.state.pins.first.ids, [first]);
    expect(ai.state.pins.last.ids, [second]);
    expect(ai.state.pins.map((pin) => pin.tabId).toSet(), {tab.session.id});
  });

  test('pins from two drawings keep their own tab ids', () {
    final ai = controller();
    final first = ai.workspace.newDocument(title: 'Alpha');
    first.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    final firstId = first.document.entities.single.id;
    first.selection.replace([firstId]);
    ai.pinSelection();

    final second = ai.workspace.newDocument(title: 'Beta');
    second.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(8, 0)),
      );
    });
    final secondId = second.document.entities.single.id;
    second.selection.replace([secondId]);
    ai.pinSelection();

    expect(ai.state.pins, hasLength(2));
    expect(ai.state.pins.map((pin) => pin.tabId).toSet(), {
      first.session.id,
      second.session.id,
    });
    ai.hoverEntities(ai.state.pins.first.ids, tabId: ai.state.pins.first.tabId);
    expect(ai.workspace.state.highlightIds, isEmpty);
    final flattened = flattenComposerPins(ai.state.pins, 'move them');
    expect(flattened, contains('tab: ${first.session.id}'));
    expect(flattened, contains('tab: ${second.session.id}'));
    expect(flattened, contains('Alpha'));
    expect(flattened, contains('Beta'));
  });

  test('a standalone @ token is the mention query', () {
    expect(composerAtMentionAt('@', 1)?.query, '');
    expect(composerAtMentionAt('see @Al', 7)?.query, 'Al');
    expect(composerAtMentionAt('email@x', 7), isNull);
    expect(composerAtMentionAt('@Sheet', 0), isNull);
  });

  test('pinning a drawing tab records tab= without dumping entities', () {
    final ai = controller();
    final tab = ai.workspace.newDocument(title: 'Sheet');
    tab.session.edit('LINE', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    ai.pinDrawing(tab);
    expect(ai.state.pins, hasLength(1));
    expect(ai.state.pins.single.kind, ComposerPinKind.drawing);
    expect(ai.state.pins.single.ids, isEmpty);
    expect(ai.state.pins.single.tabId, tab.session.id);
    final flattened = flattenComposerPins(ai.state.pins, 'how many lines');
    expect(flattened, contains('tab: ${tab.session.id}'));
    expect(flattened, contains('Sheet'));
    expect(flattened, isNot(contains('ids:')));
    expect(flattened.toLowerCase(), contains('do not dump'));

    final inline = flattenComposerPins(
      ai.state.pins,
      'how many lines in $composerMentionToken',
    );
    expect(inline, 'how many lines in @drawing[tab=${tab.session.id}]');
    expect(inline, isNot(contains('Pinned:')));
    expect(inline, isNot(contains('Sheet')));
  });

  test('closing a drawing drops its live pin', () {
    final ai = controller();
    final tab = ai.workspace.newDocument(title: 'Gone');
    ai.pinDrawing(tab);
    expect(ai.debugLivePins(), hasLength(1));
    expect(ai.workspace.closeSession(tab.session, force: true), isTrue);
    expect(ai.debugLivePins(), isEmpty);
    expect(ai.state.pins, hasLength(1));
  });
}
