import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'aci_palette.dart';
import 'bit_reader.dart';
import 'model.dart';
import 'r2004_container.dart';
import 'r2007_container.dart';
part 'reader/entities_dimension.dart';
part 'reader/common.dart';
part 'reader/tables.dart';
part 'reader/entities_text.dart';
part 'reader/entities_geometry.dart';
part 'reader/entities_leader.dart';
part 'reader/entities_hatch.dart';
part 'reader/entities_image.dart';
part 'reader/entities_insert.dart';
part 'reader/entities_region.dart';
part 'reader/header.dart';
part 'reader/objects.dart';

/// The pure-Dart DWG reader.
///
/// Selects the container by file magic: R13-R2000 use the section locator,
/// R2004/R2010+ the page and section maps, and R2007 its RS/LZ77 layout. On
/// top of that it walks the object map, decodes common entity data, tables and
/// the supported entity types into a [DwgDrawing].
final class DwgReader {
  DwgReader._();

  static const _typeVertex2d = 0x0a;
  static const _typeVertex3d = 0x0b;
  static const _typeVertexMesh = 0x0c;
  static const _typeVertexPface = 0x0d;
  static const _typeVertexPfaceFace = 0x0e;
  static const _typePolyline2d = 0x0f;
  static const _typePolyline3d = 0x10;
  static const _typePolylinePface = 0x1d;
  static const _typePolylineMesh = 0x1e;
  static const _typeShape = 0x21;
  static const _typeOle2Frame = 0x4a;
  static const _typeViewport = 0x22;
  static const _typeText = 0x01;
  static const _typeInsert = 0x07;
  static const _typeMinsert = 0x08;
  static const _typeAttrib = 0x02;
  static const _typeAttdef = 0x03;
  static const _typeArc = 0x11;
  static const _typeCircle = 0x12;
  static const _typeLine = 0x13;
  static const _typeLayer = 0x33;
  static const _typeBlockHeader = 0x31;
  static const _typeStyle = 0x35;
  static const _typeLtype = 0x39;
  static const _typeUcs = 0x3f;
  static const _typeVport = 0x41;
  static const _typeAppId = 0x43;
  static const _typeDimStyle = 0x45;
  static const _typeLayout = 0x52;
  static const _typePoint = 0x1b;
  static const _type3dFace = 0x1c;
  static const _typeEllipse = 0x23;
  static const _typeSolid = 0x1f;
  static const _typeMtext = 0x2c;
  static const _typeSpline = 0x24;
  static const _typeRay = 0x28;
  static const _typeXline = 0x29;
  static const _typeLeader = 0x2d;
  static const _typeMline = 0x2f;
  static const _typeTolerance = 0x2e;
  static const _typeTrace = 0x20;
  static const _typeLwPolyline = 0x4d;
  static const _typeHatch = 0x4e;
  static const _typeDimOrdinate = 0x14;
  static const _typeDimLinear = 0x15;
  static const _typeDimAligned = 0x16;
  static const _typeDimAng3pt = 0x17;
  static const _typeDimAng2ln = 0x18;
  static const _typeDimRadius = 0x19;
  static const _typeDimDiameter = 0x1a;
  static const _typeRegion = 0x25;
  static const _type3dSolid = 0x26;
  static const _typeBody = 0x27;

  static const _coreTypes = {
    _typeText,
    _typeAttrib,
    _typeAttdef,
    _typeInsert,
    _typeMinsert,
    _typeArc,
    _typeCircle,
    _typeLine,
    _typePoint,
    _type3dFace,
    _typeEllipse,
    _typeMtext,
    _typeSpline,
    _typeRay,
    _typeXline,
    _typeHatch,
    _typeDimOrdinate,
    _typeDimLinear,
    _typeDimAligned,
    _typeDimAng3pt,
    _typeDimAng2ln,
    _typeDimRadius,
    _typeDimDiameter,
    _typeRegion,
    _type3dSolid,
    _typeBody,
    _typeLeader,
    _typeMline,
    _typeTolerance,
    _typeTrace,
    _typeSolid,
    _typeLwPolyline,
    _typePolyline2d,
    _typeVertex2d,
    _typePolyline3d,
    _typeVertex3d,
    _typePolylinePface,
    _typeVertexPface,
    _typeVertexPfaceFace,
    _typePolylineMesh,
    _typeVertexMesh,
    _typeShape,
    _typeOle2Frame,
    _typeViewport,
  };

  /// Fixed non-entity object types, from the reference decoder's DWG_TYPE_* table.
  static const _objectTypeNames = {
    0x2a: 'DICTIONARY',
    0x30: 'BLOCK_CONTROL',
    0x32: 'LAYER_CONTROL',
    0x34: 'STYLE_CONTROL',
    0x38: 'LTYPE_CONTROL',
    0x3c: 'VIEW_CONTROL',
    0x3d: 'VIEW',
    0x3e: 'UCS_CONTROL',
    0x40: 'VPORT_CONTROL',
    0x42: 'APPID_CONTROL',
    0x44: 'DIMSTYLE_CONTROL',
    0x46: 'VX_CONTROL',
    0x47: 'VX_TABLE_RECORD',
    0x48: 'GROUP',
    0x49: 'MLINESTYLE',
    0x4a: 'OLE2FRAME',
    0x4b: 'DUMMY',
    0x4c: 'LONG_TRANSACTION',
    0x4f: 'XRECORD',
    0x50: 'PLACEHOLDER',
    0x51: 'VBA_PROJECT',
    0x1f3: 'PROXY_OBJECT',
  };

  static const _structuralEntities = {0x04, 0x05, 0x06};

  static const _typeNames = {
    _typeText: 'TEXT',
    _typeAttrib: 'ATTRIB',
    _typeAttdef: 'ATTDEF',
    _typeInsert: 'INSERT',
    _typeMinsert: 'MINSERT',
    _typeArc: 'ARC',
    _typeCircle: 'CIRCLE',
    _typeLine: 'LINE',
    _typePoint: 'POINT',
    _type3dFace: '3DFACE',
    _typeEllipse: 'ELLIPSE',
    _typeMtext: 'MTEXT',
    _typeSpline: 'SPLINE',
    _typeRay: 'RAY',
    _typeXline: 'XLINE',
    _typeHatch: 'HATCH',
    _typeDimOrdinate: 'DIMENSION_ORDINATE',
    _typeDimLinear: 'DIMENSION_LINEAR',
    _typeDimAligned: 'DIMENSION_ALIGNED',
    _typeDimAng3pt: 'DIMENSION_ANG3PT',
    _typeDimAng2ln: 'DIMENSION_ANG2LN',
    _typeDimRadius: 'DIMENSION_RADIUS',
    _typeDimDiameter: 'DIMENSION_DIAMETER',
    _typeRegion: 'REGION',
    _type3dSolid: '3DSOLID',
    _typeBody: 'BODY',
    _typeLeader: 'LEADER',
    _typeMline: 'MLINE',
    _typeTolerance: 'TOLERANCE',
    _typeTrace: 'TRACE',
    _typeSolid: 'SOLID',
    _typeLwPolyline: 'LWPOLYLINE',
    _typePolyline2d: 'POLYLINE_2D',
    _typeVertex2d: 'VERTEX_2D',
    _typePolyline3d: 'POLYLINE_3D',
    _typeVertex3d: 'VERTEX_3D',
    _typePolylinePface: 'POLYLINE_PFACE',
    _typeVertexPface: 'VERTEX_PFACE',
    _typeVertexPfaceFace: 'VERTEX_PFACE_FACE',
    _typePolylineMesh: 'POLYLINE_MESH',
    _typeVertexMesh: 'VERTEX_MESH',
    _typeShape: 'SHAPE',
    _typeOle2Frame: 'OLE2FRAME',
    _typeViewport: 'VIEWPORT',
  };

  late Uint8List _data;
  late Uint8List _handles;
  late int _handlesStart;
  late int _handlesSize;
  late int _version;
  late int _dwgVersion;

  final Map<int, int> _counts = {};
  final Map<int, DwgLayer> _layers = {};
  final Map<int, DwgBlock> _blocks = {};
  final Map<int, DwgStyle> _styles = {};
  final Map<int, DwgLinetype> _linetypes = {};
  final Map<int, DwgAppId> _appIds = {};
  final Map<int, DwgUcs> _ucs = {};
  final Map<int, DwgVPort> _vports = {};
  final Map<int, DwgDimStyle> _dimStyles = {};
  final Map<int, DwgLayout> _layoutRecords = {};
  final Map<int, DwgObject> _otherObjects = {};
  Map<String, Object?> _headerVariables = const {};
  late int _maintVersion;
  final Map<int, String> _classNames = {};
  final Map<int, bool> _classIsEntity = {};
  final Map<int, String> _imageDefs = {};

  late final DwgBitReader _objectReader = DwgBitReader(_data);
  late final DwgBitReader _probeReader = DwgBitReader(_data);
  late final DwgBitReader _strReader = DwgBitReader(_data);

  int _entmode = 0;
  int _numReactors = 0;
  int _colorIndex = 256;
  int? _colorRgb;
  int _alpha = 255;
  int _alphaType = 0;
  int _invisible = 0;
  int _nolinks = 1;
  bool _isXdicMissing = false;
  int _ltypeFlags = 0;
  int _plotstyleFlags = 0;
  double _lineTypeScale = 1;
  int _lineWeight = 29;
  int _lastViewportFrozen = 0;

  static DwgDrawing readFile(String path) =>
      readBytes(File(path).readAsBytesSync());

  /// True when the bytes start with an R13-R2018 version code.
  static bool supportsBytes(Uint8List data) {
    if (data.length < 6) return false;
    final magic = String.fromCharCodes(data.sublist(0, 6));
    return magic == 'AC1012' ||
        magic == 'AC1014' ||
        magic == 'AC1015' ||
        magic == 'AC1018' ||
        magic == 'AC1021' ||
        magic == 'AC1024' ||
        magic == 'AC1027' ||
        magic == 'AC1032';
  }

  /// Reads only the version magic, so a capability probe does not load a
  /// multi-megabyte drawing.
  static bool supportsFile(String path) {
    RandomAccessFile? file;
    try {
      file = File(path).openSync();
      return supportsBytes(file.readSync(6));
    } catch (_) {
      return false;
    } finally {
      file?.closeSync();
    }
  }

  static DwgDrawing readBytes(Uint8List data) {
    final reader = DwgReader._().._load(data);
    return reader._read();
  }

  void _load(Uint8List data) {
    if (data.length < 0x22 || data[0] != 0x41 || data[1] != 0x43) {
      throw const FormatException('not a DWG file');
    }
    final magic = String.fromCharCodes(data.sublist(0, 6));
    DwgBitReader.defaultCodepage = data.length > 0x14
        ? ((data[0x13] | (data[0x14] << 8)) & 0xffff)
        : 0;
    final version = switch (magic) {
      'AC1032' => 2018,
      'AC1027' => 2013,
      'AC1024' => 2010,
      'AC1021' => 2007,
      'AC1018' => 2004,
      'AC1015' => 2000,
      'AC1014' => 14,
      'AC1012' => 13,
      _ => 0,
    };
    if (version == 0) {
      throw FormatException('unsupported DWG version $magic');
    }
    _version = version;
    _dwgVersion = data.length > 0x11 ? data[0x11] : 0;
    _maintVersion = data.length > 0x12 ? data[0x12] : 0;
    if (version >= 2004 && version != 2007) {
      final container = R2004Container.read(data);
      _data = container.readSection('AcDb:AcDbObjects');
      _handles = container.readSection('AcDb:Handles');
      _handlesStart = 0;
      _handlesSize = _handles.length;
      if (container.infoNamed('AcDb:Header') != null) {
        _readHeaderPacked(container.readSection('AcDb:Header'));
      }
      final classes = container.readSection('AcDb:Classes');
      if (version >= 2007) {
        _readClassesR2007(classes);
      } else {
        _readClassesR2004(classes);
      }
      return;
    }
    if (version == 2007) {
      final container = R2007Container.read(data);
      _data = container.readSection('AcDb:AcDbObjects') ?? Uint8List(0);
      _handles = container.readSection('AcDb:Handles') ?? Uint8List(0);
      _handlesStart = 0;
      _handlesSize = _handles.length;
      final header = container.readSection('AcDb:Header');
      if (header != null) _readHeaderPacked(header);
      final classes = container.readSection('AcDb:Classes');
      if (classes != null) _readClassesR2007(classes);
      return;
    }

    final sectionCount = _u32le(data, 0x15);
    if (sectionCount == 0 ||
        sectionCount > 8 ||
        0x19 + sectionCount * 9 > data.length) {
      throw const FormatException('invalid section locator');
    }
    final sections = <int, _Section>{};
    for (var i = 0; i < sectionCount; i++) {
      final at = 0x19 + i * 9;
      final section = _Section(
        number: data[at],
        address: _u32le(data, at + 1),
        size: _u32le(data, at + 5),
      );
      if (section.address + section.size > data.length) {
        throw const FormatException('section outside file');
      }
      sections[section.number] = section;
    }
    final handles = sections[2];
    if (handles == null) {
      throw const FormatException('object map section is missing');
    }
    _data = data;
    _handles = data;
    _handlesStart = handles.address;
    _handlesSize = handles.size;
    final classes = sections[1];
    if (classes != null) _readClassesR2000(data, classes);
    final header = sections[0];
    if (header != null) {
      _readHeaderClassic(data, header.address, header.size);
    }
  }

  DwgDrawing _read() {
    final entities = <DwgEntity>[];
    var objectCount = 0;

    for (final offset in decodeObjectMapOffsets(
      _handles,
      start: _handlesStart,
      length: _handlesSize,
    )) {
      if (offset < 0 || offset >= _data.length) continue;
      objectCount++;
      try {
        final entity = _decodeObject(offset);
        if (entity != null) {
          entities.add(entity);
          _counts[entity.type] = (_counts[entity.type] ?? 0) + 1;
        }
      } on _InvalidObject {
        // Free space or a malformed record: skip it but keep walking.
      }
    }

    return DwgDrawing(
      version: _version,
      objectCount: objectCount,
      entities: entities,
      counts: Map.unmodifiable(_counts),
      layers: Map.unmodifiable(_layers),
      blocks: Map.unmodifiable(_blocks),
      imageDefs: Map.unmodifiable(_imageDefs),
      styles: Map.unmodifiable(_styles),
      linetypes: Map.unmodifiable(_linetypes),
      appIds: Map.unmodifiable(_appIds),
      ucs: Map.unmodifiable(_ucs),
      vports: Map.unmodifiable(_vports),
      dimStyles: Map.unmodifiable(_dimStyles),
      headerVariables: Map.unmodifiable(_headerVariables),
      layouts: Map.unmodifiable(_layoutRecords),
      otherObjects: Map.unmodifiable(_otherObjects),
    );
  }

  /// Reads the per-page handle/offset deltas and returns each object address.
  ///
  /// The offset delta is relative to the start of its handles page, not to the
  /// previous page. Files with several pages (common in large drawings) depend
  /// on that reset.
  @visibleForTesting
  static List<int> decodeObjectMapOffsets(
    Uint8List handles, {
    int start = 0,
    int? length,
  }) {
    final offsets = <int>[];
    final end = (start + (length ?? (handles.length - start))).clamp(
      0,
      handles.length,
    );
    var position = start;
    final reader = DwgBitReader(handles);
    while (position + 2 <= end) {
      final pageStart = position;
      final pageSize = _u16be(handles, position);
      position += 2;
      if (pageSize < 2) break;
      final pageEnd = pageStart + pageSize;
      if (pageEnd > end) {
        throw const FormatException('object map page outside section');
      }
      var lastOffset = 0;
      while (position < pageEnd) {
        reader
          ..bitPos = position * 8
          ..limitBits = null
          ..ok = true;
        reader.umc(); // handle delta; the object carries its own handle
        final offset = reader.mc();
        if (!reader.ok || (reader.bitPos & 7) != 0) {
          throw const FormatException('invalid object map entry');
        }
        position = reader.bitPos >> 3;
        lastOffset += offset;
        offsets.add(lastOffset);
      }
      // Page CRC, big-endian.
      position = pageEnd + 2;
    }
    return offsets;
  }

  DwgEntity? _decodeObject(int offset) {
    final br = _objectReader
      ..bitPos = offset * 8
      ..limitBits = null
      ..ok = true;
    final size = br.ms();
    if (!br.ok || size == 0 || br.bitPos + size * 8 > _data.length * 8) {
      throw const _InvalidObject();
    }
    var objectStartBit = br.bitPos;
    final int type;
    var bitsize = 0;
    var ownHandle = 0;
    var eedRead = false;
    if (_version >= 2010) {
      final handleBits = br.umc();
      objectStartBit = br.bitPos;
      br.limitBits = objectStartBit + size * 8;
      type = br.bot();
      bitsize = size * 8 - handleBits;
    } else if (_version >= 2000) {
      br.limitBits = objectStartBit + size * 8;
      type = br.bs();
      bitsize = br.rl(); // start of the handle stream, relative to type
    } else {
      // R13/R14 put the object's own handle, its EED and the preview bitmap
      // ahead of the bitsize that locates the handle stream. Reading the RL
      // straight after the type — the R2000 order — lands in the middle of
      // the handle and makes every object look like garbage.
      br.limitBits = objectStartBit + size * 8;
      type = br.bs();
      ownHandle = br.h();
      if (!br.ok || ownHandle == 0) throw const _InvalidObject();
      _skipEed(br);
      eedRead = true;
      // Only entities carry the preview bitmap; table records and other
      // objects go straight to the bitsize.
      final isEntity = type >= 500
          ? (_classIsEntity[type] ?? false)
          : _coreTypes.contains(type);
      if (isEntity) {
        final preview = br.b();
        if (preview != 0) {
          final previewSize = br.rl();
          br.skip(previewSize * 8);
        }
      }
      bitsize = br.rl();
    }
    _str = null;
    if (_version >= 2007 && bitsize > 17) {
      final probe = _probeReader
        ..bitPos = objectStartBit + bitsize - 1
        ..limitBits = br.limitBits
        ..ok = true;
      if (probe.b() != 0) {
        probe
          ..bitPos = objectStartBit + bitsize - 17
          ..ok = true;
        final length = probe.rs();
        final start = objectStartBit + bitsize - length - 17;
        if (length > 0 && start >= objectStartBit) {
          _str = _strReader
            ..bitPos = start
            ..limitBits = start + length
            ..ok = true;
        }
      }
    }
    if (ownHandle == 0) {
      ownHandle = br.h();
      if (!br.ok || ownHandle == 0) throw const _InvalidObject();
    }

    if (type == _typeLayer) {
      if (!eedRead) _skipEed(br);
      final layer = _readLayer(
        br,
        ownHandle,
        objectStartBit,
        bitsize,
        br.limitBits,
      );
      if (layer != null) _layers[ownHandle] = layer;
      return null;
    }
    if (type == _typeBlockHeader) {
      if (!eedRead) _skipEed(br);
      final block = _readBlockHeader(br, ownHandle);
      if (block != null) _blocks[ownHandle] = block;
      return null;
    }
    if (type == _typeStyle) {
      if (!eedRead) _skipEed(br);
      final style = _readStyle(br, ownHandle);
      if (style != null) _styles[ownHandle] = style;
      return null;
    }
    if (type == _typeLtype) {
      if (!eedRead) _skipEed(br);
      final ltype = _readLinetype(br, ownHandle);
      if (ltype != null) _linetypes[ownHandle] = ltype;
      return null;
    }
    if (type == _typeAppId) {
      if (!eedRead) _skipEed(br);
      final appId = _readAppId(br, ownHandle);
      if (appId != null) _appIds[ownHandle] = appId;
      return null;
    }
    if (type == _typeUcs) {
      if (!eedRead) _skipEed(br);
      final ucs = _readUcs(br, ownHandle);
      if (ucs != null) _ucs[ownHandle] = ucs;
      return null;
    }
    if (type == _typeVport) {
      if (!eedRead) _skipEed(br);
      final vport = _readVPort(br, ownHandle);
      if (vport != null) _vports[ownHandle] = vport;
      return null;
    }
    if (type == _typeDimStyle) {
      if (!eedRead) _skipEed(br);
      final dimStyle = _readDimStyle(
        br,
        ownHandle,
        objectStartBit,
        bitsize,
        br.limitBits,
      );
      if (dimStyle != null) _dimStyles[ownHandle] = dimStyle;
      return null;
    }
    if (_version >= 2000 && type == _typeLayout) {
      if (!eedRead) _skipEed(br);
      final layout = _readLayout(
        br,
        ownHandle,
        objectStartBit,
        bitsize,
        br.limitBits,
      );
      if (layout != null) _layoutRecords[ownHandle] = layout;
      return null;
    }
    final className = type >= 500 ? _classNames[type] : null;
    if (className == 'LAYOUT') {
      if (!eedRead) _skipEed(br);
      final layout = _readLayout(
        br,
        ownHandle,
        objectStartBit,
        bitsize,
        br.limitBits,
      );
      if (layout != null) _layoutRecords[ownHandle] = layout;
      return null;
    }
    if (className == 'IMAGEDEF') {
      if (!eedRead) _skipEed(br);
      _readImageDef(br, ownHandle);
      return null;
    }
    final isEntityType = type >= 500
        ? (_classIsEntity[type] ?? false)
        : _coreTypes.contains(type) || _structuralEntities.contains(type);
    if (!isEntityType) {
      if (!eedRead) _skipEed(br);
      final typeName = className ?? _objectTypeNames[type] ?? 'UNKNOWN_OBJ';
      _otherObjects[ownHandle] =
          _readOtherObject(
            br,
            ownHandle,
            type,
            typeName,
            objectStartBit,
            bitsize,
            br.limitBits,
          ) ??
          DwgObject(handle: ownHandle, type: type, typeName: typeName);
      return null;
    }
    final isImage = className == 'IMAGE' || className == 'WIPEOUT';
    final isArcDim = className == 'ARC_DIMENSION';
    final isMleader = className == 'MULTILEADER';
    final isLight = className == 'LIGHT';
    // LWPOLYLINE arrived with ObjectDBX and can therefore be a class object
    // (R14 files made by later AutoCAD releases contain one); its stream is
    // the same as the fixed R2000 type.
    final isLwPolylineClass = className == 'LWPOLYLINE';
    final isHatchClass = className == 'HATCH';
    final isUnknownEntity =
        type >= 500 &&
        (_classIsEntity[type] ?? false) &&
        !isImage &&
        !isArcDim &&
        !isMleader &&
        !isLight &&
        !isLwPolylineClass &&
        !isHatchClass;
    if (!_coreTypes.contains(type) &&
        !isImage &&
        !isArcDim &&
        !isMleader &&
        !isLight &&
        !isLwPolylineClass &&
        !isHatchClass &&
        !isUnknownEntity) {
      return null;
    }
    if (isUnknownEntity) {
      if (!eedRead) _skipEed(br);
      _readCommonEntity(br, previewRead: eedRead);
      if (!br.ok) return null;
      final handles = _readHandles(
        objectStartBit,
        bitsize,
        br.limitBits,
        ownHandle,
      );
      return DwgEntity(
        handle: ownHandle,
        type: type,
        // Keep the class name: a TABLE or HELIX is still a known object to
        // the rest of the toolchain, only its geometry is unmodelled.
        typeName: className ?? 'UNKNOWN_ENT',
        values: const [],
        layerHandle: handles.layer,
        ltypeHandle: handles.ltype,
        ltypeFlags: _ltypeFlags,
        lineTypeScale: _lineTypeScale,
        lineWeight: _lineWeight,
        colorIndex: _colorIndex,
        colorRgb: _colorRgb,
        alpha: _alpha,
        alphaType: _alphaType,
        visible: _invisible == 0,
        entmode: _entmode,
        ownerHandle: handles.owner,
      );
    }
    if (!eedRead) _skipEed(br);
    _readCommonEntity(br, previewRead: eedRead);
    if (!br.ok) return null;

    _lastText = '';
    _lastSab = null;
    _lastHatchPathFlags = const [];
    _lastViewportFrozen = 0;
    final values = switch (type) {
      _typeLine => _readLine(br),
      _typeInsert => _readInsert(br),
      _typeMinsert => _readMinsert(br),
      _typeCircle => _readCircle(br),
      _typeArc => _readArc(br),
      _typePoint => _readPoint(br),
      _typeText => _readText(br),
      _typeAttrib => _readAttrib(br),
      _typeAttdef => _readAttdef(br),
      _typeLwPolyline => _readLwPolyline(br),
      _typePolyline2d => _readPolyline2d(br),
      _typeVertex2d => _readVertex2d(br),
      _typePolyline3d => _readPolyline3d(br),
      _typeVertex3d => _readVertex3d(br),
      _typePolylinePface => _readPolylinePface(br),
      _typeVertexPface => _readVertexPface(br),
      _typeVertexPfaceFace => _readVertexPfaceFace(br),
      _typePolylineMesh => _readPolylineMesh(br),
      _typeVertexMesh => _readVertex3d(br),
      _typeShape => _readShape(br),
      _typeOle2Frame => _readOle2Frame(br),
      _typeViewport => _readViewport(br),
      _typeHatch => _readHatch(br),
      _typeDimOrdinate ||
      _typeDimLinear ||
      _typeDimAligned ||
      _typeDimAng3pt ||
      _typeDimAng2ln ||
      _typeDimRadius ||
      _typeDimDiameter => _readDimension(br, type),
      _typeRegion => _readRegion(br, objectStartBit + bitsize),
      _type3dSolid => _readRegion(br, objectStartBit + bitsize),
      _typeBody => _readRegion(br, objectStartBit + bitsize),
      _ when isImage => _readImage(br),
      _ when isArcDim => _readArcDimension(br),
      _ when isMleader => _readMleader(br),
      _ when isLwPolylineClass => _readLwPolyline(br),
      _ when isHatchClass => _readHatch(br),
      _ when isLight => const <double>[],
      _typeSolid => _readSolid(br),
      _type3dFace => _read3dFace(br),
      _typeEllipse => _readEllipse(br),
      _typeMtext => _readMtext(br),
      _typeSpline => _readSpline(br),
      _typeRay => _readRay(br),
      _typeXline => _readRay(br),
      _typeLeader => _readLeader(br),
      _typeMline => _readMline(br),
      _typeTolerance => _readTolerance(br),
      _typeTrace => _readSolid(br),
      _ => const <double>[],
    };
    if (!br.ok) return null;
    final handles = _readHandles(
      objectStartBit,
      bitsize,
      br.limitBits,
      ownHandle,
      wantBlock:
          type == _typeInsert ||
          type == _typeMinsert ||
          _isDimensionType(type) ||
          isArcDim,
      wantDimStyle:
          _isDimensionType(type) ||
          isArcDim ||
          type == _typeTolerance ||
          type == _typeLeader,
      leaderDimStyle: type == _typeLeader,
      wantTextStyle:
          type == _typeText ||
          type == _typeAttrib ||
          type == _typeAttdef ||
          type == _typeMtext ||
          type == _typeShape,
      wantImage: isImage,
      wantViewport: type == _typeViewport,
    );
    return DwgEntity(
      handle: ownHandle,
      type: type,
      typeName: _typeNames[type] ?? className ?? 'TYPE_$type',
      values: values,
      text: _lastText,
      layerHandle: handles.layer,
      ltypeHandle: handles.ltype,
      ltypeFlags: _ltypeFlags,
      lineTypeScale: _lineTypeScale,
      lineWeight: _lineWeight,
      colorIndex: _colorIndex,
      colorRgb: _colorRgb,
      alpha: _alpha,
      alphaType: _alphaType,
      visible: _invisible == 0,
      entmode: _entmode,
      ownerHandle: handles.owner,
      blockHandle: handles.block,
      imageDefHandle: handles.imageDef,
      dimStyleHandle: handles.dimStyle,
      textStyleHandle: handles.textStyle,
      frozenLayerHandles: handles.frozenLayers,
      acisSab: _lastSab,
      hatchPathFlags: _lastHatchPathFlags,
      tag: _lastTag,
      prompt: _lastPrompt,
      attribFlags: _lastFlags,
    );
  }

  /// The handle stream starts at [objectStartBit] + [bitsize]. Owner comes
  /// first for block-owned entities, then reactors, xdic, links and layer.
  ({
    int owner,
    int layer,
    int ltype,
    int block,
    int imageDef,
    int dimStyle,
    int textStyle,
    List<int> frozenLayers,
  })
  _readHandles(
    int objectStartBit,
    int bitsize,
    int? limit,
    int objectHandle, {
    bool wantBlock = false,
    bool wantDimStyle = false,
    bool leaderDimStyle = false,
    bool wantTextStyle = false,
    bool wantImage = false,
    bool wantViewport = false,
  }) {
    if (bitsize <= 0) {
      return (
        owner: 0,
        layer: 0,
        ltype: 0,
        block: 0,
        imageDef: 0,
        dimStyle: 0,
        textStyle: 0,
        frozenLayers: const [],
      );
    }
    final at = objectStartBit + bitsize;
    if (at >= (limit ?? _data.length * 8)) {
      return (
        owner: 0,
        layer: 0,
        ltype: 0,
        block: 0,
        imageDef: 0,
        dimStyle: 0,
        textStyle: 0,
        frozenLayers: const [],
      );
    }
    final h = DwgBitReader(_data)
      ..bitPos = at
      ..limitBits = limit;
    var owner = 0;
    if (_entmode == 0) {
      final raw = h.h();
      owner = _resolveHandle(raw, h.hCode, objectHandle);
    }
    for (var i = 0; i < _numReactors && i < 10000; i++) {
      h.h();
    }
    var ltype = 0;
    final int layer;
    if (_version < 2000) {
      // R13/R14 read the layer before the linetype and the prev/next links.
      h.h(); // xdic
      layer = h.h();
      if (_ltypeFlags == 3) ltype = _handleOf(h, objectHandle);
      if (_nolinks == 0) {
        h.h(); // prev_entity
        h.h(); // next_entity
      }
    } else {
      if (_version >= 2004) {
        if (!_isXdicMissing) h.h(); // xdic
      } else {
        h.h(); // xdic
        if (_nolinks == 0) {
          h.h(); // prev_entity
          h.h(); // next_entity
        }
      }
      layer = h.h();
      if (_ltypeFlags == 3) ltype = _handleOf(h, objectHandle);
      if (_plotstyleFlags == 3) h.h();
    }
    var dimStyle = 0;
    if (wantDimStyle) {
      // LEADER stores its associated annotation before the DIMSTYLE.
      if (leaderDimStyle) h.h();
      dimStyle = _handleOf(h, objectHandle);
    }
    var textStyle = 0;
    if (wantTextStyle) textStyle = _handleOf(h, objectHandle);
    var block = 0;
    if (wantBlock) {
      final raw = h.h();
      block = _resolveHandle(raw, h.hCode, objectHandle);
    }
    var imageDef = 0;
    if (wantImage) {
      final raw = h.h();
      imageDef = _resolveHandle(raw, h.hCode, objectHandle);
    }
    final frozenLayers = <int>[];
    if (wantViewport && _version >= 2000) {
      // VIEWPORT-specific handles: per-window frozen layers, then clipping
      // and UCS handles that the document does not need.
      for (var i = 0; i < _lastViewportFrozen && i < 10000; i++) {
        frozenLayers.add(_handleOf(h, objectHandle));
      }
    }
    return (
      owner: owner,
      layer: h.ok ? layer : 0,
      ltype: ltype,
      block: block,
      imageDef: imageDef,
      dimStyle: dimStyle,
      textStyle: textStyle,
      frozenLayers: frozenLayers,
    );
  }

  /// Relative handles: 6 = object+1, 8 = object-1, 10 = object+value,
  /// 12 = object-value, 14 = object. Codes 0-5 are absolute.
  int _resolveHandle(int value, int code, int objectHandle) {
    return switch (code) {
      6 => objectHandle + 1,
      8 => objectHandle - 1,
      10 => objectHandle + value,
      12 => objectHandle - value,
      14 => objectHandle,
      _ => value,
    };
  }

  /// Reads one handle and resolves it against the object that owns it.
  int _handleOf(DwgBitReader br, int objectHandle) {
    final value = br.h();
    return br.ok ? _resolveHandle(value, br.hCode, objectHandle) : 0;
  }

  DwgBitReader? _str;

  String _text(DwgBitReader br) {
    if (_version < 2007) return br.tv();
    final str = _str;
    if (str == null) return '';
    final length = str.bs();
    if (!str.ok || length < 0 || length > 1000000) return '';
    final units = <int>[];
    for (var i = 0; i < length; i++) {
      units.add(str.rs());
    }
    return expandDwgTextEscapes(String.fromCharCodes(units));
  }

  String _lastText = '';
  String _lastTag = '';
  String _lastPrompt = '';
  int _lastFlags = 0;
  Uint8List? _lastSab;
  List<int> _lastHatchPathFlags = const [];

  void _readImageDef(DwgBitReader br, int handle) {
    br.bl(); // num_reactors (object common data)
    if (_version >= 2004) br.b(); // is_xdic_missing
    br.bl(); // class_version
    br.rd();
    br.rd(); // image size
    final path = _text(br);
    br.b(); // is_loaded
    br.rc(); // resunits
    br.rd();
    br.rd(); // pixel size
    if (br.ok && path.isNotEmpty) _imageDefs[handle] = path;
  }

  /// EED entries: BS byte size, handle, then that many bytes. A zero size ends
  /// the list.
  void _skipEed(DwgBitReader br) {
    while (true) {
      final size = br.bs();
      if (!br.ok) return;
      if (size == 0) return;
      br.h();
      br.skip(size * 8);
      if (!br.ok) return;
    }
  }

  /// Common entity data for R2000.
  ({List<double> values, String text}) _readTextLike(DwgBitReader br) {
    if (_version < 2000) {
      // R13/R14 TEXT: every field is stored plainly, before the dataflags
      // word that compresses the R2000 form.
      br.bd(); // elevation
      // The insertion and alignment points are stored as raw doubles; only
      // the extrusion and the text metrics use the BD code.
      final x = br.rd();
      final y = br.rd();
      final ax = br.rd();
      final ay = br.rd();
      br.bd();
      br.bd();
      br.bd(); // extrusion
      br.bd(); // thickness
      final oblique = br.bd();
      final rotation = br.bd();
      final height = br.bd();
      final width = br.bd();
      final text = _text(br);
      final generation = br.bs();
      final hAlign = br.bs();
      final vAlign = br.bs();
      return (
        values: [
          x,
          y,
          height,
          rotation,
          width,
          oblique,
          hAlign.toDouble(),
          vAlign.toDouble(),
          generation.toDouble(),
          ax,
          ay,
        ],
        text: text,
      );
    }
    final dataflags = br.rc();
    if ((dataflags & 0x01) == 0) br.rd(); // elevation
    final x = br.rd();
    final y = br.rd();
    var ax = x;
    var ay = y;
    if ((dataflags & 0x02) == 0) {
      ax = br.dd(x); // alignment point
      ay = br.dd(y);
    }
    _be(br);
    _bt(br);
    final oblique = (dataflags & 0x04) == 0 ? br.rd() : 0.0;
    final rotation = (dataflags & 0x08) == 0 ? br.rd() : 0.0;
    final height = br.rd();
    final width = (dataflags & 0x10) == 0 ? br.rd() : 1.0;
    final text = _text(br);
    final generation = (dataflags & 0x20) == 0 ? br.bs() : 0;
    final hAlign = (dataflags & 0x40) == 0 ? br.bs() : 0;
    final vAlign = (dataflags & 0x80) == 0 ? br.bs() : 0;
    return (
      values: [
        x,
        y,
        height,
        rotation,
        width,
        oblique,
        hAlign.toDouble(),
        vAlign.toDouble(),
        generation.toDouble(),
        ax,
        ay,
      ],
      text: text,
    );
  }

  static bool _isDimensionType(int type) =>
      type >= _typeDimOrdinate && type <= _typeDimDiameter;

  ({
    double tx,
    double ty,
    double meas,
    double cx,
    double cy,
    double sx,
    double sy,
    double sz,
    double rot,
  })
  _readDimensionCommon(DwgBitReader br) {
    if (_version >= 2010) br.rc(); // class version
    br.bd();
    br.bd();
    br.bd(); // extrusion
    final tx = br.rd();
    final ty = br.rd();
    br.bd(); // elevation
    br.rc(); // flag1
    _lastText = _text(br);
    br.bd(); // text_rotation
    br.bd(); // horiz_dir
    final sx = br.bd();
    final sy = br.bd();
    final sz = br.bd(); // ins_scale
    final rotation = br.bd();
    var measurement = 0.0;
    if (_version >= 2000) {
      // Attachment, line spacing and the cached measurement arrived with
      // R2000; R13/R14 jump straight to the clone insertion point.
      br.bs(); // attachment
      br.bs(); // lspace_style
      br.bd(); // lspace_factor
      measurement = br.bd();
      if (_version >= 2007) {
        br.b(); // unknown
        br.b(); // flip arrow 1
        br.b(); // flip arrow 2
      }
    }
    final cx = br.rd();
    final cy = br.rd(); // clone_ins_pt
    return (
      tx: tx,
      ty: ty,
      meas: measurement,
      cx: cx,
      cy: cy,
      sx: sx,
      sy: sy,
      sz: sz,
      rot: rotation,
    );
  }

  static int _indexOfBytes(Uint8List data, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= data.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static bool _hasSentinel(Uint8List data, int at, List<int> sentinel) {
    if (at + sentinel.length > data.length) return false;
    for (var i = 0; i < sentinel.length; i++) {
      if (data[at + i] != sentinel[i]) return false;
    }
    return true;
  }

  static const _classSentinel = [
    0x8D,
    0xA1,
    0xC4,
    0xB8,
    0xC4,
    0xA9,
    0xF8,
    0xC5,
    0xC0,
    0xDC,
    0xF4,
    0x5F,
    0xE7,
    0xCF,
    0xB6,
    0x8A,
  ];

  static int _u32le(Uint8List data, int at) =>
      data[at] |
      (data[at + 1] << 8) |
      (data[at + 2] << 16) |
      (data[at + 3] << 24);

  static int _u16be(Uint8List data, int at) => (data[at] << 8) | data[at + 1];
}

final class _Section {
  const _Section({
    required this.number,
    required this.address,
    required this.size,
  });

  final int number;
  final int address;
  final int size;
}

/// The object map pointed at a gap (free space) rather than an object.
final class _InvalidObject implements Exception {
  const _InvalidObject();
}
