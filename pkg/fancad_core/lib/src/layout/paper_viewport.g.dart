// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paper_viewport.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaperViewport _$PaperViewportFromJson(Map<String, dynamic> json) =>
    _PaperViewport(
      paperBounds: _paperBoundsFromJson(json['paper']),
      modelCenter: _modelCenterFromJson(json['center']),
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      isOn: json['on'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      layer: json['layer'] as String? ?? '0',
      frozenLayers: json['frozen'] == null
          ? const []
          : _frozenFromJson(json['frozen']),
    );

Map<String, dynamic> _$PaperViewportToJson(
  _PaperViewport instance,
) => <String, dynamic>{
  'paper': _paperBoundsToJson(instance.paperBounds),
  'center': _modelCenterToJson(instance.modelCenter),
  'scale': instance.scale,
  if (_omitZero(instance.rotation) case final value?) 'rotation': value,
  if (_omitTrue(instance.isOn) case final value?) 'on': value,
  if (_omitFalse(instance.locked) case final value?) 'locked': value,
  if (_omitLayerZero(instance.layer) case final value?) 'layer': value,
  if (_frozenToJson(instance.frozenLayers) case final value?) 'frozen': value,
};
