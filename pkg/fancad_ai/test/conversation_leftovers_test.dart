import 'package:fancad_ai/fancad_ai.dart';
import 'package:test/test.dart';

void main() {
  test('visible model text appears in both the panel and the transcript', () {
    final conversation = Conversation();
    conversation.addAssistantLlm(const LlmMessage.assistant('here is a line'));

    expect(conversation.visible.single.role, ChatRole.assistant);
    expect(conversation.visible.single.text, 'here is a line');
    expect(conversation.llmMessages.single.role, LlmRole.assistant);
    expect(conversation.llmMessages.single.content, 'here is a line');
  });

  test('streamed leftovers grow one bubble and do not duplicate it', () {
    final conversation = Conversation();
    conversation.appendAssistantDelta('Hel');
    conversation.appendAssistantDelta('lo');
    expect(conversation.visible, hasLength(1));
    expect(conversation.visible.single.text, 'Hello');

    conversation.addAssistantLlm(const LlmMessage.assistant('Hello'));
    expect(conversation.visible, hasLength(1));
    expect(conversation.llmMessages, hasLength(1));

    conversation.replaceLastAssistant('Hello **world**');
    expect(conversation.visible.single.text, 'Hello **world**');
  });

  test('leftover reasoning stays on the pane and off the model transcript', () {
    final conversation = Conversation();
    conversation.appendReasoningDelta('I will ');
    conversation.appendReasoningDelta('draw a tail.');
    conversation.appendAssistantDelta('Done.');
    conversation.addAssistantLlm(const LlmMessage.assistant('Done.'));

    expect(conversation.visible.map((item) => item.role), [
      ChatRole.reasoning,
      ChatRole.assistant,
    ]);
    expect(conversation.visible.first.text, 'I will draw a tail.');
    expect(conversation.llmMessages, hasLength(1));
    expect(conversation.llmMessages.single.content, 'Done.');
    expect(conversation.llmMessages.single.content, isNot(contains('tail')));
  });

  test('leftover think tags become a reasoning card, not model history', () {
    final conversation = Conversation();
    conversation.addAssistantLlm(
      const LlmMessage.assistant(
        '<think>use a polyline</think>Drew the tail.',
      ),
    );
    expect(conversation.visible.map((item) => item.role), [
      ChatRole.reasoning,
      ChatRole.assistant,
    ]);
    expect(conversation.visible.first.text, 'use a polyline');
    expect(conversation.visible.last.text, 'Drew the tail.');
    expect(conversation.llmMessages.single.content, 'Drew the tail.');
    expect(conversation.llmMessages.single.content, isNot(contains('think')));
  });

  test('a leftover conversation restores the pane without think tags', () {
    final conversation = Conversation.fromJson({
      'visible': [
        {'role': 'user', 'text': 'draw a tail'},
        {'role': 'reasoning', 'text': 'use a polyline'},
        {'role': 'assistant', 'text': 'Drew the tail.'},
      ],
      'llm': [
        {'role': 'user', 'content': 'draw a tail'},
        {'role': 'assistant', 'content': 'Drew the tail.'},
      ],
    });
    expect(conversation.visible.map((item) => item.role), [
      ChatRole.user,
      ChatRole.reasoning,
      ChatRole.assistant,
    ]);
    expect(conversation.llmMessages.last.content, 'Drew the tail.');
    expect(conversation.llmMessages.last.content, isNot(contains('think')));
    expect(conversation.toJson()['visible'], isNot(contains('think')));
  });

  test('whitespace-only model content stays off the panel', () {
    final conversation = Conversation();
    conversation.addAssistantLlm(const LlmMessage.assistant('  \n'));

    expect(conversation.visible, isEmpty);
    expect(conversation.llmMessages, hasLength(1));
    expect(conversation.llmMessages.single.content, '  \n');
  });
}
