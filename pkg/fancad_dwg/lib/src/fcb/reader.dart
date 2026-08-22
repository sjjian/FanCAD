import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'format.dart';

/// The outcome of decoding an FCB buffer.
class FcbDecodeResult {
  FcbDecodeResult({
    required this.document,
    required this.diagnostics,
    required this.entityCount,
    required this.elapsed,
  });

  final CadDocument document;

  /// Warnings produced by the importer, such as skipped object types.
  final List<String> diagnostics;
  final int entityCount;
  final Duration elapsed;

  @override
  String toString() =>
      'FcbDecodeResult($entityCount entities in ${elapsed.inMilliseconds}ms, '
      '${diagnostics.length} diagnostics)';
}

/// Decodes an FCB buffer into a [CadDocument].
///
/// The decoder never copies bulk data: the double and integer pools are
/// accessed through typed-data views over the incoming buffer, and entity
/// geometry is sliced out of them with `sublistView`. That keeps the cost of
/// opening a large drawing dominated by object allocation rather than by
/// byte shuffling.
class FcbReader {
  FcbReader(this.bytes)
    : _view = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ) {
    _readToc();
  }

  final Uint8List bytes;
  final ByteData _view;

  final Map<int, (int offset, int length)> _sections = {};

  late final List<String> _strings = _readStrings();
  late final Float64List _doubles = _readDoublePool();
  late final Int64List _ints = _readIntPool();

  void _readToc() {
    if (bytes.lengthInBytes < fcbHeaderSize) {
      throw const FcbFormatException('Buffer is smaller than the FCB header');
    }
    final magic = _view.getUint32(0, Endian.little);
    if (magic != fcbMagic) {
      throw FcbFormatException(
        'Bad magic 0x${magic.toRadixString(16)}, expected 0x'
        '${fcbMagic.toRadixString(16)}',
      );
    }
    final version = _view.getUint16(4, Endian.little);
    if (version != fcbVersion) {
      throw FcbFormatException(
        'Unsupported FCB version $version, this build reads $fcbVersion',
      );
    }
    final count = _view.getUint32(8, Endian.little);
    for (var i = 0; i < count; i++) {
      final at = fcbHeaderSize + i * fcbTocEntrySize;
      if (at + fcbTocEntrySize > bytes.lengthInBytes) {
        throw const FcbFormatException('Truncated table of contents');
      }
      final kind = _view.getUint32(at, Endian.little);
      final offset = _view.getUint64(at + 8, Endian.little);
      final length = _view.getUint64(at + 16, Endian.little);
      if (offset + length > bytes.lengthInBytes) {
        throw FcbFormatException(
          'Section $kind extends past the end of the buffer',
        );
      }
      _sections[kind] = (offset, length);
    }
  }

  (int, int)? _section(int kind) => _sections[kind];

  List<String> _readStrings() {
    final section = _section(FcbSection.strings);
    if (section == null) return const [''];
    final base = section.$1;
    final count = _view.getUint32(base, Endian.little);
    final dataLength = _view.getUint32(base + 4, Endian.little);
    final offsetsAt = base + 8;
    final dataAt = offsetsAt + (count + 1) * 4;
    final result = List<String>.filled(count, '');
    for (var i = 0; i < count; i++) {
      final start = _view.getUint32(offsetsAt + i * 4, Endian.little);
      final end = _view.getUint32(offsetsAt + (i + 1) * 4, Endian.little);
      if (start > end || end > dataLength) continue;
      if (start == end) continue;
      result[i] = utf8.decode(
        Uint8List.sublistView(bytes, dataAt + start, dataAt + end),
        allowMalformed: true,
      );
    }
    return result;
  }

  Float64List _readDoublePool() {
    final section = _section(FcbSection.doublePool);
    if (section == null) return Float64List(0);
    final count = _view.getUint64(section.$1, Endian.little);
    if (count == 0) return Float64List(0);
    return Float64List.view(
      bytes.buffer,
      bytes.offsetInBytes + section.$1 + 8,
      count,
    );
  }

  Int64List _readIntPool() {
    final section = _section(FcbSection.intPool);
    if (section == null) return Int64List(0);
    final count = _view.getUint64(section.$1, Endian.little);
    if (count == 0) return Int64List(0);
    return Int64List.view(
      bytes.buffer,
      bytes.offsetInBytes + section.$1 + 8,
      count,
    );
  }

  String _string(int index) =>
      index >= 0 && index < _strings.length ? _strings[index] : '';

  /// Decodes the whole buffer.
  FcbDecodeResult decode() {
    final stopwatch = Stopwatch()..start();

    final lineTypes = _decodeLineTypes();
    final layers = _decodeLayers(lineTypes);
    final textStyles = _decodeTextStyles();
    final dimStyles = _decodeDimStyles();
    final blockNames = _blockNames();

    final document = CadDocument(
      modelSpaceBlockName: blockNames.isEmpty
          ? CadDocument.defaultModelSpaceBlock
          : blockNames.first,
      layers: layers.isEmpty ? null : layers,
      lineTypes: lineTypes.isEmpty ? null : {
        for (final lineType in lineTypes) lineType.name: lineType,
      },
      textStyles: textStyles.isEmpty ? null : textStyles,
      dimStyles: dimStyles.isEmpty ? null : dimStyles,
    );

    final layerNames = _layerNames();
    final entities = _decodeEntities(
      layerNames: layerNames,
      lineTypeNames: [for (final lineType in lineTypes) lineType.name],
    );
    for (final entity in entities) {
      document.registerImportedEntity(entity);
    }

    _applyBlocks(document, blockNames, entities);
    _applyLayouts(document, blockNames);
    _applyViewports(document);
    _applyPlotWindows(document);
    _applyPlotPlacement(document);
    _applyHeaderVariables(document);

    document.reindex();
    stopwatch.stop();

    return FcbDecodeResult(
      document: document,
      diagnostics: _decodeDiagnostics(),
      entityCount: entities.length,
      elapsed: stopwatch.elapsed,
    );
  }

  List<String> _decodeDiagnostics() {
    final section = _section(FcbSection.diagnostics);
    if (section == null || section.$2 == 0) return const [];
    final text = utf8.decode(
      Uint8List.sublistView(bytes, section.$1, section.$1 + section.$2),
      allowMalformed: true,
    );
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<LineTypeDef> _decodeLineTypes() {
    final section = _section(FcbSection.lineTypes);
    if (section == null) return const [];
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    return [
      for (var i = 0; i < count; i++)
        _decodeLineType(base + 8 + i * FcbRecord.lineType),
    ];
  }

  LineTypeDef _decodeLineType(int at) {
    final patternOffset = _view.getUint32(
      at + FcbLineType.patternOffset,
      Endian.little,
    );
    final patternCount = _view.getUint32(
      at + FcbLineType.patternCount,
      Endian.little,
    );
    return LineTypeDef(
      name: _string(_view.getUint32(at + FcbLineType.name, Endian.little)),
      description: _string(
        _view.getUint32(at + FcbLineType.description, Endian.little),
      ),
      pattern: _slice(patternOffset, patternCount).toList(),
      patternLength: _view.getFloat64(
        at + FcbLineType.patternLength,
        Endian.little,
      ),
    );
  }

  List<String> _layerNames() {
    final section = _section(FcbSection.layers);
    if (section == null) return const [];
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    return [
      for (var i = 0; i < count; i++)
        _string(
          _view.getUint32(
            base + 8 + i * FcbRecord.layer + FcbLayer.name,
            Endian.little,
          ),
        ),
    ];
  }

  Map<String, LayerDef> _decodeLayers(List<LineTypeDef> lineTypes) {
    final section = _section(FcbSection.layers);
    if (section == null) return {};
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    final result = <String, LayerDef>{};
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.layer;
      final name = _string(
        _view.getUint32(at + FcbLayer.name, Endian.little),
      );
      final flags = _view.getUint32(at + FcbLayer.flags, Endian.little);
      final lineTypeIndex = _view.getUint32(
        at + FcbLayer.lineTypeIndex,
        Endian.little,
      );
      result[name] = LayerDef(
        name: name,
        color: _unpackColor(
          _view.getUint32(at + FcbLayer.colorPacked, Endian.little),
        ),
        lineType: lineTypeIndex < lineTypes.length
            ? lineTypes[lineTypeIndex].name
            : 'Continuous',
        lineWeight: _view.getInt32(at + FcbLayer.lineWeight, Endian.little),
        visible: flags & FcbLayerFlags.hidden == 0,
        frozen: flags & FcbLayerFlags.frozen != 0,
        locked: flags & FcbLayerFlags.locked != 0,
        plottable: flags & FcbLayerFlags.noPlot == 0,
        transparency: _view.getInt32(
          at + FcbLayer.transparency,
          Endian.little,
        ),
      );
    }
    return result;
  }

  Map<String, TextStyleDef> _decodeTextStyles() {
    final section = _section(FcbSection.textStyles);
    if (section == null) return {};
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    final result = <String, TextStyleDef>{};
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.textStyle;
      final flags = _view.getUint32(at + FcbTextStyle.flags, Endian.little);
      final name = _string(
        _view.getUint32(at + FcbTextStyle.name, Endian.little),
      );
      result[name] = TextStyleDef(
        name: name,
        fontFamily: _string(
          _view.getUint32(at + FcbTextStyle.font, Endian.little),
        ),
        bigFontFamily: _string(
          _view.getUint32(at + FcbTextStyle.bigFont, Endian.little),
        ),
        height: _view.getFloat64(at + FcbTextStyle.height, Endian.little),
        widthFactor: _view.getFloat64(
          at + FcbTextStyle.widthFactor,
          Endian.little,
        ),
        obliqueAngle: _view.getFloat64(
          at + FcbTextStyle.obliqueAngle,
          Endian.little,
        ),
        backwards: flags & 1 != 0,
        upsideDown: flags & 2 != 0,
      );
    }
    return result;
  }

  Map<String, DimStyleDef> _decodeDimStyles() {
    final section = _section(FcbSection.dimStyles);
    if (section == null) return {};
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    final result = <String, DimStyleDef>{};
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.dimStyle;
      final name = _string(
        _view.getUint32(at + FcbDimStyle.name, Endian.little),
      );
      result[name] = DimStyleDef(
        name: name,
        textStyle: _string(
          _view.getUint32(at + FcbDimStyle.textStyle, Endian.little),
        ),
        decimalPlaces: _view.getUint32(
          at + FcbDimStyle.decimalPlaces,
          Endian.little,
        ),
        textHeight: _view.getFloat64(
          at + FcbDimStyle.textHeight,
          Endian.little,
        ),
        arrowSize: _view.getFloat64(at + FcbDimStyle.arrowSize, Endian.little),
        extensionLineOffset: _view.getFloat64(
          at + FcbDimStyle.extensionLineOffset,
          Endian.little,
        ),
        extensionLineExtend: _view.getFloat64(
          at + FcbDimStyle.extensionLineExtend,
          Endian.little,
        ),
        textGap: _view.getFloat64(at + FcbDimStyle.textGap, Endian.little),
        scale: _view.getFloat64(at + FcbDimStyle.scale, Endian.little),
      );
    }
    return result;
  }

  List<String> _blockNames() {
    final section = _section(FcbSection.blocks);
    if (section == null) return const [];
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    return [
      for (var i = 0; i < count; i++)
        _string(
          _view.getUint32(
            base + 8 + i * FcbRecord.block + FcbBlock.name,
            Endian.little,
          ),
        ),
    ];
  }

  void _applyBlocks(
    CadDocument document,
    List<String> names,
    List<CadEntity> entities,
  ) {
    final section = _section(FcbSection.blocks);
    if (section == null) return;
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.block;
      final flags = _view.getUint32(at + FcbBlock.flags, Endian.little);
      final first = _view.getUint32(at + FcbBlock.entityFirst, Endian.little);
      final length = _view.getUint32(at + FcbBlock.entityCount, Endian.little);
      final ids = <int>[];
      for (var k = first; k < first + length && k < entities.length; k++) {
        ids.add(entities[k].id);
      }
      document.putBlock(
        BlockRecord(
          name: names[i],
          basePoint: Vec2(
            _view.getFloat64(at + FcbBlock.baseX, Endian.little),
            _view.getFloat64(at + FcbBlock.baseY, Endian.little),
          ),
          entityIds: ids,
          isLayoutBlock: flags & FcbBlockFlags.layout != 0,
          isAnonymous: flags & FcbBlockFlags.anonymous != 0,
          description: _string(
            _view.getUint32(at + FcbBlock.description, Endian.little),
          ),
          xrefPath: _string(
            _view.getUint32(at + FcbBlock.xrefPath, Endian.little),
          ),
        ),
      );
    }
  }

  void _applyLayouts(CadDocument document, List<String> blockNames) {
    final section = _section(FcbSection.layouts);
    if (section == null) return;
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.layout;
      final blockIndex = _view.getUint32(
        at + FcbLayout.blockIndex,
        Endian.little,
      );
      final flags = _view.getUint32(at + FcbLayout.flags, Endian.little);
      document.addLayout(
        Layout(
          name: _string(
            _view.getUint32(at + FcbLayout.name, Endian.little),
          ),
          blockName: blockIndex < blockNames.length
              ? blockNames[blockIndex]
              : document.modelSpaceBlockName,
          isModelSpace: flags & FcbLayoutFlags.modelSpace != 0,
          plotRotation:
              ((flags >> FcbLayoutFlags.plotRotationShift) & 3) * 90,
          tabOrder: _view.getUint32(at + FcbLayout.tabOrder, Endian.little),
          paperWidth: _view.getFloat64(
            at + FcbLayout.paperWidth,
            Endian.little,
          ),
          paperHeight: _view.getFloat64(
            at + FcbLayout.paperHeight,
            Endian.little,
          ),
        ),
      );
    }
    // Prefer opening on model space, matching what every CAD application does.
    final model = document.layouts.firstWhere(
      (layout) => layout.isModelSpace,
      orElse: () => document.layouts.first,
    );
    document.setActiveLayout(model.name);
  }

  void _applyViewports(CadDocument document) {
    final section = _section(FcbSection.viewports);
    if (section == null) return;
    final layouts = List<Layout>.from(document.layouts);
    if (layouts.isEmpty) return;
    final buckets = List<List<PaperViewport>>.generate(
      layouts.length,
      (_) => <PaperViewport>[],
    );
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.viewport;
      final layoutIndex = _view.getUint32(
        at + FcbViewport.layoutIndex,
        Endian.little,
      );
      if (layoutIndex >= layouts.length) continue;
      final flags = _view.getUint32(at + FcbViewport.flags, Endian.little);
      final layer = _string(
        _view.getUint32(at + FcbViewport.layer, Endian.little),
      );
      buckets[layoutIndex].add(
        PaperViewport(
          paperBounds: Bounds2(
            _view.getFloat64(at + FcbViewport.paperMinX, Endian.little),
            _view.getFloat64(at + FcbViewport.paperMinY, Endian.little),
            _view.getFloat64(at + FcbViewport.paperMaxX, Endian.little),
            _view.getFloat64(at + FcbViewport.paperMaxY, Endian.little),
          ),
          modelCenter: Vec2(
            _view.getFloat64(at + FcbViewport.modelCenterX, Endian.little),
            _view.getFloat64(at + FcbViewport.modelCenterY, Endian.little),
          ),
          scale: _view.getFloat64(at + FcbViewport.scale, Endian.little),
          rotation: _view.getFloat64(at + FcbViewport.rotation, Endian.little),
          isOn: flags & FcbViewportFlags.on != 0,
          locked: flags & FcbViewportFlags.locked != 0,
          layer: layer.isEmpty ? '0' : layer,
          frozenLayers: [
            for (final name in _string(
              _view.getUint32(at + FcbViewport.frozenLayers, Endian.little),
            ).split(','))
              if (name.trim().isNotEmpty) name.trim(),
          ],
        ),
      );
    }
    for (var i = 0; i < layouts.length; i++) {
      if (buckets[i].isEmpty) continue;
      document.addLayout(layouts[i].copyWith(viewports: buckets[i]));
    }
  }

  void _applyPlotWindows(CadDocument document) {
    final section = _section(FcbSection.plotWindows);
    if (section == null) return;
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    final layouts = List<Layout>.from(document.layouts);
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.plotWindow;
      final layoutIndex = _view.getUint32(
        at + FcbPlotWindow.layoutIndex,
        Endian.little,
      );
      if (layoutIndex >= layouts.length) continue;
      final box = Bounds2(
        _view.getFloat64(at + FcbPlotWindow.minX, Endian.little),
        _view.getFloat64(at + FcbPlotWindow.minY, Endian.little),
        _view.getFloat64(at + FcbPlotWindow.maxX, Endian.little),
        _view.getFloat64(at + FcbPlotWindow.maxY, Endian.little),
      );
      if (box.isEmpty) continue;
      document.addLayout(layouts[layoutIndex].copyWith(plotWindow: box));
    }
  }

  void _applyPlotPlacement(CadDocument document) {
    final section = _section(FcbSection.plotPlacement);
    if (section == null) return;
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    final layouts = List<Layout>.from(document.layouts);
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.plotPlacement;
      final layoutIndex = _view.getUint32(
        at + FcbPlotPlacement.layoutIndex,
        Endian.little,
      );
      if (layoutIndex >= layouts.length) continue;
      final flags = _view.getUint32(at + FcbPlotPlacement.flags, Endian.little);
      document.addLayout(
        layouts[layoutIndex].copyWith(
          plotFit: flags & FcbPlotPlacementFlags.fit != 0,
          plotScale: _view.getFloat64(
            at + FcbPlotPlacement.scale,
            Endian.little,
          ),
          plotOffsetX: _view.getFloat64(
            at + FcbPlotPlacement.offsetX,
            Endian.little,
          ),
          plotOffsetY: _view.getFloat64(
            at + FcbPlotPlacement.offsetY,
            Endian.little,
          ),
        ),
      );
    }
  }

  void _applyHeaderVariables(CadDocument document) {
    final section = _section(FcbSection.headerVariables);
    if (section == null) return;
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    for (var i = 0; i < count; i++) {
      document.setHeaderVariable(
        _string(_view.getUint32(base + 8 + i * 8, Endian.little)),
        _string(_view.getUint32(base + 8 + i * 8 + 4, Endian.little)),
      );
    }
  }

  List<CadEntity> _decodeEntities({
    required List<String> layerNames,
    required List<String> lineTypeNames,
  }) {
    final section = _section(FcbSection.entities);
    if (section == null) return const [];
    final base = section.$1;
    final count = _view.getUint64(base, Endian.little);
    final result = <CadEntity>[];
    for (var i = 0; i < count; i++) {
      final at = base + 8 + i * FcbRecord.entity;
      final entity = _decodeEntity(at, layerNames, lineTypeNames);
      if (entity != null) result.add(entity);
    }
    return result;
  }

  CadEntity? _decodeEntity(
    int at,
    List<String> layerNames,
    List<String> lineTypeNames,
  ) {
    final type = _view.getUint16(at + FcbEntity.type, Endian.little);
    final flags = _view.getUint16(at + FcbEntity.flags, Endian.little);
    final id = _view.getUint64(at + FcbEntity.handle, Endian.little);

    final geomOffset = _view.getUint64(at + FcbEntity.geomOffset, Endian.little);
    final geomCount = _view.getUint32(at + FcbEntity.geomCount, Endian.little);
    final intOffset = _view.getUint64(at + FcbEntity.intOffset, Endian.little);
    final intCount = _view.getUint32(at + FcbEntity.intCount, Endian.little);
    final stringOffset = _view.getUint32(
      at + FcbEntity.stringOffset,
      Endian.little,
    );
    final stringCount = _view.getUint32(
      at + FcbEntity.stringCount,
      Endian.little,
    );

    final geom = _slice(geomOffset, geomCount);
    final ints = _intSlice(intOffset, intCount);
    String stringAt(int index) => index < stringCount
        ? _string(stringOffset + index)
        : '';

    final layerIndex = _view.getUint32(at + FcbEntity.layerIndex, Endian.little);
    final lineTypeIndex = _view.getUint32(
      at + FcbEntity.lineTypeIndex,
      Endian.little,
    );

    var elevation = 0.0;
    var lineTypeScale = 1.0;
    var transparency = -1;
    if (flags & FcbFlags.hasExtendedProps != 0) {
      final propsOffset = _view.getUint32(
        at + FcbEntity.propsOffset,
        Endian.little,
      );
      final props = _slice(propsOffset, 3);
      if (props.length == 3) {
        elevation = props[0];
        lineTypeScale = props[1];
        transparency = props[2].round();
      }
    }

    final props = EntityProps(
      layer: layerIndex < layerNames.length ? layerNames[layerIndex] : '0',
      color: _unpackColor(
        _view.getUint32(at + FcbEntity.colorPacked, Endian.little),
      ),
      lineType: switch (lineTypeIndex) {
        0xFFFFFFFF => 'ByLayer',
        0xFFFFFFFE => 'ByBlock',
        final index when index < lineTypeNames.length => lineTypeNames[index],
        _ => 'ByLayer',
      },
      lineWeight: _view.getInt32(at + FcbEntity.lineWeight, Endian.little),
      lineTypeScale: lineTypeScale,
      transparency: transparency,
      visible: flags & FcbFlags.invisible == 0,
      elevation: elevation,
    );

    final closed = flags & FcbFlags.closed != 0;

    switch (type) {
      case FcbType.line:
        if (geom.length < 4) return null;
        return LineEntity(
          id: id,
          props: props,
          start: Vec2(geom[0], geom[1]),
          end: Vec2(geom[2], geom[3]),
        );

      case FcbType.point:
        if (geom.length < 2) return null;
        return PointEntity(
          id: id,
          props: props,
          position: Vec2(geom[0], geom[1]),
        );

      case FcbType.circle:
        if (geom.length < 3) return null;
        return CircleEntity(
          id: id,
          props: props,
          center: Vec2(geom[0], geom[1]),
          radius: geom[2],
        );

      case FcbType.arc:
        if (geom.length < 5) return null;
        return ArcEntity(
          id: id,
          props: props,
          center: Vec2(geom[0], geom[1]),
          radius: geom[2],
          startAngle: geom[3],
          endAngle: geom[4],
        );

      case FcbType.ellipse:
        if (geom.length < 7) return null;
        return EllipseEntity(
          id: id,
          props: props,
          center: Vec2(geom[0], geom[1]),
          majorAxis: Vec2(geom[2], geom[3]),
          ratio: geom[4],
          startParam: geom[5],
          endParam: geom[6],
        );

      case FcbType.polyline:
        return PolylineEntity(
          id: id,
          props: props,
          vertices: Float64List.fromList(geom),
          closed: closed,
        );

      case FcbType.spline:
        if (ints.length < 5) return null;
        final degree = ints[0];
        final knotCount = ints[1];
        final ctrlCount = ints[2];
        final weightCount = ints[3];
        final fitCount = ints[4];
        var cursor = 0;
        final knots = geom.sublist(
          cursor,
          math.min(cursor + knotCount, geom.length),
        );
        cursor += knotCount;
        final control = Float64List.fromList(
          geom.sublist(cursor, math.min(cursor + ctrlCount * 2, geom.length)),
        );
        cursor += ctrlCount * 2;
        final weights = geom.sublist(
          math.min(cursor, geom.length),
          math.min(cursor + weightCount, geom.length),
        );
        cursor += weightCount;
        final fit = Float64List.fromList(
          geom.sublist(
            math.min(cursor, geom.length),
            math.min(cursor + fitCount * 2, geom.length),
          ),
        );
        return SplineEntity(
          id: id,
          props: props,
          controlPoints: control,
          knots: knots.toList(),
          weights: weights.toList(),
          degree: degree,
          closed: closed,
          fitPoints: fit.isEmpty ? null : fit,
        );

      case FcbType.text:
        if (geom.length < 6) return null;
        return TextEntity(
          id: id,
          props: props,
          position: Vec2(geom[0], geom[1]),
          content: stringAt(0),
          height: geom[2],
          rotation: geom[3],
          styleName: stringAt(1).isEmpty ? 'Standard' : stringAt(1),
          widthFactor: geom[4] == 0 ? 1 : geom[4],
          obliqueAngle: geom[5],
          hAlign: _enumAt(TextHAlign.values, ints, 0, TextHAlign.left),
          vAlign: _enumAt(TextVAlign.values, ints, 1, TextVAlign.baseline),
        );

      case FcbType.mtext:
        if (geom.length < 5) return null;
        return MTextEntity(
          id: id,
          props: props,
          position: Vec2(geom[0], geom[1]),
          content: stringAt(0),
          height: geom[2],
          rotation: geom[3],
          styleName: stringAt(1).isEmpty ? 'Standard' : stringAt(1),
          rectangleWidth: geom[4],
          attachment: ints.isNotEmpty ? ints[0] : 1,
        );

      case FcbType.insert:
        if (geom.length < 7) return null;
        return InsertEntity(
          id: id,
          props: props,
          blockName: stringAt(0),
          position: Vec2(geom[0], geom[1]),
          scale: Vec2(geom[2] == 0 ? 1 : geom[2], geom[3] == 0 ? 1 : geom[3]),
          rotation: geom[4],
          columnCount: ints.isNotEmpty ? math.max(1, ints[0]) : 1,
          rowCount: ints.length > 1 ? math.max(1, ints[1]) : 1,
          columnSpacing: geom[5],
          rowSpacing: geom[6],
        );

      case FcbType.hatch:
        if (ints.isEmpty || geom.length < 2) return null;
        final loopCount = ints[0];
        final loops = <HatchLoop>[];
        var cursor = 2;
        for (var i = 0; i < loopCount; i++) {
          final metaAt = 1 + i * 2;
          if (metaAt + 1 >= ints.length) break;
          final isOuter = ints[metaAt] != 0;
          final pointCount = ints[metaAt + 1];
          final end = math.min(cursor + pointCount * 2, geom.length);
          if (end <= cursor) break;
          loops.add(
            HatchLoop(
              vertices: Float64List.fromList(geom.sublist(cursor, end)),
              isOuter: isOuter,
            ),
          );
          cursor = end;
        }
        return HatchEntity(
          id: id,
          props: props,
          loops: loops,
          patternName: stringAt(0).isEmpty ? 'SOLID' : stringAt(0),
          solid: flags & FcbFlags.solidFill != 0,
          patternAngle: geom[0],
          patternScale: geom[1] == 0 ? 1 : geom[1],
        );

      case FcbType.dimension:
        if (geom.length < 3) return null;
        final pointCount = ints.length > 1 ? ints[1] : 0;
        final definitionPoints = <Vec2>[];
        for (var i = 0; i < pointCount; i++) {
          final at = 3 + i * 2;
          if (at + 1 >= geom.length) break;
          definitionPoints.add(Vec2(geom[at], geom[at + 1]));
        }
        return DimensionEntity(
          id: id,
          props: props,
          blockName: stringAt(0),
          definitionPoints: definitionPoints,
          textPosition: Vec2(geom[0], geom[1]),
          measurement: geom[2],
          overrideText: stringAt(1),
          styleName: stringAt(2).isEmpty ? 'Standard' : stringAt(2),
          dimensionType: ints.isNotEmpty ? ints[0] : 0,
        );

      case FcbType.leader:
        return LeaderEntity(
          id: id,
          props: props,
          vertices: Float64List.fromList(geom),
          hasArrowHead: flags & FcbFlags.arrowHead != 0,
          styleName: stringAt(0).isEmpty ? 'Standard' : stringAt(0),
        );

      case FcbType.solid:
        if (geom.length < 6) return null;
        return SolidEntity(
          id: id,
          props: props,
          corners: [
            for (var i = 0; i + 1 < geom.length; i += 2)
              Vec2(geom[i], geom[i + 1]),
          ],
        );

      case FcbType.ray:
        if (geom.length < 4) return null;
        return RayEntity(
          id: id,
          props: props,
          origin: Vec2(geom[0], geom[1]),
          direction: Vec2(geom[2], geom[3]),
        );

      case FcbType.xline:
        if (geom.length < 4) return null;
        return XLineEntity(
          id: id,
          props: props,
          origin: Vec2(geom[0], geom[1]),
          direction: Vec2(geom[2], geom[3]),
        );

      case FcbType.image:
        if (geom.length < 6) return null;
        return ImageEntity(
          id: id,
          props: props,
          reference: stringAt(0),
          origin: Vec2(geom[0], geom[1]),
          uVector: Vec2(geom[2], geom[3]),
          vVector: Vec2(geom[4], geom[5]),
        );

      default:
        return UnknownEntity(
          id: id,
          props: props,
          originalType: stringAt(0).isEmpty ? 'UNKNOWN' : stringAt(0),
          proxyBounds: geom.length >= 4
              ? Bounds2(geom[0], geom[1], geom[2], geom[3])
              : Bounds2(
                  _view.getFloat64(at + FcbEntity.minX, Endian.little),
                  _view.getFloat64(at + FcbEntity.minY, Endian.little),
                  _view.getFloat64(at + FcbEntity.maxX, Endian.little),
                  _view.getFloat64(at + FcbEntity.maxY, Endian.little),
                ),
        );
    }
  }

  Float64List _slice(int offset, int count) {
    if (count == 0) return Float64List(0);
    if (offset < 0 || offset + count > _doubles.length) return Float64List(0);
    return Float64List.sublistView(_doubles, offset, offset + count);
  }

  Int64List _intSlice(int offset, int count) {
    if (count == 0) return Int64List(0);
    if (offset < 0 || offset + count > _ints.length) return Int64List(0);
    return Int64List.sublistView(_ints, offset, offset + count);
  }

  static CadColor _unpackColor(int packed) {
    final value = unpackColorValue(packed);
    return switch (unpackColorKind(packed)) {
      FcbColorKind.byLayer => const CadColor.byLayer(),
      FcbColorKind.byBlock => const CadColor.byBlock(),
      FcbColorKind.trueColor => CadColor.rgb(value),
      _ => CadColor.indexed(value == 0 ? 7 : value),
    };
  }

  static T _enumAt<T extends Enum>(
    List<T> values,
    Int64List ints,
    int index,
    T fallback,
  ) {
    if (index >= ints.length) return fallback;
    final raw = ints[index];
    return raw >= 0 && raw < values.length ? values[raw] : fallback;
  }
}
