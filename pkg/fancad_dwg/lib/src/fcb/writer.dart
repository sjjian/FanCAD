import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'format.dart';

/// A growable `Float64List`, used for the FCB double pool.
class _DoublePool {
  Float64List _data = Float64List(1024);
  int _length = 0;

  int get length => _length;

  int add(double value) {
    _ensure(1);
    _data[_length] = value;
    return _length++;
  }

  /// Appends [values] and returns the index of the first one.
  int addAll(List<double> values) {
    if (values.isEmpty) return _length;
    _ensure(values.length);
    final start = _length;
    for (var i = 0; i < values.length; i++) {
      _data[start + i] = values[i];
    }
    _length += values.length;
    return start;
  }

  int addBuffer(Float64List values) {
    if (values.isEmpty) return _length;
    _ensure(values.length);
    final start = _length;
    _data.setRange(start, start + values.length, values);
    _length += values.length;
    return start;
  }

  void _ensure(int extra) {
    if (_length + extra <= _data.length) return;
    var capacity = _data.length * 2;
    while (capacity < _length + extra) {
      capacity *= 2;
    }
    final grown = Float64List(capacity)..setRange(0, _length, _data);
    _data = grown;
  }

  Float64List view() => Float64List.sublistView(_data, 0, _length);
}

/// A growable `Int64List`, used for the FCB integer pool.
class _IntPool {
  Int64List _data = Int64List(256);
  int _length = 0;

  int get length => _length;

  int addAll(List<int> values) {
    if (values.isEmpty) return _length;
    _ensure(values.length);
    final start = _length;
    for (var i = 0; i < values.length; i++) {
      _data[start + i] = values[i];
    }
    _length += values.length;
    return start;
  }

  void _ensure(int extra) {
    if (_length + extra <= _data.length) return;
    var capacity = _data.length * 2;
    while (capacity < _length + extra) {
      capacity *= 2;
    }
    final grown = Int64List(capacity)..setRange(0, _length, _data);
    _data = grown;
  }

  Int64List view() => Int64List.sublistView(_data, 0, _length);
}

/// Interns strings so repeated layer and style names cost four bytes each.
class _StringTable {
  final Map<String, int> _indexOf = {};
  final List<String> _values = [];

  int get length => _values.length;

  /// Index 0 is always the empty string, so a zeroed field decodes as absent.
  _StringTable() {
    intern('');
  }

  int intern(String value) =>
      _indexOf.putIfAbsent(value, () {
        _values.add(value);
        return _values.length - 1;
      });

  /// Interns a run of strings and returns `(firstIndex, count)`. The run must
  /// be contiguous, so the values are appended without deduplication.
  (int, int) internRun(List<String> values) {
    if (values.isEmpty) return (0, 0);
    final start = _values.length;
    for (final value in values) {
      _values.add(value);
    }
    return (start, values.length);
  }

  Uint8List encode() {
    final encoded = [
      for (final value in _values) utf8.encode(value),
    ];
    var dataLength = 0;
    for (final bytes in encoded) {
      dataLength += bytes.length;
    }
    final count = encoded.length;
    final offsetsBytes = (count + 1) * 4;
    final total = alignUp8(8 + offsetsBytes + dataLength);
    final buffer = Uint8List(total);
    final view = ByteData.view(buffer.buffer);
    view.setUint32(0, count, Endian.little);
    view.setUint32(4, dataLength, Endian.little);
    var cursor = 0;
    for (var i = 0; i < count; i++) {
      view.setUint32(8 + i * 4, cursor, Endian.little);
      cursor += encoded[i].length;
    }
    view.setUint32(8 + count * 4, cursor, Endian.little);
    var writeAt = 8 + offsetsBytes;
    for (final bytes in encoded) {
      buffer.setRange(writeAt, writeAt + bytes.length, bytes);
      writeAt += bytes.length;
    }
    return buffer;
  }
}

/// Encodes a [CadDocument] into an FCB buffer.
///
/// Used by the disk cache, by the DXF exporter's staging step, and by tests
/// that need to exercise the reader without native code.
class FcbWriter {
  FcbWriter();

  final _StringTable _strings = _StringTable();
  final _DoublePool _doubles = _DoublePool();
  final _IntPool _ints = _IntPool();

  final List<String> _diagnostics = [];

  Uint8List write(CadDocument document) {
    final lineTypeNames = document.lineTypes.keys.toList();
    final lineTypeIndex = {
      for (var i = 0; i < lineTypeNames.length; i++) lineTypeNames[i]: i,
    };
    final layerNames = document.layers.keys.toList();
    final layerIndex = {
      for (var i = 0; i < layerNames.length; i++) layerNames[i]: i,
    };

    // Blocks are ordered with the model space container first so that a
    // reader can start drawing before the rest of the table arrives.
    final blockNames = <String>[
      document.modelSpaceBlockName,
      for (final name in document.blocks.keys)
        if (name != document.modelSpaceBlockName) name,
    ];
    final blockIndex = {
      for (var i = 0; i < blockNames.length; i++) blockNames[i]: i,
    };

    final entityRecords = BytesBuilder(copy: false);
    final blockRanges = <String, (int, int)>{};
    var entityCursor = 0;

    for (final blockName in blockNames) {
      final block = document.blocks[blockName];
      if (block == null) {
        blockRanges[blockName] = (entityCursor, 0);
        continue;
      }
      final first = entityCursor;
      for (final id in block.entityIds) {
        final entity = document.entity(id);
        if (entity == null) continue;
        entityRecords.add(
          _encodeEntity(
            entity,
            document: document,
            layerIndex: layerIndex,
            lineTypeIndex: lineTypeIndex,
            ownerBlockIndex: blockIndex[blockName] ?? 0,
            isPaperSpace: !block.isLayoutBlock
                ? false
                : blockName != document.modelSpaceBlockName,
          ),
        );
        entityCursor++;
      }
      blockRanges[blockName] = (first, entityCursor - first);
    }

    final sections = <int, Uint8List>{
      FcbSection.entities: _withCountHeader(
        entityCursor,
        entityRecords.takeBytes(),
      ),
      FcbSection.layers: _encodeLayers(document, layerNames, lineTypeIndex),
      FcbSection.lineTypes: _encodeLineTypes(document, lineTypeNames),
      FcbSection.textStyles: _encodeTextStyles(document),
      FcbSection.blocks: _encodeBlocks(document, blockNames, blockRanges),
      FcbSection.layouts: _encodeLayouts(document, blockIndex),
      FcbSection.headerVariables: _encodeHeaderVariables(document),
    };

    // Pools are encoded last: the entity and table encoders above are what
    // fill them.
    sections[FcbSection.doublePool] = _encodeDoublePool();
    sections[FcbSection.intPool] = _encodeIntPool();
    sections[FcbSection.strings] = _strings.encode();
    if (_diagnostics.isNotEmpty) {
      sections[FcbSection.diagnostics] = _padded(
        Uint8List.fromList(utf8.encode(_diagnostics.join('\n'))),
      );
    }

    return _assemble(sections);
  }

  Uint8List _assemble(Map<int, Uint8List> sections) {
    final kinds = sections.keys.toList()..sort();
    final tocSize = kinds.length * fcbTocEntrySize;
    var offset = alignUp8(fcbHeaderSize + tocSize);
    var total = offset;
    for (final kind in kinds) {
      total += alignUp8(sections[kind]!.length);
    }

    final buffer = Uint8List(total);
    final view = ByteData.view(buffer.buffer);
    view.setUint32(0, fcbMagic, Endian.little);
    view.setUint16(4, fcbVersion, Endian.little);
    view.setUint16(6, 0, Endian.little);
    view.setUint32(8, kinds.length, Endian.little);
    view.setUint32(12, 0, Endian.little);

    var tocAt = fcbHeaderSize;
    for (final kind in kinds) {
      final payload = sections[kind]!;
      view.setUint32(tocAt, kind, Endian.little);
      view.setUint32(tocAt + 4, 0, Endian.little);
      view.setUint64(tocAt + 8, offset, Endian.little);
      view.setUint64(tocAt + 16, payload.length, Endian.little);
      buffer.setRange(offset, offset + payload.length, payload);
      offset += alignUp8(payload.length);
      tocAt += fcbTocEntrySize;
    }
    return buffer;
  }

  // -------------------------------------------------------------------------
  // Entities
  // -------------------------------------------------------------------------

  Uint8List _encodeEntity(
    CadEntity entity, {
    required CadDocument document,
    required Map<String, int> layerIndex,
    required Map<String, int> lineTypeIndex,
    required int ownerBlockIndex,
    required bool isPaperSpace,
  }) {
    final record = Uint8List(FcbRecord.entity);
    final view = ByteData.view(record.buffer);

    final bounds = document.boundsOfEntity(entity);
    view.setFloat64(FcbEntity.minX, bounds.isEmpty ? 0 : bounds.minX, Endian.little);
    view.setFloat64(FcbEntity.minY, bounds.isEmpty ? 0 : bounds.minY, Endian.little);
    view.setFloat64(FcbEntity.maxX, bounds.isEmpty ? 0 : bounds.maxX, Endian.little);
    view.setFloat64(FcbEntity.maxY, bounds.isEmpty ? 0 : bounds.maxY, Endian.little);
    view.setUint64(FcbEntity.handle, entity.id, Endian.little);

    final props = entity.props;
    var flags = 0;
    if (!props.visible) flags |= FcbFlags.invisible;
    if (isPaperSpace) flags |= FcbFlags.paperSpace;

    final needsExtended =
        props.elevation != 0 ||
        props.lineTypeScale != 1 ||
        props.transparency != -1;
    if (needsExtended) {
      flags |= FcbFlags.hasExtendedProps;
      final at = _doubles.addAll([
        props.elevation,
        props.lineTypeScale,
        props.transparency.toDouble(),
      ]);
      view.setUint32(FcbEntity.propsOffset, at, Endian.little);
    }

    final payload = _encodePayload(entity);
    flags |= payload.flags;

    view.setUint64(FcbEntity.geomOffset, payload.geomOffset, Endian.little);
    view.setUint32(FcbEntity.geomCount, payload.geomCount, Endian.little);
    view.setUint64(FcbEntity.intOffset, payload.intOffset, Endian.little);
    view.setUint32(FcbEntity.intCount, payload.intCount, Endian.little);
    view.setUint32(FcbEntity.stringOffset, payload.stringOffset, Endian.little);
    view.setUint32(FcbEntity.stringCount, payload.stringCount, Endian.little);

    view.setUint32(
      FcbEntity.layerIndex,
      layerIndex[props.layer] ?? 0,
      Endian.little,
    );
    view.setUint32(
      FcbEntity.colorPacked,
      _packEntityColor(props.color),
      Endian.little,
    );
    view.setUint32(
      FcbEntity.lineTypeIndex,
      // A `ByLayer` or `ByBlock` line type is encoded as index 0xFFFFFFFF and
      // 0xFFFFFFFE respectively, keeping real indices dense.
      switch (props.lineType) {
        'ByLayer' => 0xFFFFFFFF,
        'ByBlock' => 0xFFFFFFFE,
        final name => lineTypeIndex[name] ?? 0xFFFFFFFF,
      },
      Endian.little,
    );
    view.setUint32(FcbEntity.ownerBlockIndex, ownerBlockIndex, Endian.little);
    view.setInt32(FcbEntity.lineWeight, props.lineWeight, Endian.little);
    view.setUint16(FcbEntity.type, _typeCode(entity.kind), Endian.little);
    view.setUint16(FcbEntity.flags, flags, Endian.little);
    return record;
  }

  _Payload _encodePayload(CadEntity entity) {
    switch (entity) {
      case LineEntity(:final start, :final end):
        return _geom([start.x, start.y, end.x, end.y]);

      case PointEntity(:final position):
        return _geom([position.x, position.y]);

      case CircleEntity(:final center, :final radius):
        return _geom([center.x, center.y, radius]);

      case ArcEntity(
        :final center,
        :final radius,
        :final startAngle,
        :final endAngle,
      ):
        return _geom([center.x, center.y, radius, startAngle, endAngle]);

      case EllipseEntity(
        :final center,
        :final majorAxis,
        :final ratio,
        :final startParam,
        :final endParam,
      ):
        return _geom([
          center.x,
          center.y,
          majorAxis.x,
          majorAxis.y,
          ratio,
          startParam,
          endParam,
        ]);

      case PolylineEntity(:final vertices, :final closed):
        return _Payload(
          geomOffset: _doubles.addBuffer(vertices),
          geomCount: vertices.length,
          flags: closed ? FcbFlags.closed : 0,
        );

      case SplineEntity(
        :final controlPoints,
        :final knots,
        :final weights,
        :final degree,
        :final closed,
      ):
        final fit = entity.fitPointBuffer;
        final intOffset = _ints.addAll([
          degree,
          knots.length,
          controlPoints.length ~/ 2,
          weights.length,
          fit.length ~/ 2,
        ]);
        final geomOffset = _doubles.addAll(knots);
        _doubles.addBuffer(controlPoints);
        _doubles.addAll(weights);
        _doubles.addBuffer(fit);
        return _Payload(
          geomOffset: geomOffset,
          geomCount:
              knots.length + controlPoints.length + weights.length + fit.length,
          intOffset: intOffset,
          intCount: 5,
          flags: closed ? FcbFlags.closed : 0,
        );

      case TextEntity():
        final (stringOffset, stringCount) = _strings.internRun([
          entity.content,
          entity.styleName,
        ]);
        return _Payload(
          geomOffset: _doubles.addAll([
            entity.position.x,
            entity.position.y,
            entity.height,
            entity.rotation,
            entity.widthFactor,
            entity.obliqueAngle,
          ]),
          geomCount: 6,
          intOffset: _ints.addAll([
            entity.hAlign.index,
            entity.vAlign.index,
          ]),
          intCount: 2,
          stringOffset: stringOffset,
          stringCount: stringCount,
        );

      case MTextEntity():
        final (stringOffset, stringCount) = _strings.internRun([
          entity.content,
          entity.styleName,
        ]);
        return _Payload(
          geomOffset: _doubles.addAll([
            entity.position.x,
            entity.position.y,
            entity.height,
            entity.rotation,
            entity.rectangleWidth,
          ]),
          geomCount: 5,
          intOffset: _ints.addAll([entity.attachment]),
          intCount: 1,
          stringOffset: stringOffset,
          stringCount: stringCount,
        );

      case InsertEntity():
        final (stringOffset, stringCount) = _strings.internRun([
          entity.blockName,
        ]);
        return _Payload(
          geomOffset: _doubles.addAll([
            entity.position.x,
            entity.position.y,
            entity.scale.x,
            entity.scale.y,
            entity.rotation,
            entity.columnSpacing,
            entity.rowSpacing,
          ]),
          geomCount: 7,
          intOffset: _ints.addAll([entity.columnCount, entity.rowCount]),
          intCount: 2,
          stringOffset: stringOffset,
          stringCount: stringCount,
        );

      case HatchEntity():
        final ints = <int>[entity.loops.length];
        final coordinates = <double>[
          entity.patternAngle,
          entity.patternScale,
        ];
        for (final loop in entity.loops) {
          ints.add(loop.isOuter ? 1 : 0);
          ints.add(loop.pointCount);
          for (var i = 0; i < loop.vertices.length; i++) {
            coordinates.add(loop.vertices[i]);
          }
        }
        final (stringOffset, stringCount) = _strings.internRun([
          entity.patternName,
        ]);
        return _Payload(
          geomOffset: _doubles.addAll(coordinates),
          geomCount: coordinates.length,
          intOffset: _ints.addAll(ints),
          intCount: ints.length,
          stringOffset: stringOffset,
          stringCount: stringCount,
          flags: entity.solid ? FcbFlags.solidFill : 0,
        );

      case DimensionEntity():
        final coordinates = <double>[
          entity.textPosition.x,
          entity.textPosition.y,
          entity.measurement,
          for (final point in entity.definitionPoints) ...[point.x, point.y],
        ];
        final (stringOffset, stringCount) = _strings.internRun([
          entity.blockName,
          entity.overrideText,
          entity.styleName,
        ]);
        return _Payload(
          geomOffset: _doubles.addAll(coordinates),
          geomCount: coordinates.length,
          intOffset: _ints.addAll([
            entity.dimensionType,
            entity.definitionPoints.length,
          ]),
          intCount: 2,
          stringOffset: stringOffset,
          stringCount: stringCount,
        );

      case LeaderEntity():
        final (stringOffset, stringCount) = _strings.internRun([
          entity.styleName,
        ]);
        return _Payload(
          geomOffset: _doubles.addBuffer(entity.vertices),
          geomCount: entity.vertices.length,
          stringOffset: stringOffset,
          stringCount: stringCount,
          flags: entity.hasArrowHead ? FcbFlags.arrowHead : 0,
        );

      case SolidEntity(:final corners):
        return _geom([
          for (final corner in corners) ...[corner.x, corner.y],
        ]);

      case RayEntity(:final origin, :final direction):
        return _geom([origin.x, origin.y, direction.x, direction.y]);

      case XLineEntity(:final origin, :final direction):
        return _geom([origin.x, origin.y, direction.x, direction.y]);

      case ImageEntity():
        final (stringOffset, stringCount) = _strings.internRun([
          entity.reference,
        ]);
        return _Payload(
          geomOffset: _doubles.addAll([
            entity.origin.x,
            entity.origin.y,
            entity.uVector.x,
            entity.uVector.y,
            entity.vVector.x,
            entity.vVector.y,
          ]),
          geomCount: 6,
          stringOffset: stringOffset,
          stringCount: stringCount,
        );

      case UnknownEntity(:final originalType, :final proxyBounds):
        final (stringOffset, stringCount) = _strings.internRun([originalType]);
        return _Payload(
          geomOffset: _doubles.addAll([
            proxyBounds.isEmpty ? 0 : proxyBounds.minX,
            proxyBounds.isEmpty ? 0 : proxyBounds.minY,
            proxyBounds.isEmpty ? 0 : proxyBounds.maxX,
            proxyBounds.isEmpty ? 0 : proxyBounds.maxY,
          ]),
          geomCount: 4,
          stringOffset: stringOffset,
          stringCount: stringCount,
        );
    }
  }

  _Payload _geom(List<double> values) => _Payload(
    geomOffset: _doubles.addAll(values),
    geomCount: values.length,
  );

  // -------------------------------------------------------------------------
  // Tables
  // -------------------------------------------------------------------------

  Uint8List _encodeLayers(
    CadDocument document,
    List<String> names,
    Map<String, int> lineTypeIndex,
  ) {
    final buffer = Uint8List(8 + names.length * FcbRecord.layer);
    final view = ByteData.view(buffer.buffer);
    view.setUint64(0, names.length, Endian.little);
    for (var i = 0; i < names.length; i++) {
      final layer = document.layers[names[i]]!;
      final at = 8 + i * FcbRecord.layer;
      view.setUint32(at + FcbLayer.name, _strings.intern(layer.name), Endian.little);
      view.setUint32(
        at + FcbLayer.colorPacked,
        _packEntityColor(layer.color),
        Endian.little,
      );
      view.setUint32(
        at + FcbLayer.lineTypeIndex,
        lineTypeIndex[layer.lineType] ?? 0,
        Endian.little,
      );
      view.setInt32(at + FcbLayer.lineWeight, layer.lineWeight, Endian.little);
      var flags = 0;
      if (!layer.visible) flags |= FcbLayerFlags.hidden;
      if (layer.frozen) flags |= FcbLayerFlags.frozen;
      if (layer.locked) flags |= FcbLayerFlags.locked;
      if (!layer.plottable) flags |= FcbLayerFlags.noPlot;
      view.setUint32(at + FcbLayer.flags, flags, Endian.little);
      view.setInt32(
        at + FcbLayer.transparency,
        layer.transparency,
        Endian.little,
      );
    }
    return buffer;
  }

  Uint8List _encodeLineTypes(CadDocument document, List<String> names) {
    final buffer = Uint8List(
      alignUp8(8 + names.length * FcbRecord.lineType),
    );
    final view = ByteData.view(buffer.buffer);
    view.setUint64(0, names.length, Endian.little);
    for (var i = 0; i < names.length; i++) {
      final lineType = document.lineTypes[names[i]]!;
      final at = 8 + i * FcbRecord.lineType;
      view.setUint32(
        at + FcbLineType.name,
        _strings.intern(lineType.name),
        Endian.little,
      );
      view.setUint32(
        at + FcbLineType.description,
        _strings.intern(lineType.description),
        Endian.little,
      );
      view.setUint32(
        at + FcbLineType.patternOffset,
        _doubles.addAll(lineType.pattern),
        Endian.little,
      );
      view.setUint32(
        at + FcbLineType.patternCount,
        lineType.pattern.length,
        Endian.little,
      );
      view.setFloat64(
        at + FcbLineType.patternLength,
        lineType.patternLength,
        Endian.little,
      );
    }
    return buffer;
  }

  Uint8List _encodeTextStyles(CadDocument document) {
    final styles = document.textStyles.values.toList();
    final buffer = Uint8List(8 + styles.length * FcbRecord.textStyle);
    final view = ByteData.view(buffer.buffer);
    view.setUint64(0, styles.length, Endian.little);
    for (var i = 0; i < styles.length; i++) {
      final style = styles[i];
      final at = 8 + i * FcbRecord.textStyle;
      view.setUint32(
        at + FcbTextStyle.name,
        _strings.intern(style.name),
        Endian.little,
      );
      view.setUint32(
        at + FcbTextStyle.font,
        _strings.intern(style.fontFamily),
        Endian.little,
      );
      view.setUint32(
        at + FcbTextStyle.bigFont,
        _strings.intern(style.bigFontFamily),
        Endian.little,
      );
      var flags = 0;
      if (style.backwards) flags |= 1;
      if (style.upsideDown) flags |= 2;
      view.setUint32(at + FcbTextStyle.flags, flags, Endian.little);
      view.setFloat64(at + FcbTextStyle.height, style.height, Endian.little);
      view.setFloat64(
        at + FcbTextStyle.widthFactor,
        style.widthFactor,
        Endian.little,
      );
      view.setFloat64(
        at + FcbTextStyle.obliqueAngle,
        style.obliqueAngle,
        Endian.little,
      );
    }
    return buffer;
  }

  Uint8List _encodeBlocks(
    CadDocument document,
    List<String> names,
    Map<String, (int, int)> ranges,
  ) {
    final buffer = Uint8List(8 + names.length * FcbRecord.block);
    final view = ByteData.view(buffer.buffer);
    view.setUint64(0, names.length, Endian.little);
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final block =
          document.blocks[name] ??
          BlockRecord(name: name, isLayoutBlock: true);
      final range = ranges[name] ?? (0, 0);
      final at = 8 + i * FcbRecord.block;
      view.setFloat64(at + FcbBlock.baseX, block.basePoint.x, Endian.little);
      view.setFloat64(at + FcbBlock.baseY, block.basePoint.y, Endian.little);
      view.setUint32(at + FcbBlock.name, _strings.intern(name), Endian.little);
      var flags = 0;
      if (block.isLayoutBlock) flags |= FcbBlockFlags.layout;
      if (block.isAnonymous) flags |= FcbBlockFlags.anonymous;
      if (block.isXref) flags |= FcbBlockFlags.xref;
      view.setUint32(at + FcbBlock.flags, flags, Endian.little);
      view.setUint32(at + FcbBlock.entityFirst, range.$1, Endian.little);
      view.setUint32(at + FcbBlock.entityCount, range.$2, Endian.little);
      view.setUint32(
        at + FcbBlock.xrefPath,
        _strings.intern(block.xrefPath),
        Endian.little,
      );
      view.setUint32(
        at + FcbBlock.description,
        _strings.intern(block.description),
        Endian.little,
      );
      view.setUint64(at + FcbBlock.handle, 0, Endian.little);
    }
    return buffer;
  }

  Uint8List _encodeLayouts(
    CadDocument document,
    Map<String, int> blockIndex,
  ) {
    final layouts = document.layouts;
    final buffer = Uint8List(8 + layouts.length * FcbRecord.layout);
    final view = ByteData.view(buffer.buffer);
    view.setUint64(0, layouts.length, Endian.little);
    for (var i = 0; i < layouts.length; i++) {
      final layout = layouts[i];
      final at = 8 + i * FcbRecord.layout;
      view.setUint32(
        at + FcbLayout.name,
        _strings.intern(layout.name),
        Endian.little,
      );
      view.setUint32(
        at + FcbLayout.blockIndex,
        blockIndex[layout.blockName] ?? 0,
        Endian.little,
      );
      view.setUint32(
        at + FcbLayout.flags,
        layout.isModelSpace ? FcbLayoutFlags.modelSpace : 0,
        Endian.little,
      );
      view.setUint32(at + FcbLayout.tabOrder, layout.tabOrder, Endian.little);
      view.setFloat64(
        at + FcbLayout.paperWidth,
        layout.paperWidth,
        Endian.little,
      );
      view.setFloat64(
        at + FcbLayout.paperHeight,
        layout.paperHeight,
        Endian.little,
      );
    }
    return buffer;
  }

  Uint8List _encodeHeaderVariables(CadDocument document) {
    final entries = document.headerVariables.entries.toList();
    final buffer = Uint8List(alignUp8(8 + entries.length * 8));
    final view = ByteData.view(buffer.buffer);
    view.setUint64(0, entries.length, Endian.little);
    for (var i = 0; i < entries.length; i++) {
      view.setUint32(
        8 + i * 8,
        _strings.intern(entries[i].key),
        Endian.little,
      );
      view.setUint32(
        8 + i * 8 + 4,
        _strings.intern(entries[i].value),
        Endian.little,
      );
    }
    return buffer;
  }

  Uint8List _encodeDoublePool() {
    final values = _doubles.view();
    final buffer = Uint8List(8 + values.length * 8);
    ByteData.view(buffer.buffer).setUint64(0, values.length, Endian.little);
    Float64List.view(buffer.buffer, 8, values.length).setAll(0, values);
    return buffer;
  }

  Uint8List _encodeIntPool() {
    final values = _ints.view();
    final buffer = Uint8List(8 + values.length * 8);
    ByteData.view(buffer.buffer).setUint64(0, values.length, Endian.little);
    Int64List.view(buffer.buffer, 8, values.length).setAll(0, values);
    return buffer;
  }

  static Uint8List _withCountHeader(int count, Uint8List payload) {
    final buffer = Uint8List(8 + payload.length);
    ByteData.view(buffer.buffer).setUint64(0, count, Endian.little);
    buffer.setRange(8, 8 + payload.length, payload);
    return buffer;
  }

  static Uint8List _padded(Uint8List payload) {
    final size = alignUp8(payload.length);
    if (size == payload.length) return payload;
    return Uint8List(size)..setRange(0, payload.length, payload);
  }

  static int _packEntityColor(CadColor color) => packColor(
    switch (color.kind) {
      ColorKind.byLayer => FcbColorKind.byLayer,
      ColorKind.byBlock => FcbColorKind.byBlock,
      ColorKind.indexed => FcbColorKind.indexed,
      ColorKind.trueColor => FcbColorKind.trueColor,
    },
    color.value,
  );

  static int _typeCode(EntityKind kind) => switch (kind) {
    EntityKind.line => FcbType.line,
    EntityKind.polyline => FcbType.polyline,
    EntityKind.circle => FcbType.circle,
    EntityKind.arc => FcbType.arc,
    EntityKind.ellipse => FcbType.ellipse,
    EntityKind.spline => FcbType.spline,
    EntityKind.point => FcbType.point,
    EntityKind.text => FcbType.text,
    EntityKind.mtext => FcbType.mtext,
    EntityKind.insert => FcbType.insert,
    EntityKind.hatch => FcbType.hatch,
    EntityKind.dimension => FcbType.dimension,
    EntityKind.leader => FcbType.leader,
    EntityKind.solid => FcbType.solid,
    EntityKind.ray => FcbType.ray,
    EntityKind.xline => FcbType.xline,
    EntityKind.image => FcbType.image,
    EntityKind.unknown => FcbType.unknown,
  };
}

class _Payload {
  const _Payload({
    this.geomOffset = 0,
    this.geomCount = 0,
    this.intOffset = 0,
    this.intCount = 0,
    this.stringOffset = 0,
    this.stringCount = 0,
    this.flags = 0,
  });

  final int geomOffset;
  final int geomCount;
  final int intOffset;
  final int intCount;
  final int stringOffset;
  final int stringCount;
  final int flags;
}
