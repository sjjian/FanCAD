// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$CommandResultToJson(CommandResult instance) =>
    <String, dynamic>{
      'status': _statusName(instance.status),
      if (omitEmptyString(instance.message) case final value?) 'message': value,
      if (instance.data case final value?) 'data': value,
      if (_transactionChange(instance.transaction) case final value?)
        'change': value,
    };

Map<String, dynamic> _$CommandDescriptorToJson(CommandDescriptor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'category': instance.category,
      if (omitEmptyString(instance.description) case final value?)
        'description': value,
      'params': _paramsToJson(instance.params),
      if (_omitEmptyStringList(instance.aliases) case final value?)
        'aliases': value,
      'risk': _riskName(instance.risk),
      if (omitEmptyString(instance.extensionId) case final value?)
        'extensionId': value,
    };
