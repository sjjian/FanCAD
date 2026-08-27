// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  role: _chatRoleFromJson(json['role']),
  text: _stringOrEmpty(json['text']),
  toolName: json['toolName'] as String?,
  isError: json['isError'] as bool? ?? false,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'role': _chatRoleToJson(instance.role),
      'text': instance.text,
      if (instance.toolName case final value?) 'toolName': value,
      if (_omitFalse(instance.isError) case final value?) 'isError': value,
    };

Map<String, dynamic> _$ConversationToJson(Conversation instance) =>
    <String, dynamic>{
      'llm': _llmListToJson(instance.llmMessages),
      'visible': _chatListToJson(instance.visible),
    };
