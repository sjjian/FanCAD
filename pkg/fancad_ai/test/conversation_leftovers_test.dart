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

  test('whitespace-only model content stays off the panel', () {
    final conversation = Conversation();
    conversation.addAssistantLlm(const LlmMessage.assistant('  \n'));

    expect(conversation.visible, isEmpty);
    expect(conversation.llmMessages, hasLength(1));
    expect(conversation.llmMessages.single.content, '  \n');
  });
}
