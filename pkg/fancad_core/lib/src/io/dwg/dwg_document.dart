import 'dart:math' as math;
import 'dart:typed_data';

import '../../geometry/bounds.dart';
import '../../geometry/intersect.dart';
import '../../geometry/vector.dart';
import '../../model/document/block_record.dart';
import '../../model/document/drawing_data.dart';
import '../../model/document/layout.dart';
import '../../model/document/paper_viewport.dart';
import '../../model/entity/entity.dart';
import '../../model/entity/hatch_pattern_line.dart';
import '../../model/entity/text_alignment.dart';
import '../../model/style.dart';
import '../acis_sat.dart';
import 'acis_asm.dart';
import 'model.dart';

/// Turns decoded DWG entities into a [DrawingData].
///
/// Entities are grouped by their DWG owner: model space, paper space or a
/// named block. Block-definition entities are not drawn in model space.
DrawingData dwgToDocument(DwgDrawing decoded) {
  final drawing = _withUniqueBlockNames(decoded);
  final layers = <String, LayerDef>{
    for (final layer in drawing.layers.values)
      layer.name: LayerDef(
        name: layer.name,
        color: layer.trueColor != null
            ? CadColor.rgb(layer.trueColor!)
            : CadColor.indexed(layer.colorIndex.clamp(1, 255)),
        lineType: drawing.linetypes[layer.ltypeHandle]?.name ?? 'Continuous',
        lineWeight: LineWeight.fromDwgLayer(layer.lineWeight),
        visible: !layer.off,
        frozen: layer.frozen,
        locked: layer.locked,
        plottable: layer.plottable,
      ),
  };
  DwgBlock? model;
  DwgBlock? paper;
  for (final block in drawing.blocks.values) {
    final upper = block.name.toUpperCase();
    if (upper == '*MODEL_SPACE') model = block;
    if (upper == '*PAPER_SPACE' && paper == null) paper = block;
  }
  // The header names the paper block that was current when the file was
  // saved. It is not always the first one: a layout with a title block saved
  // on its own tab must keep those entities in that tab.
  final headerPaperName = _nameForHandle(
    drawing.headerVariables['BLOCK_RECORD_PSPACE'],
    drawing.blocks.values.map((block) => (block.handle, block.name)),
  );
  if (headerPaperName != null) {
    for (final block in drawing.blocks.values) {
      if (block.name == headerPaperName) paper = block;
    }
  }
  final modelName = model?.name ?? DrawingData.defaultModelSpaceBlock;

  final document = DrawingData(
    modelSpaceBlockName: modelName,
    layers: layers.isEmpty ? null : layers,
  );
  final records = <String, BlockRecord>{
    for (final block in drawing.blocks.values)
      block.name: BlockRecord(
        name: block.name,
        basePoint: Vec2(block.baseX, block.baseY),
        isLayoutBlock: block.name.toUpperCase().startsWith('*PAPER_SPACE'),
        isAnonymous:
            block.name.startsWith('*') &&
            block.name.toUpperCase() != '*PAPER_SPACE',
      ),
  }..remove(modelName);
  for (final record in records.values) {
    document.putBlock(record);
  }

  final insertHandles = <int>{
    for (final source in drawing.entities)
      if (source.typeName == 'INSERT' && source.handle > 0) source.handle,
  };
  final insertAttributes = <int, Map<String, String>>{};
  for (final source in drawing.entities) {
    if (source.typeName != 'ATTRIB' || source.tag.isEmpty) continue;
    if (!insertHandles.contains(source.ownerHandle)) continue;
    insertAttributes.putIfAbsent(
      source.ownerHandle,
      () => <String, String>{},
    )[source.tag] = source.text;
  }

  final verticesByOwner = <int, List<DwgEntity>>{};
  final vertices3dByOwner = <int, List<DwgEntity>>{};
  final pfaceVerticesByOwner = <int, List<DwgEntity>>{};
  final pfaceFacesByOwner = <int, List<DwgEntity>>{};
  for (final source in drawing.entities) {
    if (source.ownerHandle == 0) continue;
    final map = switch (source.typeName) {
      'VERTEX_2D' => verticesByOwner,
      'VERTEX_3D' => vertices3dByOwner,
      'VERTEX_PFACE' => pfaceVerticesByOwner,
      'VERTEX_PFACE_FACE' => pfaceFacesByOwner,
      _ => null,
    };
    map?.putIfAbsent(source.ownerHandle, () => <DwgEntity>[]).add(source);
  }

  // Importers add tens of thousands of entities at once. `addEntity` copies
  // the block's id list, so using it here is quadratic; collect the lists and
  // install them in one pass instead.
  final byBlock = <String, List<CadEntity>>{};
  for (final source in drawing.entities) {
    if (source.typeName == 'ATTRIB' &&
        insertHandles.contains(source.ownerHandle)) {
      continue;
    }
    if (source.typeName == 'VERTEX_2D' ||
        source.typeName == 'VERTEX_3D' ||
        source.typeName == 'VERTEX_PFACE' ||
        source.typeName == 'VERTEX_PFACE_FACE') {
      continue;
    }
    if (source.typeName == 'POLYLINE_PFACE') {
      final target = _blockNameFor(source, drawing, modelName, paper?.name);
      if (target == null) continue;
      final vertices = pfaceVerticesByOwner[source.handle] ?? const [];
      for (final face
          in pfaceFacesByOwner[source.handle] ?? const <DwgEntity>[]) {
        final solid = _pfaceFace(face, vertices, drawing);
        if (solid == null) continue;
        byBlock.putIfAbsent(target, () => <CadEntity>[]).add(solid);
      }
      continue;
    }
    var entity = switch (source.typeName) {
      'POLYLINE_2D' => _polyline2d(
        source,
        verticesByOwner[source.handle] ?? const [],
        drawing,
      ),
      'POLYLINE_3D' => _polyline3d(
        source,
        vertices3dByOwner[source.handle] ?? const [],
        drawing,
      ),
      _ => _toCadEntity(source, drawing),
    };
    if (entity == null) continue;
    if (entity is InsertEntity) {
      final attributes = insertAttributes[source.handle];
      if (attributes != null) {
        entity = entity.withAttributes({...entity.attributes, ...attributes});
      }
    }
    final target = _blockNameFor(source, drawing, modelName, paper?.name);
    if (target == null) continue;
    byBlock.putIfAbsent(target, () => <CadEntity>[]).add(entity);
  }
  for (final entry in byBlock.entries) {
    final list = entry.value;
    for (final entity in list) {
      document.registerImportedEntity(entity);
    }
    final record = records[entry.key];
    final ids = [for (final entity in list) entity.id];
    document.putBlock(
      (record ?? BlockRecord(name: entry.key)).copyWith(entityIds: ids),
    );
  }
  _installTables(document, drawing);
  _installLayouts(document, drawing, modelName);
  return document;
}

/// Builds the paper layouts from the `*Paper_Space*` blocks and turns each
/// `VIEWPORT` into the model window it describes.
void _installLayouts(
  DrawingData document,
  DwgDrawing drawing,
  String modelName,
) {
  final paperBlocks = [
    for (final block in drawing.blocks.values)
      if (block.name.toUpperCase().startsWith('*PAPER_SPACE')) block,
  ]..sort((a, b) => a.handle.compareTo(b.handle));
  if (paperBlocks.isEmpty) return;

  final headerPaper = _nameForHandle(
    drawing.headerVariables['BLOCK_RECORD_PSPACE'],
    drawing.blocks.values.map((block) => (block.handle, block.name)),
  );
  final activePaper = headerPaper ?? paperBlocks.first.name;
  final recordsByBlock = <int, DwgLayout>{
    for (final record in drawing.layouts.values)
      if (record.blockHandle != 0) record.blockHandle: record,
  };

  final viewportsByBlock = <String, List<PaperViewport>>{};
  for (final source in drawing.entities) {
    if (source.typeName != 'VIEWPORT') continue;
    final blockName = switch (source.entmode) {
      1 => activePaper,
      0 => drawing.blocks[source.ownerHandle]?.name,
      _ => null,
    };
    if (blockName == null ||
        !paperBlocks.any((block) => block.name == blockName)) {
      continue;
    }
    final viewport = _paperViewport(source, drawing);
    if (viewport == null) continue;
    final list = viewportsByBlock.putIfAbsent(blockName, () => []);
    if (!list.any((other) => _sameViewport(other, viewport))) {
      list.add(viewport);
    }
  }

  // R2004+ layouts often carry the overall paper-space "sheet" viewport
  // alongside the real model windows. It is a 1:1 copy of the whole sheet,
  // so drawing it as well would paint the model twice. Drop it only when a
  // real window exists; a layout whose sole viewport is that sheet still
  // needs to keep it.
  for (final list in viewportsByBlock.values) {
    if (list.length < 2) continue;
    list.removeWhere(
      (viewport) =>
          viewport.scale == 1 &&
          _samePoint(viewport.modelCenter, viewport.paperBounds.center),
    );
  }

  var tab = 1;
  for (final block in paperBlocks) {
    if (block.name == modelName) continue;
    final record = recordsByBlock[block.handle];
    final tabOrder = record != null && record.tabOrder > 0
        ? record.tabOrder
        : tab;
    final paperWidth = record != null && record.paperWidth > 0
        ? record.paperWidth
        : 297.0;
    final paperHeight = record != null && record.paperHeight > 0
        ? record.paperHeight
        : 210.0;
    document.addLayout(
      Layout(
        name: record != null && record.name.isNotEmpty
            ? record.name
            : 'Layout$tab',
        blockName: block.name,
        tabOrder: tabOrder,
        paperWidth: paperWidth,
        paperHeight: paperHeight,
        plotRotation: (record?.plotRotationMode ?? 0).clamp(0, 3) * 90,
        viewports: viewportsByBlock[block.name] ?? const [],
      ),
    );
    tab++;
  }
}

PaperViewport? _paperViewport(DwgEntity source, DwgDrawing drawing) {
  final v = source.values;
  if (v.length < 5) return null;
  final width = v[3];
  final height = v[4];
  if (width <= 0 || height <= 0) return null;
  final cx = v[0];
  final cy = v[1];

  var modelCenter = Vec2(cx, cy);
  var scale = 1.0;
  var rotation = 0.0;
  var isOn = true;
  var locked = false;
  if (v.length >= 29) {
    modelCenter = Vec2(v[17], v[18]);
    if (v[12] > 0) scale = height / v[12];
    rotation = v[11];
    final status = v[28].toInt();
    // Bit 5 is the viewport's on flag, bit 14 its lock flag.
    isOn = status == 0 || status & 0x20 != 0;
    locked = status & 0x4000 != 0;
  }

  final frozen = <String>[];
  for (final handle in source.frozenLayerHandles) {
    final name = drawing.layers[handle]?.name;
    if (name != null) frozen.add(name);
  }

  return PaperViewport(
    paperBounds: Bounds2(
      cx - width / 2,
      cy - height / 2,
      cx + width / 2,
      cy + height / 2,
    ),
    modelCenter: modelCenter,
    scale: scale,
    rotation: rotation,
    isOn: isOn,
    locked: locked,
    layer: drawing.layerOf(source)?.name ?? '0',
    frozenLayers: frozen,
  );
}

bool _sameViewport(PaperViewport a, PaperViewport b) =>
    a.paperBounds.min.x == b.paperBounds.min.x &&
    a.paperBounds.min.y == b.paperBounds.min.y &&
    a.paperBounds.max.x == b.paperBounds.max.x &&
    a.paperBounds.max.y == b.paperBounds.max.y &&
    a.modelCenter == b.modelCenter &&
    a.scale == b.scale &&
    a.rotation == b.rotation;

bool _samePoint(Vec2 a, Vec2 b) =>
    (a.x - b.x).abs() < 1e-9 && (a.y - b.y).abs() < 1e-9;

/// Copies the decoded symbol tables and header variables onto [document].
///
/// Until now only layers and blocks were mapped, so every drawing fell back
/// to the built-in linetypes and text styles and the default `$LTSCALE` /
/// `$PDMODE` values. The reader decodes all of them; installing them here is
/// what makes dashed linework, SHX/TTF styles and point display match the
/// file.
void _installTables(DrawingData document, DwgDrawing drawing) {
  for (final ltype in drawing.linetypes.values) {
    if (ltype.name.isEmpty) continue;
    document.putLineType(
      LineTypeDef(
        name: ltype.name,
        description: ltype.description,
        pattern: ltype.dashes,
        patternLength: ltype.patternLength,
      ),
    );
  }
  for (final style in drawing.styles.values) {
    if (style.name.isEmpty) continue;
    document.putTextStyle(
      TextStyleDef(
        name: style.name,
        fontFamily: style.fontFile.isEmpty ? 'txt' : style.fontFile,
        bigFontFamily: style.bigFontFile,
        height: style.textSize,
        widthFactor: style.widthFactor <= 0 ? 1 : style.widthFactor,
        obliqueAngle: style.obliqueAngle,
        backwards: (style.generation & 2) != 0,
        upsideDown: (style.generation & 4) != 0,
      ),
    );
  }
  for (final dimStyle in drawing.dimStyles.values) {
    if (dimStyle.name.isEmpty) continue;
    final values = dimStyle.values;
    double n(String key, double fallback) {
      final value = values[key];
      return value is num ? value.toDouble() : fallback;
    }

    document.putDimStyle(
      DimStyleDef(
        name: dimStyle.name,
        textHeight: n('DIMTXT', 2.5),
        arrowSize: n('DIMASZ', 2.5),
        extensionLineOffset: n('DIMEXO', 0.625),
        extensionLineExtend: n('DIMEXE', 1.25),
        textGap: n('DIMGAP', 0.625),
        scale: n('DIMSCALE', 1),
        decimalPlaces: n('DIMDEC', 2).round(),
        textStyle: _styleNameFor(values['DIMTXSTY'], drawing),
      ),
    );
  }

  for (final entry in drawing.headerVariables.entries) {
    final value = entry.value;
    if (value is num) {
      final number = value.toDouble();
      document.setHeaderVariable(
        '\$${entry.key}',
        number == number.roundToDouble() && number.abs() < 1e15
            ? number.toInt().toString()
            : number.toString(),
      );
    } else if (value is String) {
      document.setHeaderVariable('\$${entry.key}', value);
    }
  }

  final currentLayer = _nameForHandle(
    drawing.headerVariables['CLAYER'],
    drawing.layers.values.map((layer) => (layer.handle, layer.name)),
  );
  if (currentLayer != null) document.currentLayer = currentLayer;
  final currentTextStyle = _styleNameFor(
    drawing.headerVariables['TEXTSTYLE'],
    drawing,
  );
  if (currentTextStyle != 'Standard' ||
      drawing.headerVariables.containsKey('TEXTSTYLE')) {
    document.currentTextStyle = currentTextStyle;
  }
  final currentDimStyle = _dimStyleNameFor(
    drawing.headerVariables['DIMSTYLE'],
    drawing,
  );
  if (currentDimStyle != null) document.currentDimStyle = currentDimStyle;
}

/// The name behind a `[code, value]` handle into [entries].
String? _nameForHandle(Object? handle, Iterable<(int, String)> entries) {
  if (handle is! List || handle.length < 2) return null;
  final value = handle[1];
  if (value is! int) return null;
  for (final (key, name) in entries) {
    if (key == value) return name;
  }
  return null;
}

String _dimStyleFor(DwgEntity source, DwgDrawing drawing) {
  final name = drawing.dimStyles[source.dimStyleHandle]?.name;
  return name == null || name.isEmpty ? 'Standard' : name;
}

/// The stored anchor is the alignment point when the text is justified;
/// otherwise it is the left/baseline insertion point.
Vec2 _textAnchor(List<double> values, TextHAlign hAlign, TextVAlign vAlign) {
  if ((hAlign != TextHAlign.left || vAlign != TextVAlign.baseline) &&
      values.length > 10) {
    return Vec2(values[9], values[10]);
  }
  return Vec2(values[0], values[1]);
}

String _textStyleFor(DwgEntity source, DwgDrawing drawing) {
  final name = drawing.styles[source.textStyleHandle]?.name;
  return name == null || name.isEmpty ? 'Standard' : name;
}

String _styleNameFor(Object? handle, DwgDrawing drawing) {
  final name = _nameForHandle(
    handle,
    drawing.styles.values.map((style) => (style.handle, style.name)),
  );
  return name == null || name.isEmpty ? 'Standard' : name;
}

String? _dimStyleNameFor(Object? handle, DwgDrawing drawing) => _nameForHandle(
  handle,
  drawing.dimStyles.values.map((style) => (style.handle, style.name)),
);

PolylineEntity? _polyline3d(
  DwgEntity source,
  List<DwgEntity> vertices,
  DwgDrawing drawing,
) {
  if (vertices.isEmpty || source.values.length < 2) return null;
  final buffer = Float64List(vertices.length * 3);
  for (var i = 0; i < vertices.length; i++) {
    final v = vertices[i].values;
    if (v.length < 4) return null;
    buffer[i * 3] = v[1];
    buffer[i * 3 + 1] = v[2];
  }
  return PolylineEntity(
    id: source.handle,
    props: _props(source, drawing),
    vertices: buffer,
    closed: (source.values[1].toInt() & 1) != 0,
  );
}

SolidEntity? _pfaceFace(
  DwgEntity face,
  List<DwgEntity> vertices,
  DwgDrawing drawing,
) {
  if (face.values.length < 5) return null;
  final corners = <Vec2>[];
  for (var i = 1; i < 5; i++) {
    final index = face.values[i].toInt();
    if (index <= 0 || index > vertices.length) continue;
    final v = vertices[index - 1].values;
    if (v.length < 4) continue;
    final point = Vec2(v[1], v[2]);
    if (!corners.contains(point)) corners.add(point);
  }
  if (corners.length < 3) return null;
  return SolidEntity(
    id: face.handle,
    props: _props(face, drawing),
    corners: corners,
  );
}

PolylineEntity? _polyline2d(
  DwgEntity source,
  List<DwgEntity> vertices,
  DwgDrawing drawing,
) {
  if (vertices.isEmpty || source.values.isEmpty) return null;
  final flag = source.values.first.toInt();
  final buffer = Float64List(vertices.length * 3);
  var constantWidth = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    final v = vertices[i].values;
    if (v.length < 8) return null;
    buffer[i * 3] = v[1];
    buffer[i * 3 + 1] = v[2];
    buffer[i * 3 + 2] = v[6];
    final start = v[4];
    final end = v[5];
    if (start != end) {
      constantWidth = 0;
    } else if (i == 0) {
      constantWidth = start;
    } else if (constantWidth != start) {
      constantWidth = 0;
    }
  }
  return PolylineEntity(
    id: source.handle,
    props: _props(source, drawing),
    vertices: buffer,
    closed: (flag & 1) != 0,
    constantWidth: constantWidth,
  );
}

String? _blockNameFor(
  DwgEntity source,
  DwgDrawing drawing,
  String modelName,
  String? paperName,
) {
  if (source.entmode == 2) return modelName;
  if (source.entmode == 1) return paperName ?? modelName;
  return drawing.blocks[source.ownerHandle]?.name;
}

EntityProps _props(DwgEntity source, DwgDrawing drawing) {
  final color = source.trueColor != null
      ? CadColor.rgb(source.trueColor!)
      : switch (source.colorIndex) {
          256 => const CadColor.byLayer(),
          0 => const CadColor.byBlock(),
          final index => CadColor.indexed(index.clamp(1, 255)),
        };
  return EntityProps(
    layer: drawing.layerOf(source)?.name ?? '0',
    color: color,
    lineType: switch (source.ltypeFlags) {
      0 => 'ByLayer',
      1 => 'ByBlock',
      2 => 'Continuous',
      _ => drawing.linetypeOf(source)?.name ?? 'ByLayer',
    },
    lineWeight: LineWeight.normalize(source.lineWeight),
    lineTypeScale: source.lineTypeScale > 0 ? source.lineTypeScale : 1,
    transparency: source.alphaType == 3 && source.alpha < 255
        ? ((255 - source.alpha) * 100 / 255).clamp(0, 90).round()
        : -1,
    visible: source.visible,
  );
}

CadEntity? _toCadEntity(DwgEntity source, DwgDrawing drawing) {
  final props = _props(source, drawing);
  final v = source.values;
  final id = source.handle > 0 ? source.handle : 0;
  // Class objects carry a 500+ type number but share the fixed type's data
  // stream once the reader has decoded them.
  final typeCode = switch (source.typeName) {
    'LWPOLYLINE' => 0x4d,
    'HATCH' => 0x4e,
    _ => source.type,
  };
  if (source.typeName == 'IMAGE') {
    if (v.length < 8) return null;
    return ImageEntity(
      id: id,
      props: props,
      reference: drawing.imageDefs[source.imageDefHandle] ?? '',
      origin: Vec2(v[0], v[1]),
      uVector: Vec2(v[2] * v[6], v[3] * v[6]),
      vVector: Vec2(v[4] * v[7], v[5] * v[7]),
    );
  }
  if (source.typeName == 'REGION' ||
      source.typeName == '3DSOLID' ||
      source.typeName == 'BODY') {
    if (source.text.isEmpty && source.acisSab == null) {
      // R2013+ keeps ACIS in the AcDs blob, which is not decoded yet. Keep the
      // object visible in the tree instead of losing it.
      return UnknownEntity(id: id, props: props, originalType: source.typeName);
    }
    var geometry = readAcisRegion(source.text);
    if ((geometry == null || geometry.components.isEmpty) &&
        source.acisSab != null) {
      geometry = readAcisSabRegion(source.acisSab!);
    }
    if (geometry == null || geometry.components.isEmpty) {
      final loops = readAcisAsmLoopText(source.text);
      if (loops == null || loops.isEmpty) {
        // Keep a payload we cannot parse rather than dropping the object.
        return UnknownEntity(
          id: id,
          props: props,
          originalType: source.typeName,
        );
      }
      geometry = RegionGeometry.fromLoops(loops, approximated: true);
    }
    if (geometry.components.isEmpty) {
      return UnknownEntity(id: id, props: props, originalType: source.typeName);
    }
    final payload = source.acisSab != null
        ? AcisPayload(
            format: 'sab',
            bytes: source.acisSab!,
            sourceType: source.typeName,
          )
        : AcisPayload(
            format: 'sat',
            bytes: Uint8List.fromList(source.text.codeUnits),
            sourceType: source.typeName,
          );
    return RegionEntity(
      id: id,
      props: props,
      components: geometry.components,
      source: payload,
      approximated: geometry.approximated,
    );
  }
  if (source.typeName == 'MULTILEADER') {
    if (v.length < 6) return null;
    final count = v[5].toInt();
    final vertices = <double>[];
    for (var i = 0; i < count && 6 + i * 2 + 1 < v.length; i++) {
      vertices.add(v[6 + i * 2]);
      vertices.add(v[7 + i * 2]);
    }
    if (vertices.isEmpty) return null;
    return MLeaderEntity(
      id: id,
      props: props,
      vertices: Float64List.fromList(vertices),
      pathLengths: [count],
      content: source.text,
      textPosition: Vec2(v[0], v[1]),
      textHeight: v[2] == 0 ? 2.5 : v[2],
      textRotation: v[4],
      attachment: 4,
    );
  }
  if (source.typeName == 'ARC_DIMENSION') {
    if (v.length < 11) return null;
    final count = v[10].toInt();
    final points = <Vec2>[];
    for (var i = 0; i < count && 12 + i * 2 < v.length; i++) {
      points.add(Vec2(v[11 + i * 2], v[12 + i * 2]));
    }
    return DimensionEntity(
      id: id,
      props: props,
      blockName: drawing.blocks[source.blockHandle]?.name ?? '',
      definitionPoints: points,
      textPosition: Vec2(v[0], v[1]),
      measurement: v[2],
      overrideText: source.text,
      dimensionType: 8,
      styleName: _dimStyleFor(source, drawing),
      blockTranslation: Vec2(v[4], v[5]),
      blockScale: Vec2(v[6] == 0 ? 1 : v[6], v[7] == 0 ? 1 : v[7]),
      blockRotation: v[9],
    );
  }
  if (source.typeName == 'WIPEOUT') {
    if (v.length < 10) return null;
    return WipeoutEntity(
      id: id,
      props: props,
      origin: Vec2(v[0], v[1]),
      uVector: Vec2(v[2], v[3]),
      vVector: Vec2(v[4], v[5]),
      clipVertices: Float64List.fromList(v.sublist(8)),
    );
  }
  switch (typeCode) {
    case 0x13: // LINE
      if (v.length < 6) return null;
      return LineEntity(
        id: id,
        props: props,
        start: Vec2(v[0], v[1]),
        end: Vec2(v[3], v[4]),
      );
    case 0x07: // INSERT
      if (v.length < 7) return null;
      final block = drawing.blocks[source.blockHandle]?.name;
      if (block == null || block.isEmpty) return null;
      return InsertEntity(
        id: id,
        props: props,
        blockName: block,
        position: Vec2(v[0], v[1]),
        scale: Vec2(v[3], v[4]),
        rotation: v[6],
      );
    case 0x08: // MINSERT: an INSERT with a rectangular array
      if (v.length < 11) return null;
      final arrayBlock = drawing.blocks[source.blockHandle]?.name;
      if (arrayBlock == null || arrayBlock.isEmpty) return null;
      return InsertEntity(
        id: id,
        props: props,
        blockName: arrayBlock,
        position: Vec2(v[0], v[1]),
        scale: Vec2(v[3], v[4]),
        rotation: v[6],
        columnCount: v[7].toInt().clamp(1, 10000),
        rowCount: v[8].toInt().clamp(1, 10000),
        columnSpacing: v[9],
        rowSpacing: v[10],
      );
    case 0x1b: // POINT
      if (v.length < 3) return null;
      return PointEntity(id: id, props: props, position: Vec2(v[0], v[1]));
    case 0x12: // CIRCLE
      if (v.length < 4) return null;
      return CircleEntity(
        id: id,
        props: props,
        center: Vec2(v[0], v[1]),
        radius: v[3],
      );
    case 0x11: // ARC
      if (v.length < 6) return null;
      return ArcEntity(
        id: id,
        props: props,
        center: Vec2(v[0], v[1]),
        radius: v[3],
        startAngle: v[4],
        endAngle: v[5],
      );
    case 0x01: // TEXT
      if (v.length < 3) return null;
      final hAlign = v.length > 6 ? _textHAlign(v[6].toInt()) : TextHAlign.left;
      final vAlign = v.length > 7
          ? _textVAlign(v[7].toInt())
          : TextVAlign.baseline;
      return TextEntity(
        id: id,
        props: props,
        position: _textAnchor(v, hAlign, vAlign),
        content: source.text,
        height: v[2] == 0 ? 2.5 : v[2],
        rotation: v.length > 3 ? v[3] : 0,
        widthFactor: v.length > 4 && v[4] != 0 ? v[4] : 1,
        obliqueAngle: v.length > 5 ? v[5] : 0,
        hAlign: hAlign,
        vAlign: vAlign,
        styleName: _textStyleFor(source, drawing),
      );
    case 0x4d: // LWPOLYLINE: [count, flag, x0, y0, ..., bulges...]
      if (v.length < 4) return null;
      final count = v[0].toInt().clamp(0, 100000);
      if (count < 1 || 2 + count * 2 > v.length) return null;
      final flag = v[1].toInt();
      final buffer = Float64List(count * 3);
      var at = 2 + count * 2;
      final hasBulges = (flag & 16) != 0;
      for (var i = 0; i < count; i++) {
        buffer[i * 3] = v[2 + i * 2];
        buffer[i * 3 + 1] = v[3 + i * 2];
        buffer[i * 3 + 2] = hasBulges && at + i < v.length ? v[at + i] : 0;
      }
      if (hasBulges) at += count;
      return PolylineEntity(
        id: id,
        props: props,
        vertices: buffer,
        closed: (flag & 512) != 0,
        constantWidth: (flag & 4) != 0 && at < v.length ? v[at] : 0,
      );
    case 0x02: // ATTRIB
      if (v.length < 6) return null;
      final attribH = v.length > 6
          ? _textHAlign(v[6].toInt())
          : TextHAlign.left;
      final attribV = v.length > 7
          ? _textVAlign(v[7].toInt())
          : TextVAlign.baseline;
      return AttribEntity(
        id: id,
        props: props,
        position: _textAnchor(v, attribH, attribV),
        tag: source.tag,
        value: source.text,
        height: v[2] == 0 ? 2.5 : v[2],
        rotation: v[3],
        widthFactor: v[4] == 0 ? 1 : v[4],
        obliqueAngle: v[5],
        hAlign: attribH,
        vAlign: attribV,
        styleName: _textStyleFor(source, drawing),
        invisible: (source.attribFlags & 1) != 0,
      );
    case 0x03: // ATTDEF
      if (v.length < 6) return null;
      final attdefH = v.length > 6
          ? _textHAlign(v[6].toInt())
          : TextHAlign.left;
      final attdefV = v.length > 7
          ? _textVAlign(v[7].toInt())
          : TextVAlign.baseline;
      return AttdefEntity(
        id: id,
        props: props,
        position: _textAnchor(v, attdefH, attdefV),
        tag: source.tag,
        prompt: source.prompt,
        defaultValue: source.text,
        height: v[2] == 0 ? 2.5 : v[2],
        rotation: v[3],
        widthFactor: v[4] == 0 ? 1 : v[4],
        obliqueAngle: v[5],
        hAlign: attdefH,
        vAlign: attdefV,
        styleName: _textStyleFor(source, drawing),
        invisible: (source.attribFlags & 1) != 0,
        constant: (source.attribFlags & 2) != 0,
        verify: (source.attribFlags & 4) != 0,
        preset: (source.attribFlags & 8) != 0,
      );
    case 0x2f: // MLINE: draw the centre-line vertices
      if (v.length < 3) return null;
      final count = v[0].toInt();
      final points = <Vec2>[];
      for (var i = 0; i < count && 1 + i * 2 + 1 < v.length; i++) {
        points.add(Vec2(v[1 + i * 2], v[2 + i * 2]));
      }
      if (points.length < 2) return null;
      return PolylineEntity.fromPoints(id: id, props: props, points: points);
    case 0x14: // DIMENSION_ORDINATE
    case 0x15: // DIMENSION_LINEAR
    case 0x16: // DIMENSION_ALIGNED
    case 0x17: // DIMENSION_ANG3PT
    case 0x18: // DIMENSION_ANG2LN
    case 0x19: // DIMENSION_RADIUS
    case 0x1a: // DIMENSION_DIAMETER
      if (v.length < 11) return null;
      final count = v[10].toInt();
      final points = <Vec2>[];
      for (var i = 0; i < count && 12 + i * 2 < v.length; i++) {
        points.add(Vec2(v[11 + i * 2], v[12 + i * 2]));
      }
      final block = drawing.blocks[source.blockHandle]?.name ?? '';
      return DimensionEntity(
        id: id,
        props: props,
        blockName: block,
        definitionPoints: points,
        textPosition: Vec2(v[0], v[1]),
        measurement: v[2],
        overrideText: source.text,
        dimensionType: v[3].toInt(),
        styleName: _dimStyleFor(source, drawing),
        blockTranslation: Vec2(v[4], v[5]),
        blockScale: Vec2(v[6] == 0 ? 1 : v[6], v[7] == 0 ? 1 : v[7]),
        blockRotation: v[9],
      );
    case 0x4e: // HATCH
      if (v.length < 4) return null;
      final solid = v[0] != 0;
      final angle = v[1];
      final scale = v[2];
      final numPaths = v[3].toInt();
      var at = 4;
      final loops = <HatchLoop>[];
      for (var p = 0; p < numPaths && at < v.length; p++) {
        final count = v[at++].toInt();
        if (count < 0 || at + count * 2 > v.length) return null;
        final flag = p < source.hatchPathFlags.length
            ? source.hatchPathFlags[p]
            : (p == 0 ? 1 : 0);
        loops.add(
          HatchLoop(
            vertices: Float64List.fromList(v.sublist(at, at + count * 2)),
            // Bit 1 is the external/outer boundary bit. A hatch may have
            // several separate islands, not just one first outer loop.
            isOuter: (flag & 1) != 0,
          ),
        );
        at += count * 2;
      }
      if (loops.isEmpty) return null;
      // A hatch may have several islands and nested holes. The path flags
      // only say "external"; the even-odd nesting depth is what decides which
      // rings are filled and which are cut out.
      if (loops.length > 1) {
        final filled = <HatchLoop>[];
        for (var i = 0; i < loops.length; i++) {
          final loop = loops[i];
          final p = _insidePoint(loop.vertices);
          var depth = 0;
          for (var j = 0; j < loops.length; j++) {
            if (i == j) continue;
            if (Intersect.polygonContains(loops[j].vertices, p)) depth++;
          }
          filled.add(HatchLoop(vertices: loop.vertices, isOuter: depth.isEven));
        }
        loops
          ..clear()
          ..addAll(filled);
      }
      final patternLines = <HatchPatternLine>[];
      if (at < v.length) {
        final numDefs = v[at++].toInt();
        for (var i = 0; i < numDefs && at + 6 <= v.length; i++) {
          final lineAngle = v[at++];
          final ox = v[at++];
          final oy = v[at++];
          final dx = v[at++];
          final dy = v[at++];
          final numDashes = v[at++].toInt();
          final dashes = v.sublist(at, at + numDashes);
          at += numDashes;
          patternLines.add(
            HatchPatternLine(
              angle: lineAngle,
              originX: ox,
              originY: oy,
              deltaX: dx,
              deltaY: dy,
              dashes: dashes,
            ),
          );
        }
      }
      return HatchEntity(
        id: id,
        props: props,
        loops: loops,
        patternName: source.text.isEmpty ? 'SOLID' : source.text,
        solid: solid,
        patternAngle: angle,
        patternScale: scale,
        patternLines: patternLines,
      );
    case 0x2d: // LEADER
      if (v.length < 2) return null;
      final num = v[0].toInt();
      final vertices = <double>[];
      for (var i = 0; i < num && 2 + i * 2 + 1 < v.length; i++) {
        vertices.add(v[2 + i * 2]);
        vertices.add(v[3 + i * 2]);
      }
      if (vertices.length < 4) return null;
      return LeaderEntity(
        id: id,
        props: props,
        vertices: Float64List.fromList(vertices),
        hasArrowHead: v[1] != 0,
      );
    case 0x28: // RAY
      if (v.length < 6) return null;
      return RayEntity(
        id: id,
        props: props,
        origin: Vec2(v[0], v[1]),
        direction: Vec2(v[3], v[4]),
      );
    case 0x29: // XLINE
      if (v.length < 6) return null;
      return XLineEntity(
        id: id,
        props: props,
        origin: Vec2(v[0], v[1]),
        direction: Vec2(v[3], v[4]),
      );
    case 0x24: // SPLINE
      if (v.length < 6) return null;
      final degree = v[0].toInt();
      final closed = v[1] != 0;
      final numKnots = v[2].toInt();
      final numCtrl = v[3].toInt();
      final weighted = v[4] != 0;
      final numFit = v[5].toInt();
      var at = 6;
      final knots = v.sublist(at, at + numKnots);
      at += numKnots;
      final ctrl = Float64List(numCtrl * 2);
      final weights = <double>[];
      for (var i = 0; i < numCtrl; i++) {
        ctrl[i * 2] = v[at + i * 3];
        ctrl[i * 2 + 1] = v[at + i * 3 + 1];
        if (weighted) weights.add(v[at + i * 3 + 2]);
      }
      at += numCtrl * 3;
      Float64List? fit;
      if (numFit > 0) {
        fit = Float64List(numFit * 2);
        for (var i = 0; i < numFit; i++) {
          fit[i * 2] = v[at + i * 2];
          fit[i * 2 + 1] = v[at + i * 2 + 1];
        }
      }
      return SplineEntity(
        id: id,
        props: props,
        controlPoints: ctrl,
        knots: knots,
        weights: weights,
        degree: degree,
        closed: closed,
        fitPoints: fit,
      );
    case 0x2e: // TOLERANCE: draw the feature-control frame as text
      if (v.length < 4) return null;
      return TextEntity(
        id: id,
        props: props,
        position: Vec2(v[0], v[1]),
        content: source.text,
        height: 2.5,
        rotation: math.atan2(v[3], v[2]),
      );
    case 0x2c: // MTEXT
      if (v.length < 9) return null;
      return MTextEntity(
        id: id,
        props: props,
        position: Vec2(v[0], v[1]),
        content: source.text,
        height: v[7] == 0 ? 2.5 : v[7],
        rotation: math.atan2(v[4], v[3]),
        rectangleWidth: v[6],
        attachment: v[8].toInt(),
        styleName: _textStyleFor(source, drawing),
      );
    case 0x23: // ELLIPSE
      if (v.length < 9) return null;
      return EllipseEntity(
        id: id,
        props: props,
        center: Vec2(v[0], v[1]),
        majorAxis: Vec2(v[3], v[4]),
        ratio: v[6],
        startParam: v[7],
        endParam: v[8],
      );
    case 0x20: // TRACE
    case 0x1f: // SOLID
    case 0x1c: // 3DFACE: drop Z
      final stride = source.type == 0x1f ? 2 : 3;
      final corners = <Vec2>[];
      for (var i = 0; i + 1 < v.length; i += stride) {
        corners.add(Vec2(v[i], v[i + 1]));
      }
      if (corners.length < 3) return null;
      return SolidEntity(id: id, props: props, corners: corners);
    default:
      // Everything the document cannot model is kept as an unknown object:
      // tables, surfaces and custom application entities still belong to the
      // drawing tree and must survive a save. VIEWPORT is the exception: it
      // describes a layout window, not model geometry.
      if (source.type >= 500 || source.typeName != 'VIEWPORT') {
        return UnknownEntity(
          id: id,
          props: props,
          originalType: source.typeName,
        );
      }
      return null;
  }
}

TextHAlign _textHAlign(int value) =>
    value >= 0 && value < TextHAlign.values.length
    ? TextHAlign.values[value]
    : TextHAlign.left;

TextVAlign _textVAlign(int value) =>
    value >= 0 && value < TextVAlign.values.length
    ? TextVAlign.values[value]
    : TextVAlign.baseline;

/// Returns [drawing] with every block name unique.
///
/// DWG stores anonymous blocks as `*D` or `*U` and expects the reader to tell
/// them apart by handle; AutoCAD ships them as `*D1`, `*D2`, … A file can hold
/// hundreds of `*D` headers (one per dimension), and the document keys blocks
/// by name, so without this every dimension in the drawing would share one
/// block — and emit its 4,690 entities once per dimension.
DwgDrawing _withUniqueBlockNames(DwgDrawing drawing) {
  String baseName(DwgBlock block) => block.name.isEmpty ? '*U' : block.name;

  // Names the file itself uses once are reserved before any suffix is made:
  // otherwise a duplicate `*D` could take the name of a real `*D1` block and
  // force *that* block to be renamed.
  final totals = <String, int>{};
  for (final block in drawing.blocks.values) {
    final name = baseName(block);
    totals[name] = (totals[name] ?? 0) + 1;
  }
  final reserved = <String>{
    for (final entry in totals.entries)
      if (entry.value == 1) entry.key,
  };

  final used = <String>{};
  final counts = <String, int>{};
  final renamed = <int, DwgBlock>{};
  for (final block in drawing.blocks.values) {
    final base = baseName(block);
    var name = base;
    if ((totals[base] ?? 0) > 1) {
      // `*D` duplicates become `*D1`, `*D2`, … The first one keeps the bare
      // name, which is what AutoCAD and the reference decoder show for such a header.
      while (used.contains(name) || (name != base && reserved.contains(name))) {
        final next = counts[base] = (counts[base] ?? 0) + 1;
        name = '$base$next';
      }
    }
    used.add(name);
    renamed[block.handle] = name == block.name
        ? block
        : DwgBlock(
            handle: block.handle,
            name: name,
            baseX: block.baseX,
            baseY: block.baseY,
          );
  }
  return DwgDrawing(
    version: drawing.version,
    objectCount: drawing.objectCount,
    entities: drawing.entities,
    counts: drawing.counts,
    layers: drawing.layers,
    blocks: renamed,
    imageDefs: drawing.imageDefs,
    styles: drawing.styles,
    linetypes: drawing.linetypes,
    appIds: drawing.appIds,
    ucs: drawing.ucs,
    vports: drawing.vports,
    dimStyles: drawing.dimStyles,
    headerVariables: drawing.headerVariables,
    layouts: drawing.layouts,
    otherObjects: drawing.otherObjects,
  );
}

/// A point just inside a hatch boundary ring, used for nesting tests.
Vec2 _insidePoint(Float64List vertices) {
  if (vertices.length < 6) {
    return vertices.length >= 2 ? Vec2(vertices[0], vertices[1]) : Vec2.zero();
  }
  final ax = vertices[0];
  final ay = vertices[1];
  final bx = vertices[2];
  final by = vertices[3];
  const epsilon = 1e-6;
  return Vec2(ax + (bx - ax) * epsilon, ay + (by - ay) * epsilon);
}
