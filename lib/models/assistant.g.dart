// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$AssistantChatModelToJson(_AssistantChatModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'draft': instance.draft,
    };

_AssistantProfileModel _$AssistantProfileModelFromJson(
  Map<String, dynamic> json,
) => _AssistantProfileModel(
  id: json['id'] as String,
  label: json['label'] as String? ?? '',
  model: json['model'] as String? ?? 'gpt-4o-mini',
  baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
  apiKey: json['apiKey'] as String? ?? '',
);

Map<String, dynamic> _$AssistantProfileModelToJson(
  _AssistantProfileModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'model': instance.model,
  'baseUrl': instance.baseUrl,
  'apiKey': instance.apiKey,
};
