// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AssistantProfile _$AssistantProfileFromJson(Map<String, dynamic> json) =>
    _AssistantProfile(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      model: json['model'] as String? ?? 'gpt-4o-mini',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
      apiKey: json['apiKey'] as String? ?? '',
    );

Map<String, dynamic> _$AssistantProfileToJson(_AssistantProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'model': instance.model,
      'baseUrl': instance.baseUrl,
      'apiKey': instance.apiKey,
    };
