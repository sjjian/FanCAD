import 'package:fancad_ai/fancad_ai.dart';
import 'package:test/test.dart';

void main() {
  test('user and tool turns appear in both the panel and the LLM transcript', () {
    final conversation = Conversation();
    conversation.addUser('draw a line');
    conversation.addAssistant('  ');
    conversation.addAssistantLlm(
      const LlmMessage.assistant(
        '',
        toolCalls: [LlmToolCall(id: '1', name: 'draw_line', arguments: {})],
      ),
    );
    conversation.addToolResult(
      call: const LlmToolCall(id: '1', name: 'draw_line', arguments: {}),
      content: 'ok',
    );
    conversation.addAssistant('done');

    expect(conversation.visible.map((item) => item.role), [
      ChatRole.user,
      ChatRole.tool,
      ChatRole.assistant,
    ]);
    expect(conversation.visible[1].toolName, 'draw_line');
    expect(conversation.llmMessages.map((item) => item.role), [
      LlmRole.user,
      LlmRole.assistant,
      LlmRole.tool,
    ]);
  });

  test('an empty user turn is skipped rather than sent to the model', () {
    final conversation = Conversation();
    conversation.addUser('   ');
    conversation.addUser('');
    expect(conversation.visible, isEmpty);
    expect(conversation.llmMessages, isEmpty);
    conversation.addUser('draw a line');
    expect(conversation.visible.single.text, 'draw a line');
    expect(conversation.llmMessages.single.role, LlmRole.user);
  });

  test('clear empties both sides of the transcript', () {
    final conversation = Conversation();
    conversation.addUser('hi');
    conversation.addAssistantLlm(const LlmMessage.assistant('hello'));
    conversation.addToolResult(
      call: const LlmToolCall(id: '1', name: 'query_summary', arguments: {}),
      content: 'failed',
      isError: true,
    );
    expect(conversation.visible.singleWhere((item) => item.isError).text, 'failed');
    conversation.clear();
    expect(conversation.visible, isEmpty);
    expect(conversation.llmMessages, isEmpty);
  });
}
