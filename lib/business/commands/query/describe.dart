import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

/// A JSON description of an entity, geometry included.
///
/// Kept flat and short on purpose: this is what gets serialised into an AI
/// context, so every redundant nested object costs tokens that could have
/// been another entity.
Map<String, Object?> describeEntity(CadDocument document, CadEntity entity) {
  final box = document.boundsOfEntity(entity);
  final record = <String, Object?>{
    'id': entity.id,
    'kind': entity.kind.name,
    'layer': entity.props.layer,
    if (entity.props.color.kind != ColorKind.byLayer)
      'color': cadColorToJson(entity.props.color),
    if (box.isNotEmpty) 'bounds': [box.minX, box.minY, box.maxX, box.maxY],
  };
  switch (entity) {
    case LineEntity(:final start, :final end, :final length):
      record
        ..['start'] = [start.x, start.y]
        ..['end'] = [end.x, end.y]
        ..['length'] = length;
    case CircleEntity(:final center, :final radius):
      record
        ..['center'] = [center.x, center.y]
        ..['radius'] = radius;
    case ArcEntity(:final center, :final radius):
      record
        ..['center'] = [center.x, center.y]
        ..['radius'] = radius
        ..['startAngle'] = entity.startAngle * 180 / math.pi
        ..['endAngle'] = entity.endAngle * 180 / math.pi;
    case PolylineEntity():
      record
        ..['vertexCount'] = entity.vertexCount
        ..['closed'] = entity.closed
        ..['length'] = Construct.lengthOf(entity);
      // Small polylines are described exactly; large ones would swamp the
      // response, and the bounding box already says where they are.
      if (entity.vertexCount <= 32) {
        record['points'] = [
          for (var i = 0; i < entity.vertexCount; i++)
            [entity.vertexAt(i).x, entity.vertexAt(i).y],
        ];
      }
    case TextEntity(:final content, :final position, :final height):
      record
        ..['text'] = content
        ..['position'] = [position.x, position.y]
        ..['height'] = height;
    case MTextEntity(:final content, :final position):
      record
        ..['text'] = content
        ..['position'] = [position.x, position.y];
    case MLeaderEntity(:final content, :final textPosition):
      record
        ..['text'] = content
        ..['position'] = [textPosition.x, textPosition.y];
    case InsertEntity(:final blockName, :final position, :final attributes):
      record
        ..['block'] = blockName
        ..['position'] = [position.x, position.y];
      if (attributes.isNotEmpty) record['attributes'] = attributes;
    case AttdefEntity(:final tag, :final defaultValue, :final position):
      record
        ..['tag'] = tag
        ..['text'] = defaultValue
        ..['position'] = [position.x, position.y];
    case AttribEntity(:final tag, :final value, :final position):
      record
        ..['tag'] = tag
        ..['text'] = value
        ..['position'] = [position.x, position.y];
    case PointEntity(:final position):
      record['position'] = [position.x, position.y];
    case HatchEntity(:final patternName):
      record
        ..['pattern'] = patternName
        ..['area'] = Construct.areaOf(entity).abs();
    case DimensionEntity(:final measurement, :final displayText):
      record
        ..['measurement'] = measurement
        ..['text'] = displayText;
    default:
      break;
  }
  return record;
}
