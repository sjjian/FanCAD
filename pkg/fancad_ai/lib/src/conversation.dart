// ignore_for_file: invalid_annotation_target

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'provider.dart';

part 'conversation.g.dart';

/// One visible item in the assistant panel.
@immutable
@JsonSerializable(includeIfNull: false)
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.toolName,
    this.isError = false,
  });

  @JsonKey(fromJson: _chatRoleFromJson, toJson: _chatRoleToJson)
  final ChatRole role;
  @JsonKey(fromJson: _stringOrEmpty)
  final String text;
  final String? toolName;
  @JsonKey(toJson: _omitFalse)
  final bool isError;

  Map<String, Object?> toJson() => _$ChatMessageToJson(this);

  factory ChatMessage.fromJson(Map<dynamic, dynamic> raw) =>
      _$ChatMessageFromJson(Map<String, dynamic>.from(raw));
}

ChatRole _chatRoleFromJson(Object? raw) {
  final roleName = '${raw ?? 'assistant'}';
  return ChatRole.values.firstWhere(
    (item) => item.name == roleName,
    orElse: () => ChatRole.assistant,
  );
}

String _chatRoleToJson(ChatRole role) => role.name;

String _stringOrEmpty(Object? raw) => raw is String ? raw : '';

bool? _omitFalse(bool value) => value ? true : null;

enum ChatRole { user, assistant, tool, system, reasoning }

/// The transcript of one assistant session.
///
/// Holds both the messages shown in the panel and the messages sent back to
/// the model. Those are not the same list: a tool result is collapsed in the
/// UI and expanded for the next completion.
@JsonSerializable(createFactory: false)
class Conversation {
  Conversation();

  @JsonKey(name: 'llm', toJson: _llmListToJson)
  final List<LlmMessage> llmMessages = [];
  @JsonKey(toJson: _chatListToJson)
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
    String? toolName,
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
        toolName: toolName ?? call.name,
        isError: isError,
      ),
    );
  }

  void clear() {
    llmMessages.clear();
    visible.clear();
  }

  Map<String, Object?> toJson() => _$ConversationToJson(this);

  factory Conversation.fromJson(Map<dynamic, dynamic> raw) {
    final conversation = Conversation();
    conversation.visible.addAll(_chatListFromJson(raw['visible']));
    conversation.llmMessages.addAll(_llmListFromJson(raw['llm']));
    return conversation;
  }
}

List<Map<String, Object?>> _chatListToJson(List<ChatMessage> items) => [
  for (final item in items) item.toJson(),
];

List<Map<String, Object?>> _llmListToJson(List<LlmMessage> items) => [
  for (final item in items) item.toJson(),
];

List<ChatMessage> _chatListFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) ChatMessage.fromJson(item),
  ];
}

List<LlmMessage> _llmListFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) LlmMessage.fromJson(item),
  ];
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
