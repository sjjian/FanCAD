// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$LineEntityToJson(LineEntity instance) =>
    <String, dynamic>{
      'start': vec2ToJson(instance.start),
      'end': vec2ToJson(instance.end),
    };

Map<String, dynamic> _$PolylineEntityToJson(PolylineEntity instance) =>
    <String, dynamic>{
      'vertices': vertexBufferToJson(instance.vertices),
      'closed': instance.closed,
      if (omitZero(instance.constantWidth) case final value?) 'width': value,
    };

Map<String, dynamic> _$CircleEntityToJson(CircleEntity instance) =>
    <String, dynamic>{
      'center': vec2ToJson(instance.center),
      'radius': instance.radius,
    };

Map<String, dynamic> _$ArcEntityToJson(ArcEntity instance) => <String, dynamic>{
  'center': vec2ToJson(instance.center),
  'radius': instance.radius,
  'startAngle': instance.startAngle,
  'endAngle': instance.endAngle,
};

Map<String, dynamic> _$EllipseEntityToJson(EllipseEntity instance) =>
    <String, dynamic>{
      'center': vec2ToJson(instance.center),
      'majorAxis': vec2ToJson(instance.majorAxis),
      'ratio': instance.ratio,
      'startParam': instance.startParam,
      'endParam': instance.endParam,
    };

Map<String, dynamic> _$SplineEntityToJson(SplineEntity instance) =>
    <String, dynamic>{
      'controlPoints': pointBufferToJson(instance.controlPoints),
      if (doubleListToJsonIfNotEmpty(instance.knots) case final value?)
        'knots': value,
      if (doubleListToJsonIfNotEmpty(instance.weights) case final value?)
        'weights': value,
      'degree': instance.degree,
      if (omitFalse(instance.closed) case final value?) 'closed': value,
      if (optionalPointBufferToJson(instance.fitPoints) case final value?)
        'fitPoints': value,
    };

Map<String, dynamic> _$PointEntityToJson(PointEntity instance) =>
    <String, dynamic>{'position': vec2ToJson(instance.position)};

Map<String, dynamic> _$TextEntityToJson(TextEntity instance) =>
    <String, dynamic>{
      'position': vec2ToJson(instance.position),
      'text': instance.content,
      'height': instance.height,
      if (omitZero(instance.rotation) case final value?) 'rotation': value,
      'style': instance.styleName,
      if (omitOne(instance.widthFactor) case final value?) 'widthFactor': value,
      if (omitZero(instance.obliqueAngle) case final value?) 'oblique': value,
      if (_omitHAlign(instance.hAlign) case final value?) 'hAlign': value,
      if (_omitVAlign(instance.vAlign) case final value?) 'vAlign': value,
    };

Map<String, dynamic> _$MTextEntityToJson(MTextEntity instance) =>
    <String, dynamic>{
      'position': vec2ToJson(instance.position),
      'text': instance.content,
      'height': instance.height,
      if (omitZero(instance.rotation) case final value?) 'rotation': value,
      'style': instance.styleName,
      if (omitZero(instance.rectangleWidth) case final value?)
        'rectangleWidth': value,
      if (_omitAttachment(instance.attachment) case final value?)
        'attachment': value,
    };

Map<String, dynamic> _$DimensionEntityToJson(
  DimensionEntity instance,
) => <String, dynamic>{
  if (omitEmptyString(instance.blockName) case final value?) 'blockName': value,
  'definitionPoints': vec2ListToJson(instance.definitionPoints),
  'textPosition': vec2ToJson(instance.textPosition),
  'measurement': instance.measurement,
  if (omitEmptyString(instance.overrideText) case final value?) 'text': value,
  'style': instance.styleName,
  if (omitZero(instance.dimensionType) case final value?)
    'dimensionType': value,
  if (idListToJsonIfNotEmpty(instance.sourceIds) case final value?)
    'sourceIds': value,
};

Map<String, dynamic> _$LeaderEntityToJson(LeaderEntity instance) =>
    <String, dynamic>{
      'vertices': pointBufferToJson(instance.vertices),
      'arrowHead': instance.hasArrowHead,
      'style': instance.styleName,
    };

Map<String, dynamic> _$MLeaderEntityToJson(MLeaderEntity instance) =>
    <String, dynamic>{
      'vertices': pointBufferToJson(instance.vertices),
      if (idListToJsonIfNotEmpty(instance.pathLengths) case final value?)
        'pathLengths': value,
      'arrowHead': instance.hasArrowHead,
      if (omitEmptyString(instance.content) case final value?) 'text': value,
      'textPosition': vec2ToJson(instance.textPosition),
      if (omitZero(instance.textHeight) case final value?) 'height': value,
      if (omitZero(instance.textRotation) case final value?) 'rotation': value,
      'style': instance.styleName,
    };

Map<String, dynamic> _$HatchEntityToJson(
  HatchEntity instance,
) => <String, dynamic>{
  'loops': _hatchLoopsToJson(instance.loops),
  'pattern': instance.patternName,
  'solid': instance.solid,
  if (omitZero(instance.patternAngle) case final value?) 'patternAngle': value,
  if (omitOne(instance.patternScale) case final value?) 'patternScale': value,
};

Map<String, dynamic> _$InsertEntityToJson(InsertEntity instance) =>
    <String, dynamic>{
      'blockName': instance.blockName,
      'position': vec2ToJson(instance.position),
      if (scaleToJson(instance.scale) case final value?) 'scale': value,
      if (omitZero(instance.rotation) case final value?) 'rotation': value,
      if (omitOne(instance.columnCount) case final value?) 'columnCount': value,
      if (omitOne(instance.rowCount) case final value?) 'rowCount': value,
      if (omitZero(instance.columnSpacing) case final value?)
        'columnSpacing': value,
      if (omitZero(instance.rowSpacing) case final value?) 'rowSpacing': value,
    };

Map<String, dynamic> _$SolidEntityToJson(SolidEntity instance) =>
    <String, dynamic>{'corners': vec2ListToJson(instance.corners)};

Map<String, dynamic> _$RayEntityToJson(RayEntity instance) => <String, dynamic>{
  'origin': vec2ToJson(instance.origin),
  'direction': vec2ToJson(instance.direction),
};

Map<String, dynamic> _$XLineEntityToJson(XLineEntity instance) =>
    <String, dynamic>{
      'origin': vec2ToJson(instance.origin),
      'direction': vec2ToJson(instance.direction),
    };

Map<String, dynamic> _$ImageEntityToJson(ImageEntity instance) =>
    <String, dynamic>{
      'reference': instance.reference,
      'origin': vec2ToJson(instance.origin),
      'u': vec2ToJson(instance.uVector),
      'v': vec2ToJson(instance.vVector),
    };

Map<String, dynamic> _$UnknownEntityToJson(UnknownEntity instance) =>
    <String, dynamic>{
      'originalType': instance.originalType,
      if (proxyBoundsToJson(instance.proxyBounds) case final value?)
        'proxyBounds': value,
      if (pointBufferToJsonIfNotEmpty(instance.strokes) case final value?)
        'strokes': value,
      if (idListToJsonIfNotEmpty(instance.strokeCounts) case final value?)
        'strokeCounts': value,
    };
