// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LlmMessage _$LlmMessageFromJson(Map<String, dynamic> json) => LlmMessage(
  role: _llmRoleFromJson(json['role']),
  content: json['content'] == null ? '' : _stringOrEmpty(json['content']),
  toolCalls: json['tool_calls'] == null
      ? const []
      : _toolCallsFromJson(json['tool_calls']),
  toolCallId: json['tool_call_id'] as String?,
  name: json['name'] as String?,
);

Map<String, dynamic> _$LlmMessageToJson(
  LlmMessage instance,
) => <String, dynamic>{
  'role': _llmRoleToJson(instance.role),
  if (_omitEmptyString(instance.content) case final value?) 'content': value,
  if (_toolCallsToJson(instance.toolCalls) case final value?)
    'tool_calls': value,
  if (instance.toolCallId case final value?) 'tool_call_id': value,
  if (instance.name case final value?) 'name': value,
};

Map<String, dynamic> _$LlmToolToJson(LlmTool instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'parameters': instance.parameters,
};
