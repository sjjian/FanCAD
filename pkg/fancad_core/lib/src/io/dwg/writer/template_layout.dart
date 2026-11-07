import 'dart:typed_data';

import '../bit_reader.dart';
import 'r2000_writer.dart';

/// Read-only view of the R2000 template's container, object map and block
/// headers. This is the staging data the writer needs before it can append
/// entities: section addresses, object handles/offsets and the model-space
/// block header's first/last entity handles.
final class R2000TemplateLayout {
  const R2000TemplateLayout({
    required this.sections,
    required this.objects,
    required this.blockNames,
    required this.layers,
    required this.modelSpaceRef,
    required this.paperSpaceRef,
    required this.firstEntity,
    required this.lastEntity,
    required this.layerOwner,
    required this.layerPlotStyle,
    required this.layerLineType,
    required this.blockControl,
    required this.paperSpace,
    required this.standardTextStyle,
    required this.lineTypes,
    required this.lineTypeControl,
    required this.textStyles,
    required this.styleControl,
    required this.dimStyles,
    required this.dimStyleControl,
    required this.standardDimStyle,
    required this.dimStyleMoreHandles,
  });

  final List<R2000SectionRef> sections;
  final List<R2000ObjectRef> objects;
  final Map<int, String> blockNames;
  final Map<String, int> layers;
  final R2000ObjectRef? modelSpaceRef;
  final R2000ObjectRef? paperSpaceRef;
  int get modelSpaceHandle => modelSpaceRef?.handle ?? 0;
  final int firstEntity;
  final int lastEntity;

  /// Handles shared by table records: the LAYER_CONTROL that owns layers,
  /// the default plot style and the Continuous line type.
  final int layerOwner;
  final int layerPlotStyle;
  final int layerLineType;

  /// BLOCK_CONTROL handle and the paper-space BLOCK_HEADER handle.
  final int blockControl;
  final int paperSpace;

  /// Handle of the STYLE record named `Standard`, used by text entities.
  final int standardTextStyle;

  /// LTYPE table records by upper-case name, and the LTYPE_CONTROL handle.
  final Map<String, int> lineTypes;
  final int lineTypeControl;

  /// STYLE table records by upper-case name, and the STYLE_CONTROL handle.
  final Map<String, int> textStyles;
  final int styleControl;

  /// DIMSTYLE table records by upper-case name, the DIMSTYLE_CONTROL handle
  /// and the Standard DIMSTYLE handle.
  final Map<String, int> dimStyles;
  final int dimStyleControl;
  final int standardDimStyle;

  /// Extra hard handles stored on DIMSTYLE_CONTROL (R2000+).
  final List<int> dimStyleMoreHandles;

  static R2000TemplateLayout read([Uint8List? data]) {
    final bytes = data ?? const R2000Writer().writeEmptyTemplate();
    final count = _u32(bytes, 0x15);
    final sections = <R2000SectionRef>[];
    for (var i = 0; i < count; i++) {
      final at = 0x19 + i * 9;
      sections.add(
        R2000SectionRef(
          number: bytes[at],
          address: _u32(bytes, at + 1),
          size: _u32(bytes, at + 5),
        ),
      );
    }
    final handles = sections.firstWhere((section) => section.number == 2);
    final objects = <R2000ObjectRef>[];
    final blockNames = <int, String>{};
    final layers = <String, int>{};
    R2000ObjectRef? modelSpaceRef;
    var first = 0;
    var last = 0;

    var pos = handles.address;
    final end = handles.address + handles.size;
    var lastOffset = 0;
    var lastHandle = 0;
    while (pos + 2 <= end) {
      final page = pos;
      final pageSize = (bytes[pos] << 8) | bytes[pos + 1];
      pos += 2;
      final pageEnd = page + pageSize;
      if (pageSize < 2 || pageEnd > end) break;
      while (pos < pageEnd) {
        final br = DwgBitReader(bytes)..bitPos = pos * 8;
        final handleOff = br.umc();
        final offset = br.mc();
        pos = br.bitPos >> 3;
        lastHandle += handleOff;
        lastOffset += offset;
        final object = _object(bytes, lastHandle, lastOffset);
        if (object != null) objects.add(object);
        if (object != null && object.type == 0x33) {
          final name = _layerName(bytes, object.offset);
          if (name != null) layers[name] = object.handle;
        }
        if (object != null && object.type == 0x31) {
          final name = object.blockName;
          if (name != null) blockNames[object.handle] = name;
          if (name != null && name.toUpperCase() == '*MODEL_SPACE') {
            modelSpaceRef = object;
            first = object.firstEntity;
            last = object.lastEntity;
          }
        }
      }
      pos = pageEnd + 2;
    }
    var blockControl = 0;
    for (final object in objects) {
      if (object.type == 0x30) {
        blockControl = object.handle;
        break;
      }
    }
    var paperSpace = 0;
    R2000ObjectRef? paperSpaceRef;
    for (final object in objects) {
      if (object.type != 0x31) continue;
      if (object.blockName?.toUpperCase() == '*PAPER_SPACE') {
        paperSpace = object.handle;
        paperSpaceRef = object;
      }
    }
    final textStyles = <String, int>{};
    var styleControl = 0;
    var standardTextStyle = 0;
    for (final object in objects) {
      if (object.type == 0x34) {
        styleControl = object.handle;
      } else if (object.type == 0x35) {
        final name = _tableName(bytes, object.offset, 0x35);
        if (name == null) continue;
        final upper = name.toUpperCase();
        textStyles[upper] = object.handle;
        if (upper == 'STANDARD') standardTextStyle = object.handle;
      }
    }
    final lineTypes = <String, int>{};
    var lineTypeControl = 0;
    for (final object in objects) {
      if (object.type == 0x38) {
        lineTypeControl = object.handle;
      } else if (object.type == 0x39) {
        final name = _tableName(bytes, object.offset, 0x39);
        if (name != null) lineTypes[name.toUpperCase()] = object.handle;
      }
    }
    final dimStyles = <String, int>{};
    var dimStyleControl = 0;
    var standardDimStyle = 0;
    var dimStyleMoreHandles = <int>[];
    for (final object in objects) {
      if (object.type == 0x44) {
        dimStyleControl = object.handle;
        final refs = _dimStyleControlRefs(bytes, object.offset);
        if (refs != null) dimStyleMoreHandles = refs;
      } else if (object.type == 0x45) {
        final name = _tableName(bytes, object.offset, 0x45);
        if (name == null) continue;
        final upper = name.toUpperCase();
        dimStyles[upper] = object.handle;
        if (upper == 'STANDARD') standardDimStyle = object.handle;
      }
    }
    var layerOwner = 0;
    var layerPlotStyle = 0;
    var layerLineType = 0;
    final layerZero = layers['0'];
    if (layerZero != null) {
      for (final object in objects) {
        if (object.handle != layerZero) continue;
        final refs = _layerRefs(bytes, object.offset);
        if (refs != null) {
          layerOwner = refs.owner;
          layerPlotStyle = refs.plotStyle;
          layerLineType = refs.lineType;
        }
        break;
      }
    }
    return R2000TemplateLayout(
      sections: sections,
      objects: objects,
      blockNames: blockNames,
      layers: layers,
      modelSpaceRef: modelSpaceRef,
      paperSpaceRef: paperSpaceRef,
      firstEntity: first,
      lastEntity: last,
      layerOwner: layerOwner,
      layerPlotStyle: layerPlotStyle,
      layerLineType: layerLineType,
      blockControl: blockControl,
      paperSpace: paperSpace,
      standardTextStyle: standardTextStyle,
      lineTypes: lineTypes,
      lineTypeControl: lineTypeControl,
      textStyles: textStyles,
      styleControl: styleControl,
      dimStyles: dimStyles,
      dimStyleControl: dimStyleControl,
      standardDimStyle: standardDimStyle,
      dimStyleMoreHandles: dimStyleMoreHandles,
    );
  }

  static List<int>? _dimStyleControlRefs(Uint8List data, int offset) {
    final br = DwgBitReader(data)..bitPos = offset * 8;
    final size = br.ms();
    if (!br.ok || size == 0) return null;
    final objectStart = br.bitPos;
    br.limitBits = objectStart + size * 8;
    br.bs(); // type
    final bitsize = br.rl();
    br.h(); // handle
    br.bs(); // EED
    br.bl(); // reactors
    final numEntries = br.bs();
    final more = br.rc();
    final h = DwgBitReader(data)
      ..bitPos = objectStart + bitsize
      ..limitBits = objectStart + size * 8;
    h.h(); // owner
    h.h(); // xdic
    for (var i = 0; i < numEntries; i++) {
      h.h();
    }
    final result = <int>[];
    for (var i = 0; i < more; i++) {
      result.add(h.h());
    }
    return result;
  }

  static ({int owner, int plotStyle, int lineType})? _layerRefs(
    Uint8List data,
    int offset,
  ) {
    final br = DwgBitReader(data)..bitPos = offset * 8;
    final size = br.ms();
    if (!br.ok || size == 0) return null;
    final objectStart = br.bitPos;
    br.limitBits = objectStart + size * 8;
    br.bs(); // type
    final bitsize = br.rl();
    final h = DwgBitReader(data)
      ..bitPos = objectStart + bitsize
      ..limitBits = objectStart + size * 8;
    final owner = h.h();
    h.h(); // xdic
    h.h(); // xref
    final plotStyle = h.h();
    final lineType = h.h();
    if (!h.ok) return null;
    return (owner: owner, plotStyle: plotStyle, lineType: lineType);
  }

  static String? _tableName(Uint8List data, int offset, int type) {
    final br = DwgBitReader(data)..bitPos = offset * 8;
    final size = br.ms();
    if (!br.ok || size == 0) return null;
    br.limitBits = br.bitPos + size * 8;
    if (br.bs() != type) return null;
    br.rl();
    br.h();
    _skipEed(br);
    br.bl(); // num_reactors
    final name = br.tv();
    return name.isEmpty ? null : name;
  }

  static String? _layerName(Uint8List data, int offset) {
    final br = DwgBitReader(data)..bitPos = offset * 8;
    final size = br.ms();
    if (!br.ok || size == 0) return null;
    br.limitBits = br.bitPos + size * 8;
    final type = br.bs();
    if (type != 0x33) return null;
    br.rl();
    br.h();
    _skipEed(br);
    br.bl(); // num_reactors
    final name = br.tv();
    return name.isEmpty ? null : name;
  }

  static void _skipEed(DwgBitReader br) {
    while (true) {
      final size = br.bs();
      if (!br.ok || size == 0) return;
      br.h();
      br.skip(size * 8);
      if (!br.ok) return;
    }
  }

  static R2000ObjectRef? _object(Uint8List data, int handle, int offset) {
    if (offset < 0 || offset >= data.length) return null;
    final br = DwgBitReader(data)..bitPos = offset * 8;
    final size = br.ms();
    if (!br.ok || size == 0 || br.bitPos + size * 8 > data.length * 8) {
      return null;
    }
    final objectStart = br.bitPos;
    br.limitBits = objectStart + size * 8;
    final type = br.bs();
    final bitsize = br.rl();
    final ownHandle = br.h();
    if (!br.ok) return null;
    if (type != 0x31) {
      return R2000ObjectRef(
        handle: ownHandle == 0 ? handle : ownHandle,
        type: type,
        offset: offset,
      );
    }

    // BLOCK_HEADER: skip EED, object common data, then read name/base and
    // the handle stream (block_entity, first_entity, last_entity, endblk).
    _skipEed(br);
    br.bl(); // num_reactors
    final name = br.tv();
    br.b(); // is_xref_ref
    br.bs(); // is_xref_resolved
    br.b(); // is_xref_dep
    br.b(); // anonymous
    br.b(); // hasattrs
    br.b(); // blkisxref
    br.b(); // xrefoverlaid
    br.b(); // xref_loaded
    if (br.bitPos < 0) return null;
    // Skip to the data end (preview etc. are not needed here).
    final handleStream = objectStart + bitsize;
    final h = DwgBitReader(data)
      ..bitPos = handleStream
      ..limitBits = objectStart + size * 8;
    // Common object handles come first: owner, xdic, then the accumulated
    // table xref handle (zero in the template). The block header's own
    // handles follow.
    h.h(); // ownerhandle
    h.h(); // xdicobjhandle
    h.h(); // xref
    h.h(); // block_entity
    final firstPos = h.bitPos;
    final first = h.h();
    final lastPos = h.bitPos;
    final last = h.h();
    h.h(); // endblk
    return R2000ObjectRef(
      handle: ownHandle == 0 ? handle : ownHandle,
      type: type,
      offset: offset,
      blockName: name,
      firstEntity: first,
      lastEntity: last,
      firstHandlePos: firstPos,
      lastHandlePos: lastPos,
    );
  }

  static int _u32(Uint8List data, int at) =>
      data[at] |
      (data[at + 1] << 8) |
      (data[at + 2] << 16) |
      (data[at + 3] << 24);
}

final class R2000SectionRef {
  const R2000SectionRef({
    required this.number,
    required this.address,
    required this.size,
  });

  final int number;
  final int address;
  final int size;
}

final class R2000ObjectRef {
  const R2000ObjectRef({
    required this.handle,
    required this.type,
    required this.offset,
    this.blockName,
    this.firstEntity = 0,
    this.lastEntity = 0,
    this.firstHandlePos = 0,
    this.lastHandlePos = 0,
  });

  final int handle;
  final int type;
  final int offset;
  final String? blockName;
  final int firstEntity;
  final int lastEntity;
  final int firstHandlePos;
  final int lastHandlePos;
}
