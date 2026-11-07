import 'dart:typed_data';

import '../../../model/document/drawing_data.dart';
import '../../../model/entity/entity.dart';
import '../../../model/style.dart';
import '../aci_palette.dart';
import '../acis_sab.dart';
import '../dwg_reader.dart';
import 'r2000_appender.dart';
import 'r2000_writer.dart';

/// Converts a [DrawingData] into the subset the R2000 writer can encode.
///
/// The writer currently targets model space with LINE, CIRCLE, ARC, ELLIPSE,
/// SPLINE, POINT, TEXT, LWPOLYLINE and SOLID entities. Blocks, inserts and the
/// remaining entity types are reported as unsupported so callers can fall back
/// to another format instead of silently dropping geometry.
bool canWriteR2000Document(DrawingData document) {
  final modelSpace = document.modelSpaceBlockName;
  // The R2000 writer copies the template's header section. Settings that the
  // template does not already hold would be lost, so let DXF carry them.
  for (final name in const [
    'LTSCALE',
    'PDMODE',
    'PDSIZE',
    'CELTSCALE',
    'INSUNITS',
  ]) {
    final wanted = document.headerVariables['\$$name'];
    if (wanted == null) continue;
    final current = _templateHeaderVariables()[name];
    final a = double.tryParse(wanted);
    final b = current is num ? current.toDouble() : null;
    if (a == null || b == null || (a - b).abs() > 1e-9) return false;
  }
  // A paper viewport is a window into model space. The R2000 writer can copy
  // the sheet entities but cannot encode the VIEWPORT that shows the model,
  // so saving would silently produce a blank sheet.
  for (final layout in document.layouts) {
    if (!layout.isModelSpace && layout.viewports.isNotEmpty) return false;
  }
  var paperBlocks = 0;
  for (final block in document.blocks.values) {
    if (block.name == modelSpace) continue;
    if (block.isLayoutBlock) {
      if (block.entityIds.isEmpty) continue;
      paperBlocks++;
      if (paperBlocks > 1) return false;
      for (final entity in document.entitiesOf(block.name)) {
        if (!_supports(entity)) return false;
      }
      continue;
    }
    if (block.isAnonymous || block.isXref) return false;
    for (final entity in document.entitiesOf(block.name)) {
      if (!_supports(entity)) return false;
    }
  }
  for (final entity in document.entitiesOf(modelSpace)) {
    if (!_supports(entity)) return false;
    if (entity is InsertEntity) {
      final block = document.blocks[entity.blockName];
      if (block == null ||
          block.isXref ||
          block.isAnonymous ||
          block.isLayoutBlock) {
        return false;
      }
    }
  }
  for (final block in document.blocks.values) {
    for (final entity in document.entitiesOf(block.name)) {
      if (entity is InsertEntity) {
        final target = document.blocks[entity.blockName];
        if (target == null ||
            target.isXref ||
            target.isAnonymous ||
            target.isLayoutBlock) {
          return false;
        }
      }
    }
  }
  for (final entity in document.entities) {
    // R2000 has no per-entity transparency.
    if (entity.props.transparency > 0) return false;
  }
  // Table entries whose names already exist in the template cannot be
  // replaced, so a customized Continuous linetype or Standard text style
  // would silently fall back to the template's values.
  final continuous = document.lineTypes['Continuous'];
  if (continuous != null &&
      (continuous.pattern.isNotEmpty || continuous.patternLength > 0)) {
    return false;
  }
  final standardStyle = document.textStyles['Standard'];
  if (standardStyle != null && standardStyle != TextStyleDef.standard) {
    return false;
  }
  final standardDim = document.dimStyles['Standard'];
  if (standardDim != null && standardDim != DimStyleDef.standard) {
    return false;
  }
  return true;
}

Map<String, Object?>? _templateHeaders;

Map<String, Object?> _templateHeaderVariables() =>
    _templateHeaders ??= DwgReader.readBytes(
      const R2000Writer().writeEmptyTemplate(),
    ).headerVariables;

/// Encodes [document] as a valid R2000 DWG.
///
/// Call [canWriteR2000Document] first; the writer skips entities it cannot
/// represent.
Uint8List writeR2000Document(DrawingData document) {
  final entities = document.entitiesOf(document.modelSpaceBlockName);
  final items = <R2000WriteItem>[
    for (final entity in entities) ?_item(entity, document),
  ];
  final blocks = <String, List<R2000WriteItem>>{
    for (final block in document.blocks.values)
      if (block.name != document.modelSpaceBlockName && !block.isLayoutBlock)
        block.name: [
          for (final entity in document.entitiesOf(block.name))
            ?_item(entity, document),
        ],
  };
  final basePoints = <String, (double, double)>{
    for (final block in document.blocks.values)
      if (block.name != document.modelSpaceBlockName && !block.isLayoutBlock)
        block.name: (block.basePoint.x, block.basePoint.y),
  };
  final paperItems = <R2000WriteItem>[
    for (final block in document.blocks.values)
      if (block.isLayoutBlock &&
          block.name != document.modelSpaceBlockName &&
          block.entityIds.isNotEmpty)
        for (final entity in document.entitiesOf(block.name))
          ?_item(entity, document),
  ];
  final colors = <String, int>{};
  final flags = <String, int>{};
  final layerLineTypes = <String, String>{};
  for (final layer in document.layers.values) {
    layerLineTypes[layer.name] = layer.lineType;
    colors[layer.name] = switch (layer.color.kind) {
      ColorKind.indexed => layer.color.value,
      // R2000 layers only carry an ACI; use the closest one rather than
      // repainting every true-colour layer white.
      ColorKind.trueColor => nearestAciIndexForRgb(layer.color.value),
      _ => 7,
    };
    var flag0 = 0;
    if (layer.frozen) flag0 |= 1;
    if (!layer.visible) flag0 |= 2;
    if (layer.locked) flag0 |= 8;
    if (layer.plottable) flag0 |= 16;
    flag0 |= (LineWeight.toDwgLayer(layer.lineWeight) & 0x1f) << 5;
    flags[layer.name] = flag0;
  }
  final textStyleDefs =
      <
        String,
        ({
          String font,
          String bigFont,
          double height,
          double widthFactor,
          double oblique,
          int generation,
        })
      >{
        for (final style in document.textStyles.values)
          style.name.toUpperCase(): (
            font: style.fontFamily,
            bigFont: style.bigFontFamily,
            height: style.height,
            widthFactor: style.widthFactor,
            oblique: style.obliqueAngle,
            generation: (style.backwards ? 2 : 0) | (style.upsideDown ? 4 : 0),
          ),
      };
  final lineTypeDefs =
      <String, ({String description, List<double> pattern, double length})>{
        for (final lineType in document.lineTypes.values)
          lineType.name.toUpperCase(): (
            description: lineType.description,
            pattern: lineType.pattern,
            length: lineType.patternLength,
          ),
      };
  final dimStyleDefs =
      <
        String,
        ({
          double textHeight,
          double arrowSize,
          double extensionLineOffset,
          double extensionLineExtend,
          double textGap,
          double scale,
          int decimalPlaces,
          String textStyle,
        })
      >{
        for (final style in document.dimStyles.values)
          style.name.toUpperCase(): (
            textHeight: style.textHeight,
            arrowSize: style.arrowSize,
            extensionLineOffset: style.extensionLineOffset,
            extensionLineExtend: style.extensionLineExtend,
            textGap: style.textGap,
            scale: style.scale,
            decimalPlaces: style.decimalPlaces,
            textStyle: style.textStyle,
          ),
      };
  return const R2000Appender().appendItems(
    items,
    paperItems: paperItems,
    layerColors: colors,
    layerFlags: flags,
    layerLineTypes: layerLineTypes,
    lineTypeDefs: lineTypeDefs,
    textStyleDefs: textStyleDefs,
    dimStyleDefs: dimStyleDefs,
    blocks: blocks,
    blockBasePoints: basePoints,
  );
}

bool _supports(CadEntity entity) => switch (entity) {
  LineEntity() ||
  CircleEntity() ||
  ArcEntity() ||
  EllipseEntity() ||
  PointEntity() ||
  TextEntity() ||
  MTextEntity() ||
  AttribEntity() ||
  AttdefEntity() ||
  RayEntity() ||
  XLineEntity() ||
  LeaderEntity() ||
  MLeaderEntity() ||
  WipeoutEntity() => true,
  SolidEntity() => true,
  PolylineEntity() => true,
  SplineEntity() => entity.controlPointCount >= 2,
  DimensionEntity() =>
    _dimensionPoints(entity.dimensionType & 0x0f) != null &&
        entity.definitionPoints.length >=
            (_dimensionPoints(entity.dimensionType & 0x0f) ?? 0),
  HatchEntity() =>
    entity.loops.isNotEmpty && (entity.solid || entity.patternLines.isNotEmpty),
  ImageEntity() => entity.reference.isNotEmpty,
  RegionEntity() => _regionSat(entity) != null,
  InsertEntity() =>
    entity.columnCount >= 1 &&
        entity.columnCount <= 10000 &&
        entity.rowCount >= 1 &&
        entity.rowCount <= 10000,
  _ => false,
};

R2000WriteItem? _item(CadEntity entity, DrawingData document) {
  final item = switch (entity) {
    LineEntity() => R2000WriteItem.line(
      entity.start.x,
      entity.start.y,
      entity.end.x,
      entity.end.y,
    ),
    CircleEntity() => R2000WriteItem.circle(
      entity.center.x,
      entity.center.y,
      entity.radius,
    ),
    ArcEntity() => R2000WriteItem.arc(
      entity.center.x,
      entity.center.y,
      entity.radius,
      entity.startAngle,
      entity.endAngle,
    ),
    EllipseEntity() => R2000WriteItem.ellipse(
      entity.center.x,
      entity.center.y,
      entity.majorAxis.x,
      entity.majorAxis.y,
      entity.ratio,
      start: entity.startParam,
      end: entity.endParam,
    ),
    PointEntity() => R2000WriteItem.point(entity.position.x, entity.position.y),
    TextEntity() => R2000WriteItem.text(
      entity.position.x,
      entity.position.y,
      entity.height,
      entity.rotation,
      entity.content,
      widthFactor: entity.widthFactor,
      oblique: entity.obliqueAngle,
      hAlign: entity.hAlign.index,
      vAlign: entity.vAlign.index,
    ),
    MTextEntity() => R2000WriteItem.mtext(
      entity.position.x,
      entity.position.y,
      entity.height,
      entity.rotation,
      entity.rectangleWidth,
      entity.content,
      attachment: entity.attachment,
    ),
    AttribEntity() => R2000WriteItem.attrib(
      entity.position.x,
      entity.position.y,
      entity.height,
      entity.rotation,
      entity.value,
      entity.tag,
      flags: entity.invisible ? 1 : 0,
      widthFactor: entity.widthFactor,
      hAlign: entity.hAlign.index,
      vAlign: entity.vAlign.index,
    ),
    AttdefEntity() => R2000WriteItem.attdef(
      entity.position.x,
      entity.position.y,
      entity.height,
      entity.rotation,
      entity.defaultValue,
      entity.tag,
      entity.prompt,
      flags:
          (entity.invisible ? 1 : 0) |
          (entity.constant ? 2 : 0) |
          (entity.verify ? 4 : 0) |
          (entity.preset ? 8 : 0),
      widthFactor: entity.widthFactor,
      hAlign: entity.hAlign.index,
      vAlign: entity.vAlign.index,
    ),
    RayEntity() => R2000WriteItem.ray(
      entity.origin.x,
      entity.origin.y,
      entity.direction.x,
      entity.direction.y,
    ),
    XLineEntity() => R2000WriteItem.xline(
      entity.origin.x,
      entity.origin.y,
      entity.direction.x,
      entity.direction.y,
    ),
    LeaderEntity() => R2000WriteItem.leader(
      entity.vertices.toList(),
      arrow: entity.hasArrowHead,
    ),
    WipeoutEntity() => R2000WriteItem.wipeout(
      entity.clipVertices.toList(),
      originX: entity.origin.x,
      originY: entity.origin.y,
      ux: entity.uVector.x,
      uy: entity.uVector.y,
      vx: entity.vVector.x,
      vy: entity.vVector.y,
      frame: entity.frame,
    ),
    MLeaderEntity() => R2000WriteItem.mleader(
      _mleaderPaths(entity),
      entity.content,
      textX: entity.textPosition.x,
      textY: entity.textPosition.y,
      textHeight: entity.textHeight,
      textRotation: entity.textRotation,
      attachment: entity.attachment,
    ),
    RegionEntity() => R2000WriteItem.region(
      _regionSat(entity)!,
      solid: entity.source?.sourceType == '3DSOLID',
    ),
    ImageEntity() => R2000WriteItem.image(
      entity.origin.x,
      entity.origin.y,
      entity.uVector.x,
      entity.uVector.y,
      entity.vVector.x,
      entity.vVector.y,
      entity.reference,
    ),
    HatchEntity() => R2000WriteItem.hatch(
      [
        for (final loop in entity.loops)
          if (loop.pointCount >= 2) loop.vertices.toList(),
      ],
      solid: entity.solid,
      name: entity.solid ? 'SOLID' : entity.patternName,
      angle: entity.patternAngle,
      scale: entity.patternScale,
      patternLines: [
        for (final line in entity.patternLines)
          [
            line.angle,
            line.originX,
            line.originY,
            line.deltaX,
            line.deltaY,
            line.dashes.length.toDouble(),
            ...line.dashes,
          ],
      ],
    ),
    DimensionEntity() => R2000WriteItem.dimension(
      entity.dimensionType & 0x0f,
      [
        for (final point in entity.definitionPoints) ...[point.x, point.y],
      ],
      textX: entity.textPosition.x,
      textY: entity.textPosition.y,
      measurement: entity.measurement,
      text: entity.overrideText,
      scaleX: entity.blockScale.x,
      scaleY: entity.blockScale.y,
      insRotation: entity.blockRotation,
      cloneX: entity.blockTranslation.x,
      cloneY: entity.blockTranslation.y,
      dimStyle: entity.styleName,
    ),
    InsertEntity() => R2000WriteItem.insert(
      entity.position.x,
      entity.position.y,
      entity.blockName,
      scale: entity.scale.x,
      scaleY: entity.scale.y,
      rotation: entity.rotation,
      attributes: _insertAttributes(entity, document),
      columnCount: entity.columnCount,
      rowCount: entity.rowCount,
      columnSpacing: entity.columnSpacing,
      rowSpacing: entity.rowSpacing,
    ),
    SolidEntity() => R2000WriteItem.solid(_solidCorners(entity)),
    PolylineEntity() => R2000WriteItem.lwPolyline(
      _polylinePoints(entity),
      closed: entity.closed,
      bulges: _polylineBulges(entity),
      constantWidth: entity.constantWidth,
    ),
    SplineEntity() => R2000WriteItem.spline(
      knots: entity.knots,
      controlPoints: entity.controlPoints.toList(),
      weights: entity.weights,
      degree: entity.degree,
      closed: entity.closed,
    ),
    _ => null,
  };
  final props = entity.props;
  return item
      ?.withLayer(props.layer)
      .withAppearance(
        colorIndex: _colorIndex(props.color),
        visible: props.visible,
        lineWeight: _lineWeight(props.lineWeight),
        lineType: props.lineType,
        lineTypeScale: props.lineTypeScale,
        textStyle: entity is TextLike ? entity.styleName : 'Standard',
      );
}

int _colorIndex(CadColor color) => switch (color.kind) {
  ColorKind.indexed => color.value.clamp(0, 255),
  ColorKind.byBlock => 0,
  // R2000 cannot store a true colour, so approximate it with the nearest ACI
  // instead of silently turning the entity ByLayer.
  ColorKind.trueColor => nearestAciIndexForRgb(color.value),
  _ => 256,
};

int _lineWeight(int weight) => switch (weight) {
  LineWeight.byLayer => 29,
  LineWeight.byBlock => 30,
  LineWeight.byDefault => 31,
  _ => weight.clamp(0, 211),
};

List<R2000Attribute> _insertAttributes(
  InsertEntity insert,
  DrawingData document,
) {
  final block = document.blocks[insert.blockName];
  if (block == null) return const [];
  final transform = insert.transformFor(0, 0);
  final result = <R2000Attribute>[];
  for (final attdef in document.attdefsOf(insert.blockName)) {
    if (attdef.constant) continue;
    final position = transform.transform(attdef.position);
    result.add(
      R2000Attribute(
        tag: attdef.tag,
        value: insert.attributes[attdef.tag] ?? attdef.defaultValue,
        x: position.x,
        y: position.y,
        height: attdef.height * insert.scale.y.abs(),
        rotation: attdef.rotation + insert.rotation,
        flags:
            (attdef.invisible ? 1 : 0) |
            (attdef.constant ? 2 : 0) |
            (attdef.verify ? 4 : 0) |
            (attdef.preset ? 8 : 0),
        widthFactor: attdef.widthFactor,
        hAlign: attdef.hAlign.index,
        vAlign: attdef.vAlign.index,
      ),
    );
  }
  return result;
}

List<List<double>> _mleaderPaths(MLeaderEntity entity) {
  final vertices = entity.vertices;
  if (entity.pathLengths.isEmpty) {
    return vertices.length < 4 ? const [] : [vertices.toList()];
  }
  final paths = <List<double>>[];
  var start = 0;
  for (final count in entity.pathLengths) {
    final from = start * 2;
    final to = from + count * 2;
    if (from < 0 || to > vertices.length) break;
    paths.add(vertices.sublist(from, to));
    start += count;
  }
  return paths;
}

String? _regionSat(RegionEntity entity) {
  final source = entity.source;
  if (source == null) return null;
  final text = source.format == 'sab' ? sabToSat1(source.bytes) : source.text;
  if (text == null || text.isEmpty) return null;
  return text;
}

/// Minimum definition-point count for each dimension family, or null when the
/// family is not one of the seven R2000 dimension types.
int? _dimensionPoints(int family) => switch (family) {
  0 || 1 => 3,
  2 => 5,
  3 || 4 => 2,
  5 => 4,
  6 => 3,
  _ => null,
};

List<double> _polylinePoints(PolylineEntity entity) => [
  for (var i = 0; i < entity.vertexCount; i++) ...[
    entity.vertexAt(i).x,
    entity.vertexAt(i).y,
  ],
];

List<double> _polylineBulges(PolylineEntity entity) => [
  for (var i = 0; i < entity.vertexCount; i++) entity.bulgeAt(i),
];

List<double> _solidCorners(SolidEntity entity) {
  if (entity.corners.isEmpty) return const [0, 0, 0, 0, 0, 0, 0, 0];
  final corners = [
    for (final corner in entity.corners) ...[corner.x, corner.y],
  ];
  while (corners.length < 8) {
    corners
      ..add(corners[corners.length - 2])
      ..add(corners[corners.length - 1]);
  }
  return corners;
}
