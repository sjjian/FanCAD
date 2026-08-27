// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EntityProps _$EntityPropsFromJson(Map<String, dynamic> json) => _EntityProps(
  layer: json['layer'] as String? ?? '0',
  color: json['color'] == null
      ? const CadColor.byLayer()
      : cadColorFromJson(json['color']),
  lineType: json['lineType'] as String? ?? 'ByLayer',
  lineWeight: (json['lineWeight'] as num?)?.toInt() ?? LineWeight.byLayer,
  lineTypeScale: (json['lineTypeScale'] as num?)?.toDouble() ?? 1,
  transparency: (json['transparency'] as num?)?.toInt() ?? -1,
  visible: json['visible'] as bool? ?? true,
  elevation: (json['elevation'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$EntityPropsToJson(
  _EntityProps instance,
) => <String, dynamic>{
  'layer': instance.layer,
  if (cadColorToJson(instance.color) case final value?) 'color': value,
  if (_omitByLayerName(instance.lineType) case final value?) 'lineType': value,
  if (_omitByLayerWeight(instance.lineWeight) case final value?)
    'lineWeight': value,
  if (_omitOne(instance.lineTypeScale) case final value?)
    'lineTypeScale': value,
  if (_omitMinusOne(instance.transparency) case final value?)
    'transparency': value,
  if (_omitTrue(instance.visible) case final value?) 'visible': value,
  if (_omitZero(instance.elevation) case final value?) 'elevation': value,
};
