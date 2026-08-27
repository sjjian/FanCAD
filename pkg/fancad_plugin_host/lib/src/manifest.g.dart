// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginManifestToJson(PluginManifest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'version': instance.version,
      'main': instance.entryPoint,
      if (_omitEmptyString(instance.publisher) case final value?)
        'publisher': value,
      if (_omitEmptyString(instance.description) case final value?)
        'description': value,
      if (_hostConstraintToJson(instance.hostConstraint) case final value?)
        'engines': value,
      if (_activationToJson(instance.activation) case final value?)
        'activationEvents': value,
      if (_permissionsToJson(instance.permissions) case final value?)
        'permissions': value,
    };
