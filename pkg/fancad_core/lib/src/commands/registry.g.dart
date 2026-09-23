// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$CommandInvocationToJson(CommandInvocation instance) =>
    <String, dynamic>{
      'command': instance.commandId,
      'source': _sourceName(instance.source),
      'at': instance.startedAt.toIso8601String(),
      if (_omitEmptyArgs(instance.args) case final value?) 'args': value,
    };
