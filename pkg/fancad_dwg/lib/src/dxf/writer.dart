import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

/// Writes a drawing as ASCII DXF R2000.
///
/// DXF is the interchange format that does not depend on LibreDWG. A save
/// that cannot produce DWG still produces a file AutoCAD, LibreCAD and every
/// other tool in the ecosystem can open, which is the difference between
/// "FanCAD drawings are trapped" and "FanCAD drawings travel".
class DxfWriter {
  const DxfWriter();

  String writeString(CadDocument document, {String acadVer = 'AC1015'}) {
    final out = StringBuffer();
    void pair(int code, Object value) {
      out.writeln(code);
      out.writeln(value);
    }

    pair(0, 'SECTION');
    pair(2, 'HEADER');
    pair(9, r'$ACADVER');
    pair(1, acadVer);
    pair(9, r'$INSUNITS');
    pair(70, int.tryParse(document.headerVariables[r'$INSUNITS'] ?? '0') ?? 0);
    pair(9, r'$CLAYER');
    pair(8, document.currentLayer);
    pair(0, 'ENDSEC');

    pair(0, 'SECTION');
    pair(2, 'TABLES');
    _layers(pair, document);
    pair(0, 'ENDSEC');

    pair(0, 'SECTION');
    pair(2, 'BLOCKS');
    for (final block in document.blocks.values) {
      pair(0, 'BLOCK');
      pair(2, block.name);
      var flags = 0;
      if (block.isAnonymous) flags |= 1;
      if (block.isXref) flags |= 4;
      pair(70, flags);
      pair(10, block.basePoint.x);
      pair(20, block.basePoint.y);
      pair(30, 0);
      if (block.xrefPath.isNotEmpty) pair(1, block.xrefPath);
      // Model-space entities live in ENTITIES. Paper-space entities and
      // viewports stay in their layout block so a reader that walks both
      // sections does not double the model.
      if (block.name != document.modelSpaceBlockName) {
        for (final entity in document.entitiesOf(block.name)) {
          _entity(pair, entity, paperSpace: block.isLayoutBlock);
        }
        if (block.isLayoutBlock) {
          _viewports(pair, document, block.name);
        }
      }
      pair(0, 'ENDBLK');
    }
    pair(0, 'ENDSEC');

    pair(0, 'SECTION');
    pair(2, 'ENTITIES');
    for (final entity in document.entitiesOf(document.modelSpaceBlockName)) {
      _entity(pair, entity);
    }
    pair(0, 'ENDSEC');

    pair(0, 'SECTION');
    pair(2, 'OBJECTS');
    for (final layout in document.layouts) {
      pair(0, 'LAYOUT');
      pair(100, 'AcDbPlotSettings');
      pair(44, layout.paperWidth);
      pair(45, layout.paperHeight);
      pair(100, 'AcDbLayout');
      pair(1, layout.name);
      pair(2, layout.blockName);
      pair(71, layout.tabOrder);
    }
    pair(0, 'ENDSEC');
    pair(0, 'EOF');
    return out.toString();
  }

  Future<void> writeFile(String path, CadDocument document) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(writeString(document), encoding: utf8);
  }

  void _layers(void Function(int, Object) pair, CadDocument document) {
    pair(0, 'TABLE');
    pair(2, 'LAYER');
    pair(70, document.layers.length);
    for (final layer in document.layers.values) {
      pair(0, 'LAYER');
      pair(2, layer.name);
      pair(70, (layer.frozen ? 1 : 0) | (layer.locked ? 4 : 0));
      pair(62, _aci(layer.color));
      pair(6, layer.lineType);
    }
    pair(0, 'ENDTAB');
  }

  void _viewports(
    void Function(int, Object) pair,
    CadDocument document,
    String blockName,
  ) {
    var id = 2;
    for (final layout in document.layouts) {
      if (layout.blockName != blockName) continue;
      for (final viewport in layout.viewports) {
        pair(0, 'VIEWPORT');
        pair(8, viewport.layer);
        pair(10, viewport.paperBounds.center.x);
        pair(20, viewport.paperBounds.center.y);
        pair(30, 0);
        pair(40, viewport.paperBounds.width);
        pair(41, viewport.paperBounds.height);
        pair(68, viewport.isOn ? 1 : 0);
        pair(69, id++);
        pair(12, viewport.modelCenter.x);
        pair(22, viewport.modelCenter.y);
        final scale = viewport.scale;
        pair(
          45,
          scale == 0 ? viewport.paperBounds.height : viewport.paperBounds.height / scale,
        );
        if (viewport.rotation != 0) {
          pair(50, viewport.rotation * 180 / math.pi);
        }
        var flags = 0;
        if (viewport.locked) flags |= 16384;
        if (!viewport.isOn) flags |= 131072;
        if (flags != 0) pair(90, flags);
      }
    }
  }

  void _entity(
    void Function(int, Object) pair,
    CadEntity entity, {
    bool paperSpace = false,
  }) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        pair(0, 'LINE');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, start.x);
        pair(20, start.y);
        pair(11, end.x);
        pair(21, end.y);
      case CircleEntity(:final center, :final radius):
        pair(0, 'CIRCLE');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, center.x);
        pair(20, center.y);
        pair(40, radius);
      case ArcEntity(:final center, :final radius, :final startAngle, :final endAngle):
        pair(0, 'ARC');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, center.x);
        pair(20, center.y);
        pair(40, radius);
        pair(50, startAngle * 180 / math.pi);
        pair(51, endAngle * 180 / math.pi);
      case PolylineEntity():
        pair(0, 'LWPOLYLINE');
        _common(pair, entity, paperSpace: paperSpace);
        pair(90, entity.vertexCount);
        pair(70, entity.closed ? 1 : 0);
        for (var i = 0; i < entity.vertexCount; i++) {
          final p = entity.vertexAt(i);
          pair(10, p.x);
          pair(20, p.y);
          final bulge = entity.bulgeAt(i);
          if (bulge != 0) pair(42, bulge);
        }
      case PointEntity(:final position):
        pair(0, 'POINT');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, position.x);
        pair(20, position.y);
      case TextEntity():
        pair(0, 'TEXT');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, entity.position.x);
        pair(20, entity.position.y);
        pair(40, entity.height);
        pair(1, entity.content);
        if (entity.rotation != 0) {
          pair(50, entity.rotation * 180 / math.pi);
        }
        pair(7, entity.styleName);
      case MTextEntity():
        pair(0, 'MTEXT');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, entity.position.x);
        pair(20, entity.position.y);
        pair(40, entity.height);
        pair(41, entity.rectangleWidth);
        pair(1, entity.content);
        pair(71, entity.attachment);
        pair(7, entity.styleName);
      case InsertEntity():
        pair(0, entity.isArray ? 'MINSERT' : 'INSERT');
        _common(pair, entity, paperSpace: paperSpace);
        pair(2, entity.blockName);
        pair(10, entity.position.x);
        pair(20, entity.position.y);
        pair(41, entity.scale.x);
        pair(42, entity.scale.y);
        if (entity.rotation != 0) {
          pair(50, entity.rotation * 180 / math.pi);
        }
        if (entity.isArray) {
          pair(70, entity.columnCount);
          pair(71, entity.rowCount);
          pair(44, entity.columnSpacing);
          pair(45, entity.rowSpacing);
        }
      case EllipseEntity():
        pair(0, 'ELLIPSE');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, entity.center.x);
        pair(20, entity.center.y);
        pair(11, entity.majorAxis.x);
        pair(21, entity.majorAxis.y);
        pair(40, entity.ratio);
        pair(41, entity.startParam);
        pair(42, entity.endParam);
      case HatchEntity():
        pair(0, 'HATCH');
        _common(pair, entity, paperSpace: paperSpace);
        pair(2, entity.patternName);
        pair(70, entity.solid ? 1 : 0);
        pair(91, entity.loops.length);
        for (final loop in entity.loops) {
          pair(92, loop.isOuter ? 1 : 0);
          pair(93, loop.pointCount);
          for (var i = 0; i < loop.pointCount; i++) {
            pair(10, loop.vertices[i * 2]);
            pair(20, loop.vertices[i * 2 + 1]);
          }
        }
      case DimensionEntity():
        pair(0, 'DIMENSION');
        _common(pair, entity, paperSpace: paperSpace);
        if (entity.blockName.isNotEmpty) pair(2, entity.blockName);
        pair(10, entity.textPosition.x);
        pair(20, entity.textPosition.y);
        pair(70, entity.dimensionType);
        pair(1, entity.overrideText);
        pair(42, entity.measurement);
        if (entity.definitionPoints.isNotEmpty) {
          pair(13, entity.definitionPoints[0].x);
          pair(23, entity.definitionPoints[0].y);
        }
        if (entity.definitionPoints.length > 1) {
          pair(14, entity.definitionPoints[1].x);
          pair(24, entity.definitionPoints[1].y);
        }
      case SolidEntity(:final corners):
        pair(0, 'SOLID');
        _common(pair, entity, paperSpace: paperSpace);
        for (var i = 0; i < 4; i++) {
          final p = i < corners.length ? corners[i] : corners.last;
          pair(10 + i, p.x);
          pair(20 + i, p.y);
        }
      case RayEntity(:final origin, :final direction):
        pair(0, 'RAY');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, origin.x);
        pair(20, origin.y);
        pair(11, direction.x);
        pair(21, direction.y);
      case XLineEntity(:final origin, :final direction):
        pair(0, 'XLINE');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, origin.x);
        pair(20, origin.y);
        pair(11, direction.x);
        pair(21, direction.y);
      case SplineEntity():
        pair(0, 'SPLINE');
        _common(pair, entity, paperSpace: paperSpace);
        var flags = 8; // planar
        if (entity.closed) flags |= 1;
        if (entity.weights.isNotEmpty) flags |= 4;
        pair(70, flags);
        pair(71, entity.degree);
        pair(72, entity.knots.length);
        pair(73, entity.controlPointCount);
        final fit = entity.fitPoints;
        if (fit != null && fit.length >= 2) {
          pair(74, fit.length ~/ 2);
        }
        for (final knot in entity.knots) {
          pair(40, knot);
        }
        for (var i = 0; i < entity.controlPointCount; i++) {
          pair(10, entity.controlPoints[i * 2]);
          pair(20, entity.controlPoints[i * 2 + 1]);
          pair(30, 0);
          if (i < entity.weights.length) pair(41, entity.weights[i]);
        }
        if (fit != null) {
          for (var i = 0; i < fit.length ~/ 2; i++) {
            pair(11, fit[i * 2]);
            pair(21, fit[i * 2 + 1]);
            pair(31, 0);
          }
        }
      case LeaderEntity():
        pair(0, 'LEADER');
        _common(pair, entity, paperSpace: paperSpace);
        pair(3, entity.styleName);
        pair(71, entity.hasArrowHead ? 1 : 0);
        pair(76, entity.vertices.length ~/ 2);
        for (var i = 0; i < entity.vertices.length ~/ 2; i++) {
          pair(10, entity.vertices[i * 2]);
          pair(20, entity.vertices[i * 2 + 1]);
          pair(30, 0);
        }
      case ImageEntity():
        pair(0, 'IMAGE');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, entity.origin.x);
        pair(20, entity.origin.y);
        pair(30, 0);
        pair(11, entity.uVector.x);
        pair(21, entity.uVector.y);
        pair(31, 0);
        pair(12, entity.vVector.x);
        pair(22, entity.vVector.y);
        pair(32, 0);
        pair(1, entity.reference);
      default:
        pair(0, 'POINT');
        _common(pair, entity, paperSpace: paperSpace);
        pair(10, 0);
        pair(20, 0);
    }
  }

  void _common(
    void Function(int, Object) pair,
    CadEntity entity, {
    bool paperSpace = false,
  }) {
    pair(5, entity.id.toRadixString(16));
    if (paperSpace) pair(67, 1);
    pair(8, entity.props.layer);
    if (entity.props.color.kind == ColorKind.indexed) {
      pair(62, entity.props.color.value);
    } else if (entity.props.color.kind == ColorKind.trueColor) {
      pair(420, entity.props.color.value);
    }
    if (entity.props.lineType != 'ByLayer') pair(6, entity.props.lineType);
  }

  static int _aci(CadColor color) =>
      color.kind == ColorKind.indexed ? color.value : 7;
}
