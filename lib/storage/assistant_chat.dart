import 'package:fancad_ai/fancad_ai.dart';

import 'settings.dart';

/// One assistant thread. The pane shows [conversation]; leftover chats
/// are stored in settings so a new session does not wipe the last one.
class AssistantChat {
  AssistantChat({
    required this.id,
    this.title = '',
    DateTime? updatedAt,
    Conversation? conversation,
    this.usage,
    this.draft = '',
  }) : updatedAt = updatedAt ?? DateTime.now(),
       conversation = conversation ?? Conversation();

  static const String defaultId = 'default';

  final String id;
  String title;
  DateTime updatedAt;
  final Conversation conversation;
  LlmUsage? usage;
  String draft;

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

/// Leftover `ai.chats` becomes a list; a missing key is one empty thread.
class AssistantChats {
  const AssistantChats._();

  static const int cap = 20;

  static List<AssistantChat> read(SettingsStore settings) {
    final raw = settings.values[SettingsKeys.aiChats];
    if (raw is List && raw.isNotEmpty) {
      final parsed = <AssistantChat>[];
      for (final item in raw) {
        if (item is Map) parsed.add(AssistantChat.fromJson(item));
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return [AssistantChat(id: AssistantChat.defaultId)];
  }

  static String activeId(SettingsStore settings, List<AssistantChat> chats) {
    final id = settings.getString(SettingsKeys.aiActiveChat);
    if (chats.any((chat) => chat.id == id)) return id;
    return chats.first.id;
  }
}

String titleFromUserMessage(String text) {
  final first = text.trim().split('\n').first.trim();
  if (first.isEmpty) return '';
  if (first.length <= 40) return first;
  return '${first.substring(0, 39)}…';
}
