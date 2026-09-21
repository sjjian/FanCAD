import 'package:fancad_ai/fancad_ai.dart';
import 'package:test/test.dart';

LlmMessage _user(String text) => LlmMessage.user(text);

LlmMessage _assistant(String text, {List<LlmToolCall> calls = const []}) =>
    LlmMessage.assistant(text, toolCalls: calls);

LlmMessage _tool(String id, String name, String content) =>
    LlmMessage.tool(toolCallId: id, content: content, name: name);

List<LlmMessage> _oldThenNew({required String oldTool}) => [
  _user('offset the left turtle'),
  _assistant(
    '',
    calls: [const LlmToolCall(id: '1', name: 'fancad', arguments: {})],
  ),
  _tool('1', 'fancad', oldTool),
  _user('now the right one'),
];

void main() {
  test('threshold is 80 percent of the window', () {
    expect(contextCompactThresholdTokens(window: 1000), 800);
    expect(
      contextCompactThresholdTokens(),
      (LlmUsage.contextWindowTokens * contextCompactFraction).floor(),
    );
  });

  test('old tool payloads are stubbed; the last user turn stays whole', () {
    final huge = 'x' * 400;
    final compacted = stubOldToolResults(_oldThenNew(oldTool: huge));
    expect(compacted, hasLength(4));
    expect(compacted[0].content, 'offset the left turtle');
    expect(compacted[1].toolCalls, hasLength(1));
    expect(compacted[1].toolCalls.single.id, '1');
    expect(isToolStubContent(compacted[2].content), isTrue);
    expect(compacted[2].content, contains('fancad'));
    expect(compacted[2].content, contains('400'));
    expect(compacted[2].toolCallId, '1');
    expect(compacted[3].content, 'now the right one');
    expect(compacted[3].content, isNot(contains('omitted:')));
  });

  test('a lone current turn is not stubbed', () {
    final messages = [
      _user('hi'),
      _assistant(
        '',
        calls: [const LlmToolCall(id: '1', name: 'fancad', arguments: {})],
      ),
      _tool('1', 'fancad', 'keep this json'),
    ];
    final compacted = stubOldToolResults(messages);
    expect(compacted.last.content, 'keep this json');
  });

  test('compact is a no-op under the token threshold', () async {
    final messages = _oldThenNew(oldTool: '{"ok":true}');
    final result = await compactLlmMessages(messages: messages, window: 128000);
    expect(result, same(messages));
  });

  test(
    'compact stubs old tools when the estimate is over the threshold',
    () async {
      final huge = 'e' * 2000;
      final messages = _oldThenNew(oldTool: huge);
      final result = await compactLlmMessages(messages: messages, window: 200);
      expect(isToolStubContent(result[2].content), isTrue);
      expect(result[3].content, 'now the right one');
    },
  );

  test('lastPromptTokens over the threshold also triggers a stub', () async {
    final messages = _oldThenNew(oldTool: '{"entities":[1,2,3]}');
    final result = await compactLlmMessages(
      messages: messages,
      lastPromptTokens: 900,
      window: 1000,
    );
    expect(isToolStubContent(result[2].content), isTrue);
  });

  test(
    'still-over history is replaced by a prior-conversation summary',
    () async {
      final huge = 'y' * 4000;
      final messages = [
        _user('offset the left turtle. Keep tab=2 ids 1-11. ${'note ' * 80}'),
        _assistant(
          'working',
          calls: [const LlmToolCall(id: '1', name: 'fancad', arguments: {})],
        ),
        _tool('1', 'fancad', huge),
        _user('now the right one'),
      ];
      final result = await compactLlmMessages(
        messages: messages,
        window: 40,
        summarize: (source) async {
          expect(source, contains('offset the left turtle'));
          return 'Edited the left turtle; ids 1-11 on tab=2.';
        },
      );
      expect(result.first.role, LlmRole.user);
      expect(result.first.content, startsWith('Prior conversation summary:'));
      expect(result.first.content, contains('ids 1-11'));
      expect(result.last.content, 'now the right one');
      expect(result.where((item) => item.role == LlmRole.tool), isEmpty);
    },
  );

  test('a failed summary keeps the stubbed transcript', () async {
    final huge = 'z' * 4000;
    final messages = _oldThenNew(oldTool: huge);
    final result = await compactLlmMessages(
      messages: messages,
      window: 40,
      summarize: (source) async => null,
    );
    expect(isToolStubContent(result[2].content), isTrue);
    expect(result[0].content, 'offset the left turtle');
  });

  test('overflow copy is detected without false friends', () {
    expect(
      isContextOverflowMessage('This model maximum context length exceeded'),
      isTrue,
    );
    expect(isContextOverflowMessage('too many tokens in the prompt'), isTrue);
    expect(isContextOverflowMessage('No API key'), isFalse);
  });
}
