import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace({SettingsStore? settings}) {
    final created = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(settings ?? SettingsStore.inMemory()),
    );
    addTearDown(created.dispose);
    return created;
  }

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
}
