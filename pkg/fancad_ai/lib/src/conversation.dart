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

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    if (toolName != null) 'toolName': toolName,
    if (isError) 'isError': true,
  };

  factory ChatMessage.fromJson(Map<dynamic, dynamic> raw) {
    final roleName = '${raw['role'] ?? 'assistant'}';
    final role = ChatRole.values.firstWhere(
      (item) => item.name == roleName,
      orElse: () => ChatRole.assistant,
    );
    return ChatMessage(
      role: role,
      text: raw['text'] is String ? raw['text'] as String : '',
      toolName: raw['toolName'] is String ? raw['toolName'] as String : null,
      isError: raw['isError'] == true,
    );
  }
}

enum ChatRole { user, assistant, tool, system, reasoning }

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
    if (text.trim().isEmpty) return;
    llmMessages.add(LlmMessage.user(text));
    visible.add(ChatMessage(role: ChatRole.user, text: text));
  }

  void addAssistant(String text) {
    if (text.trim().isEmpty) return;
    visible.add(ChatMessage(role: ChatRole.assistant, text: text));
  }

  /// Grows the last thinking card as reasoning tokens arrive.
  ///
  /// Leftover reasoning stays on [visible] only. It must not join
  /// [llmMessages], or the next round would send chain-of-thought back.
  void appendReasoningDelta(String delta) {
    if (delta.isEmpty) return;
    if (visible.isNotEmpty && visible.last.role == ChatRole.reasoning) {
      final last = visible.removeLast();
      visible.add(
        ChatMessage(role: ChatRole.reasoning, text: last.text + delta),
      );
      return;
    }
    visible.add(ChatMessage(role: ChatRole.reasoning, text: delta));
  }

  /// Grows the last assistant bubble as tokens arrive. Creates one if needed.
  void appendAssistantDelta(String delta) {
    if (delta.isEmpty) return;
    if (visible.isNotEmpty && visible.last.role == ChatRole.assistant) {
      final last = visible.removeLast();
      visible.add(ChatMessage(role: ChatRole.assistant, text: last.text + delta));
      return;
    }
    visible.add(ChatMessage(role: ChatRole.assistant, text: delta));
  }

  /// Replaces a streamed assistant bubble after a non-stream fallback.
  void replaceLastAssistant(String text) {
    if (visible.isNotEmpty && visible.last.role == ChatRole.assistant) {
      visible.removeLast();
    }
    if (text.trim().isEmpty) return;
    visible.add(ChatMessage(role: ChatRole.assistant, text: text));
  }

  void addAssistantLlm(LlmMessage message) {
    final peeled = peelAssistantThinkBlocks(message.content);
    llmMessages.add(
      LlmMessage(
        role: message.role,
        content: peeled.reply,
        toolCalls: message.toolCalls,
        toolCallId: message.toolCallId,
        name: message.name,
      ),
    );
    if (visible.isNotEmpty &&
        visible.last.role == ChatRole.assistant &&
        visible.last.text == message.content) {
      visible.removeLast();
    }
    final think = peeled.think.trim();
    if (think.isNotEmpty &&
        (visible.isEmpty ||
            visible.last.role != ChatRole.reasoning ||
            visible.last.text != think)) {
      if (visible.isNotEmpty &&
          visible.last.role == ChatRole.reasoning &&
          (think.startsWith(visible.last.text) ||
              visible.last.text.startsWith(think))) {
        visible.removeLast();
      }
      if (visible.isEmpty || visible.last.role != ChatRole.reasoning) {
        visible.add(ChatMessage(role: ChatRole.reasoning, text: think));
      }
    }
    if (peeled.reply.trim().isEmpty) return;
    if (visible.isNotEmpty &&
        visible.last.role == ChatRole.assistant &&
        visible.last.text == peeled.reply) {
      return;
    }
    visible.add(ChatMessage(role: ChatRole.assistant, text: peeled.reply));
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

  Map<String, Object?> toJson() => {
    'visible': [for (final item in visible) item.toJson()],
    'llm': [for (final item in llmMessages) item.toJson()],
  };

  factory Conversation.fromJson(Map<dynamic, dynamic> raw) {
    final conversation = Conversation();
    final visible = raw['visible'];
    if (visible is List) {
      for (final item in visible) {
        if (item is Map) conversation.visible.add(ChatMessage.fromJson(item));
      }
    }
    final llm = raw['llm'];
    if (llm is List) {
      for (final item in llm) {
        if (item is Map) conversation.llmMessages.add(LlmMessage.fromJson(item));
      }
    }
    return conversation;
  }
}

/// Leftover `<think>` fences in ordinary content become a thinking card.
({String think, String reply}) peelAssistantThinkBlocks(String text) {
  final matches = RegExp(
    r'<think>([\s\S]*?)</think>',
    caseSensitive: false,
  ).allMatches(text);
  if (matches.isEmpty) {
    final open = RegExp(r'<think>', caseSensitive: false).firstMatch(text);
    if (open == null) return (think: '', reply: text);
    return (
      think: text.substring(open.end),
      reply: text.substring(0, open.start),
    );
  }
  final think = StringBuffer();
  final reply = StringBuffer();
  var last = 0;
  for (final match in matches) {
    reply.write(text.substring(last, match.start));
    think.write(match.group(1));
    last = match.end;
  }
  reply.write(text.substring(last));
  return (think: think.toString(), reply: reply.toString());
}
