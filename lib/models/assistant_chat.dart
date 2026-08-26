import 'package:fancad_ai/fancad_ai.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant_chat.freezed.dart';

/// One assistant thread. The pane shows [conversation]; leftover chats
/// are stored so a new session does not wipe the last one.
@freezed
abstract class AssistantChat with _$AssistantChat {
  const AssistantChat._();

  const factory AssistantChat.raw({
    required String id,
    @Default('') String title,
    required DateTime updatedAt,
    required Conversation conversation,
    LlmUsage? usage,
    @Default('') String draft,
  }) = _AssistantChat;

  factory AssistantChat({
    required String id,
    String title = '',
    DateTime? updatedAt,
    Conversation? conversation,
    LlmUsage? usage,
    String draft = '',
  }) {
    return AssistantChat.raw(
      id: id,
      title: title,
      updatedAt: updatedAt ?? DateTime.now(),
      conversation: conversation ?? Conversation(),
      usage: usage,
      draft: draft,
    );
  }

  static const String defaultId = 'default';

  bool get isEmpty =>
      conversation.visible.isEmpty && conversation.llmMessages.isEmpty;

  String displayTitle(String emptyLabel) {
    final named = title.trim();
    if (named.isNotEmpty) return named;
    for (final item in conversation.visible) {
      if (item.role != ChatRole.user) continue;
      return titleFromUserMessage(item.text);
    }
    return emptyLabel;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'draft': draft,
    ...conversation.toJson(),
  };

  factory AssistantChat.fromJson(Map<dynamic, dynamic> raw) {
    final id = raw['id'] is String ? raw['id'] as String : defaultId;
    final updated = raw['updatedAt'] is String
        ? DateTime.tryParse(raw['updatedAt'] as String)
        : null;
    return AssistantChat(
      id: id.trim().isEmpty ? defaultId : id,
      title: raw['title'] is String ? raw['title'] as String : '',
      updatedAt: updated,
      conversation: Conversation.fromJson(raw),
      draft: raw['draft'] is String ? raw['draft'] as String : '',
    );
  }
}

String titleFromUserMessage(String text) {
  final first = text.trim().split('\n').first.trim();
  if (first.isEmpty) return '';
  if (first.length <= 40) return first;
  return '${first.substring(0, 39)}…';
}
