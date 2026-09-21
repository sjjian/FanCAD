import 'package:fancad/fancad.dart';
import 'package:fancad/services/composer_pin.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace({SettingsStore? settings}) =>
      Headless(settings: settings, document: false).workspace;

  AiController controller({SettingsStore? settings}) {
    final store = settings ?? SettingsStore.inMemory();
    store.set(SettingsKeys.aiApiKeyRef, 'FANCAD_TEST_MISSING_KEY');
    store.set(SettingsKeys.aiApiKey, '');
    final created = AiController(
      workspace: workspace(settings: store),
      assistant: AssistantSettings(store),
    );
    addTearDown(created.dispose);
    return created;
  }

  test('model, endpoint and auto-approve persist in settings', () {
    final ai = controller();
    var ticks = 0;
    ai.addListener(() => ticks++);

    ai.setDraft('draw a line');
    ai.setModel('deepseek-chat');
    ai.setBaseUrl('http://127.0.0.1:9/v1');
    ai.setAutoApprove(true);
    ai.setApiKey('sk-test');

    expect(ai.draft, 'draw a line');
    expect(ai.model, 'deepseek-chat');
    expect(ai.baseUrl, 'http://127.0.0.1:9/v1');
    expect(ai.autoApprove, isTrue);
    expect(ai.apiKey, 'sk-test');
    expect(ai.assistant.activeProfile.model, 'deepseek-chat');
    expect(ai.assistant.activeProfile.apiKey, 'sk-test');
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

    expect(ai.profiles, hasLength(2));
    expect(ai.model, 'gpt-4o-mini');

    ai.selectProfile(ai.profiles.first.id);
    expect(ai.model, 'deepseek-chat');
    expect(ai.baseUrl, 'https://api.deepseek.com/v1');
    expect(ai.apiKey, 'sk-one');
    expect(ai.assistant.activeProfile.model, 'deepseek-chat');

    ai.debugSetBusy(true);
    ai.selectProfile(ai.profiles.last.id);
    expect(ai.model, 'deepseek-chat');
  });

  test('a leftover empty new session is not duplicated', () {
    final ai = controller();
    expect(ai.chats, hasLength(1));
    ai.newSession();
    expect(ai.chats, hasLength(1));
    expect(ai.messages, isEmpty);
  });

  test('new session keeps leftover messages on the previous thread', () {
    final ai = controller();
    ai.conversation.addUser('draw a turtle');
    ai.newSession();
    expect(ai.messages, isEmpty);
    expect(ai.chats, hasLength(2));
    final leftover = ai.chats.firstWhere(
      (chat) => chat.conversation.visible.isNotEmpty,
    );
    ai.selectSession(leftover.id);
    expect(ai.messages.single.text, 'draw a turtle');
    expect(ai.assistant.activeChatId(ai.chats), leftover.id);
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
    expect(ai.activeChat.id, 'c1');
    expect(ai.messages.single.text, 'draw a turtle');
    expect(ai.messages.single.text, isNot(contains('status')));
  });

  test('clear drops leftover usage so the ring starts empty', () {
    final ai = controller();
    ai.debugSetUsage(const LlmUsage(promptTokens: 12400));
    expect(ai.lastUsage, isNotNull);
    ai.clear();
    expect(ai.lastUsage, isNull);
  });

  test(
    'an empty send is ignored and a missing key is an error, not a hang',
    () async {
      final ai = controller();
      await ai.send('   ');
      expect(ai.error, isNull);
      expect(ai.isBusy, isFalse);
      expect(ai.messages, isEmpty);

      ai.setDraft('draw a circle');
      await ai.send();
      expect(ai.isConfigured, isFalse);
      expect(ai.error, contains('Paste one in Settings'));
      expect(ai.isBusy, isFalse);
      expect(ai.draft, 'draw a circle');
    },
  );

  test('clearing a leftover pasted key forgets it', () {
    final ai = controller();
    ai.setApiKey('sk-x');
    expect(ai.apiKey, 'sk-x');
    ai.setApiKey('');
    expect(ai.apiKey, isEmpty);
    expect(ai.isConfigured, isFalse);
  });

  test('clear drops a leftover error so the next turn starts clean', () async {
    final ai = controller();
    await ai.send('hello');
    expect(ai.error, isNotNull);

    ai.clear();
    expect(ai.error, isNull);
    expect(ai.messages, isEmpty);
  });

  test('leftover pending args stay out of the in-panel approval', () async {
    final ai = controller();
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
    expect(ai.pendingApproval, isNotNull);
    expect(ai.pendingApproval!.details, isNot(contains('center')));
    expect(ai.pendingApproval!.details, isNot(contains('mystery')));
    expect(ai.workspace.pendingHighlightIds, [7, 8]);

    ai.acceptPending();
    expect(await future, isTrue);
    expect(ai.pendingApproval, isNull);
    expect(ai.workspace.pendingHighlightIds, isEmpty);
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
      expect(ai.pendingApproval, isNotNull);
      ai.clear();
      expect(await future, isFalse);
      expect(ai.pendingApproval, isNull);
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
    expect(ai.pendingQuestion, isNotNull);
    expect(ai.workspace.pendingHighlightIds, isEmpty);
    ai.cancelQuestion();
    expect(await future, {'status': 'cancelled'});
  });

  test('testProfile without a key notifies an error', () async {
    final ai = controller();
    await ai.testProfile(ai.activeProfile);
    expect(ai.workspace.notices, isNotEmpty);
    expect(ai.workspace.notices.last.isError, isTrue);
    expect(ai.workspace.notices.last.message, contains('No API key'));
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
    expect(ai.pins, hasLength(1));
    expect(ai.pins.single.ids, [id]);
    expect(ai.pins.single.tabId, tab.session.id);
    final flattened = flattenComposerPins(ai.pins, 'offset these');
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
    expect(ai.pins, hasLength(2));
    expect(ai.pins.first.ids, [first]);
    expect(ai.pins.last.ids, [second]);
    expect(ai.pins.map((pin) => pin.tabId).toSet(), {tab.session.id});
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

    expect(ai.pins, hasLength(2));
    expect(ai.pins.map((pin) => pin.tabId).toSet(), {
      first.session.id,
      second.session.id,
    });
    ai.hoverEntities(ai.pins.first.ids, tabId: ai.pins.first.tabId);
    expect(ai.workspace.pendingHighlightIds, isEmpty);
    final flattened = flattenComposerPins(ai.pins, 'move them');
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
    expect(ai.pins, hasLength(1));
    expect(ai.pins.single.kind, ComposerPinKind.drawing);
    expect(ai.pins.single.ids, isEmpty);
    expect(ai.pins.single.tabId, tab.session.id);
    final flattened = flattenComposerPins(ai.pins, 'how many lines');
    expect(flattened, contains('tab: ${tab.session.id}'));
    expect(flattened, contains('Sheet'));
    expect(flattened, isNot(contains('ids:')));
    expect(flattened.toLowerCase(), contains('do not dump'));

    final inline = flattenComposerPins(
      ai.pins,
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
    expect(ai.pins, hasLength(1));
  });
}
