// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fidelity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$FidelityReportToJson(FidelityReport instance) =>
    <String, dynamic>{
      'sourceEntities': instance.sourceEntities,
      'targetEntities': instance.targetEntities,
      'missingByKind': instance.missingByKind,
      'extraByKind': instance.extraByKind,
      'missingLayers': instance.missingLayers,
      'missingBySpace': instance.missingBySpace,
      'extraBySpace': instance.extraBySpace,
      'missingLayouts': instance.missingLayouts,
      'extraLayouts': instance.extraLayouts,
      'layoutMismatches': instance.layoutMismatches,
      'missingXrefs': instance.missingXrefs,
      'extraXrefs': instance.extraXrefs,
      'xrefMismatches': instance.xrefMismatches,
      if (_omitEmptyNotes(instance.notes) case final value?) 'notes': value,
    };
