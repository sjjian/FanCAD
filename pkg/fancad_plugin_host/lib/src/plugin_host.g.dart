// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_host.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginHandleJsonToJson(_PluginHandleJson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'version': instance.version,
      'state': instance.state,
      if (instance.error case final value?) 'error': value,
      'commands': instance.commands,
    };
