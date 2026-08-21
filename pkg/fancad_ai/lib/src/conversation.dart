import 'package:meta/meta.dart';

import 'provider.dart';

/// One visible item in the assistant panel.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.toolName,
    this.isError = false,
  });

  final ChatRole role;
  final String text;
  final String? toolName;
  final bool isError;
}

enum ChatRole { user, assistant, tool, system }

/// The transcript of one assistant session.
///
/// Holds both the messages shown in the panel and the messages sent back to
/// the model. Those are not the same list: a tool result is collapsed in the
/// UI and expanded for the next completion.
class Conversation {
  Conversation();

  final List<LlmMessage> llmMessages = [];
  final List<ChatMessage> visible = [];

  void addUser(String text) {
    llmMessages.add(LlmMessage.user(text));
    visible.add(ChatMessage(role: ChatRole.user, text: text));
  }

  void addAssistant(String text) {
    if (text.trim().isEmpty) return;
    visible.add(ChatMessage(role: ChatRole.assistant, text: text));
  }

  void addAssistantLlm(LlmMessage message) {
    llmMessages.add(message);
    if (message.content.trim().isNotEmpty) {
      visible.add(ChatMessage(role: ChatRole.assistant, text: message.content));
    }
  }

  void addToolResult({
    required LlmToolCall call,
    required String content,
    bool isError = false,
  }) {
    llmMessages.add(
      LlmMessage.tool(
        toolCallId: call.id,
        content: content,
        name: call.name,
      ),
    );
    visible.add(
      ChatMessage(
        role: ChatRole.tool,
        text: content,
        toolName: call.name,
        isError: isError,
      ),
    );
  }

  void clear() {
    llmMessages.clear();
    visible.clear();
  }
}
