part of '../dwg_reader.dart';

extension on DwgReader {
  DwgLayer? _readLayer(
    DwgBitReader br,
    int handle,
    int objectStartBit,
    int bitsize,
    int? limit,
  ) {
    final reactors = br.bl();
    final xdicMissing = _version >= 2004 ? br.b() != 0 : false;
    if (_version >= 2013) br.b(); // has_ds_data
    final name = _text(br);
    if (_version >= 2007) {
      br.bs(); // is_xref_resolved
    } else {
      br.b(); // is_xref_ref
      br.bs(); // is_xref_resolved
      br.b(); // is_xref_dep
    }
    final int flags;
    var color = 0;
    int? trueColor;
    if (_version < 2000) {
      // R13/R14 store the state as four bits instead of the R2000 flag word,
      // and have neither a plot flag nor a line weight.
      final frozen = br.b() != 0;
      var off = br.b() != 0;
      final frozenInNew = br.b() != 0;
      final locked = br.b() != 0;
      color = br.bs(); // CMC
      // A negative colour is the pre-R2000 way of switching a layer off. It
      // can appear with or without the off bit, so both must be honoured.
      if (color < 0) {
        off = true;
        color = -color;
      }
      flags =
          (frozen ? 1 : 0) |
          (off ? 2 : 0) |
          (frozenInNew ? 4 : 0) |
          (locked ? 8 : 0) |
          // No line-weight field exists before R2000; ByDefault is the only
          // honest value, not a 0.00 mm hairline.
          (31 << 5) |
          16;
    } else {
      flags = br.bs();
      color = br.bs();
    }
    if (_version >= 2004) {
      // R2004+ stores a full CMC: ACI index, true colour and name flags.
      final rgb = br.bl();
      final cflag = br.rc();
      if (cflag < 4) {
        if ((cflag & 1) != 0) _text(br); // colour name
        if ((cflag & 2) != 0) _text(br); // colour book
      }
      final method = (rgb >> 24) & 0xff;
      // The BS index is authoritative when it names a real ACI colour; only
      // then does the CMC method overrule it. Overwriting it with the low
      // byte of the RGB repainted a true-colour layer 176 as 104.
      final usableIndex = color > 0 && color < 256;
      if (method == 0xc3) {
        if (!usableIndex) {
          // The low byte is the intended ACI, but the palette search first
          // keeps duplicate palette entries consistent with the reference decoder.
          final exact = aciIndexForRgb(rgb);
          color = exact == 256 ? rgb & 0xff : exact;
        }
      } else if (method == 0xc2) {
        trueColor = rgb & 0xffffff;
        // No ACI is stored; use the palette when the RGB is exactly one of
        // its colours, as the reference decoder does.
        if (!usableIndex) color = aciIndexForRgb(rgb);
      } else if (method == 0xc1) {
        color = 0;
      } else if (method == 0xc0) {
        color = 256;
      }
    }
    if (!br.ok || name.isEmpty) return null;

    // Handle stream: owner, reactors, xdic, xref, plotstyle, material, ltype.
    var ltypeHandle = 0;
    final handleAt = objectStartBit + bitsize;
    if (bitsize > 0 && handleAt < (limit ?? _data.length * 8)) {
      final h = DwgBitReader(_data)
        ..bitPos = handleAt
        ..limitBits = limit;
      h.h(); // owner
      for (var i = 0; i < reactors && i < 10000; i++) {
        h.h();
      }
      if (_version >= 2004) {
        if (!xdicMissing) h.h(); // xdic
      } else {
        h.h(); // xdic
      }
      h.h(); // xref
      if (_version >= 2000) h.h(); // plotstyle
      if (_version >= 2007) h.h(); // material
      ltypeHandle = _handleOf(h, handle);
    }

    return DwgLayer(
      handle: handle,
      name: name,
      colorIndex: color,
      trueColor: trueColor,
      flags: flags,
      ltypeHandle: ltypeHandle,
    );
  }

  DwgBlock? _readBlockHeader(DwgBitReader br, int handle) {
    br.bl(); // num_reactors
    if (_version >= 2004) br.b(); // is_xdic_missing
    if (_version >= 2013) br.b(); // has_ds_data
    final name = _text(br);
    if (_version >= 2007) {
      br.bs(); // is_xref_resolved
    } else {
      br.b(); // is_xref_ref
      br.bs(); // is_xref_resolved
      br.b(); // is_xref_dep
    }
    br.b(); // anonymous
    br.b(); // hasattrs
    final blkisxref = br.b();
    final xrefoverlaid = br.b();
    if (_version >= 2000) {
      br.b(); // xref_loaded
      if (_version >= 2004 && blkisxref == 0 && xrefoverlaid == 0) {
        br.bl(); // num_owned; the handles are in the handle stream
      }
    }
    final x = br.bd();
    final y = br.bd();
    br.bd(); // z
    _text(br); // xref_pname
    if (_version >= 2000) {
      // num_inserts, description and the preview bitmap arrived with R2000.
      while (br.rc() != 0) {
        if (!br.ok) break;
      }
      _text(br); // description
      final previewSize = br.bl();
      if (previewSize > br.bytes.length) return null;
      br.skip(previewSize * 8);
    }
    if (!br.ok || name.isEmpty) return null;
    return DwgBlock(handle: handle, name: name, baseX: x, baseY: y);
  }

  /// The name a class object is known by.
  ///
  /// DWG stores TABLE as `ACAD_TABLE`, while AutoCAD, DXF and the reference decoder call
  /// the object `TABLE`. The `ACAD_` prefix only appears on a few classes.
  static String _className(String dxf) {
    var name = dxf;
    if (name.startsWith('ACAD_')) {
      name = name.substring(5);
    } else if (name.startsWith('ACDB')) {
      // ObjectDBX class records often carry an ACDB prefix that the reference decoder and
      // DXF do not use in the object name (ACDBASSOCNETWORK => ASSOCNETWORK).
      name = name.substring(4);
    }
    // Some context-data records are written as _FOO_CLASS; the reference decoder and DXF
    // call them FOO. ACSH_*_CLASS names are real and keep their suffix.
    if (name.startsWith('_')) {
      name = name.substring(1);
      for (final suffix in ['_CLASS', '_VERSION', '_DATA']) {
        if (name.endsWith(suffix)) {
          name = name.substring(0, name.length - suffix.length);
        }
      }
    }
    return name;
  }

  void _readClassesR2000(Uint8List data, _Section section) {
    var at = section.address;
    final end = section.address + section.size;
    if (at + 16 <= end &&
        DwgReader._hasSentinel(data, at, DwgReader._classSentinel)) {
      at += 16;
    }
    if (at + 4 > end) return;
    final size = DwgReader._u32le(data, at);
    at += 4;
    final limit = (at + size).clamp(0, end).toInt();
    final br = DwgBitReader(data)
      ..bitPos = at * 8
      ..limitBits = limit * 8;
    while (br.ok && br.bitPos < limit * 8) {
      final number = br.bs();
      br.bs();
      _text(br);
      _text(br);
      final dxf = _text(br);
      br.b();
      final itemClassId = br.bs();
      if (!br.ok) break;
      if (number >= 500) {
        _classNames[number] = _className(dxf);
        _classIsEntity[number] = itemClassId == 498;
      }
      at = br.bitPos >> 3;
      if (at >= limit) break;
    }
  }

  void _readClassesR2007(Uint8List data) {
    final sentinel = DwgReader._indexOfBytes(data, DwgReader._classSentinel);
    if (sentinel < 0) return;
    final br = DwgBitReader(data)..bitPos = (sentinel + 16) * 8;
    br.rl(); // size
    if (_version >= 2010) br.rl(); // header size
    final bitsize = br.rl();
    final maxNum = br.bs();
    br.rc();
    br.rc();
    br.b();
    if (maxNum < 500 || maxNum > 5000) return;

    var start = bitsize + (_version >= 2010 ? 191 : 159);
    final flag = DwgBitReader(data)
      ..bitPos = start
      ..limitBits = data.length * 8;
    if (flag.b() == 0) return;
    start -= 16;
    final sizeReader = DwgBitReader(data)
      ..bitPos = start
      ..limitBits = data.length * 8;
    var stringSize = sizeReader.rs();
    if ((stringSize & 0x8000) != 0) {
      start -= 16;
      final hiReader = DwgBitReader(data)
        ..bitPos = start
        ..limitBits = data.length * 8;
      final hi = hiReader.rs();
      stringSize = (stringSize & 0x7fff) | (hi << 15);
    }
    start -= stringSize;
    if (start < 0 || stringSize <= 0) return;
    final str = DwgBitReader(data)
      ..bitPos = start
      ..limitBits = start + stringSize;

    String tu() {
      final length = str.bs();
      if (!str.ok || length < 0 || length > 100000) return '';
      final units = <int>[];
      for (var i = 0; i < length; i++) {
        units.add(str.rs());
      }
      return String.fromCharCodes(units);
    }

    final count = maxNum - 499;
    for (var i = 0; i < count && br.ok && str.ok; i++) {
      final number = br.bs();
      br.bs(); // proxy flag
      tu(); // application name
      tu(); // C++ class name
      final dxf = tu();
      br.b(); // was proxy
      final itemClassId = br.bs();
      br.bl(); // instance count
      br.bs(); // dwg version
      br.bs(); // maintenance version
      br.bl();
      br.bl();
      if (number >= 500 && dxf.isNotEmpty) {
        _classNames[number] = _className(dxf);
        _classIsEntity[number] = itemClassId == 498;
      }
    }
  }

  void _readClassesR2004(Uint8List data) {
    final start = DwgReader._indexOfBytes(data, DwgReader._classSentinel);
    if (start < 0) return;
    final br = DwgBitReader(data)..bitPos = (start + 16) * 8;
    br.rl(); // size
    final maxNum = br.bs();
    br.rc();
    br.rc();
    br.b();
    final count = maxNum - 499;
    for (var i = 0; i < count && br.ok; i++) {
      final number = br.bs();
      br.bs();
      _text(br);
      _text(br);
      final dxf = _text(br);
      br.b();
      final itemClassId = br.bs();
      br.bl(); // num_instances
      br.bs(); // dwg version
      br.bs(); // maint version
      br.bl();
      br.bl();
      if (number >= 500) {
        _classNames[number] = _className(dxf);
        _classIsEntity[number] = itemClassId == 498;
      }
    }
  }
}

extension on DwgReader {
  /// Object common data and the shared table name/xref prefix.
  ({String name, int ref, int dep, int reactors, bool xdicMissing})
  _readTableHead(DwgBitReader br) {
    final reactors = br.bl();
    final xdicMissing = _version >= 2004 ? br.b() != 0 : false;
    if (_version >= 2013) br.b(); // has_ds_data
    final name = _text(br);
    var ref = 1;
    var dep = 0;
    if (_version >= 2007) {
      final resolved = br.bs();
      dep = resolved == 256 ? 1 : 0;
    } else {
      ref = br.b();
      br.bs(); // is_xref_resolved
      dep = br.b();
    }
    return (
      name: name,
      ref: ref,
      dep: dep,
      reactors: reactors,
      xdicMissing: xdicMissing,
    );
  }

  /// R2000+ table record flags: xref dep=16, xref ref=64, plus type bits.
  static int _tableFlags(int ref, int dep, {int extra = 0}) =>
      extra | (dep << 4) | (ref << 6);

  DwgStyle? _readStyle(DwgBitReader br, int handle) {
    final head = _readTableHead(br);
    final isShape = br.b();
    final isVertical = br.b();
    final textSize = br.bd();
    final widthFactor = br.bd();
    final oblique = br.bd();
    final generation = br.rc();
    final lastHeight = br.bd();
    final fontFile = _text(br);
    final bigFontFile = _text(br);
    if (!br.ok) return null;
    return DwgStyle(
      handle: handle,
      name: head.name,
      flags: _tableFlags(
        head.ref,
        head.dep,
        extra: (isShape != 0 ? 1 : 0) | (isVertical != 0 ? 4 : 0),
      ),
      textSize: textSize,
      widthFactor: widthFactor,
      obliqueAngle: oblique,
      generation: generation,
      lastHeight: lastHeight,
      fontFile: fontFile,
      bigFontFile: bigFontFile,
    );
  }

  DwgLinetype? _readLinetype(DwgBitReader br, int handle) {
    final head = _readTableHead(br);
    final description = _text(br);
    final patternLength = br.bd();
    final alignment = br.rc();
    final numDashes = br.rc();
    final dashes = <double>[];
    for (var i = 0; i < numDashes && i < 1000; i++) {
      dashes.add(br.bd());
      br.bs(); // complex_shapecode
      br.rd(); // x offset
      br.rd(); // y offset
      br.bd(); // scale
      br.bd(); // rotation
      br.bs(); // shape flag
    }
    if (!br.ok) return null;
    return DwgLinetype(
      handle: handle,
      name: head.name,
      flags: _tableFlags(head.ref, head.dep),
      description: description,
      patternLength: patternLength,
      alignment: alignment,
      dashes: dashes,
    );
  }

  DwgAppId? _readAppId(DwgBitReader br, int handle) {
    final head = _readTableHead(br);
    final unknown = br.rc();
    if (!br.ok) return null;
    return DwgAppId(
      handle: handle,
      name: head.name,
      flags: _tableFlags(head.ref, head.dep),
      unknown: unknown,
    );
  }

  DwgUcs? _readUcs(DwgBitReader br, int handle) {
    final head = _readTableHead(br);
    final origin = [br.bd(), br.bd(), br.bd()];
    final xAxis = [br.bd(), br.bd(), br.bd()];
    final yAxis = [br.bd(), br.bd(), br.bd()];
    if (!br.ok) return null;
    return DwgUcs(
      handle: handle,
      name: head.name,
      flags: _tableFlags(head.ref, head.dep),
      origin: origin,
      xAxis: xAxis,
      yAxis: yAxis,
    );
  }

  DwgVPort? _readVPort(DwgBitReader br, int handle) {
    final head = _readTableHead(br);
    final viewHeight = br.bd();
    final viewWidth = br.bd();
    final centerX = br.rd();
    final centerY = br.rd();
    final target = [br.bd(), br.bd(), br.bd()];
    final direction = [br.bd(), br.bd(), br.bd()];
    final twist = br.bd();
    final lensLength = br.bd();
    final frontZ = br.bd();
    final backZ = br.bd();
    final viewMode = br.b4();
    if (_version >= 2000) br.rc(); // render mode
    if (_version >= 2007) {
      br.b(); // use default lights
      br.rc(); // default lighting type
      br.bd(); // brightness
      br.bd(); // contrast
      br.bs(); // ambient colour index
      br.bl(); // ambient true colour
      final flags = br.rc();
      if (flags < 4) {
        if ((flags & 1) != 0) _text(br); // colour name
        if ((flags & 2) != 0) _text(br); // colour book
      }
    }
    final lowerLeft = [br.rd(), br.rd()];
    final upperRight = [br.rd(), br.rd()];
    br.b(); // UCSFOLLOW
    br.bs(); // circle zoom
    br.b(); // fast zoom
    br.bb(); // UCSICON
    br.b(); // grid mode
    final gridUnit = [br.rd(), br.rd()];
    br.b(); // snap mode
    br.b(); // snap style
    br.bs(); // snap isopair
    var snapAngle = 0.0;
    final snapBase = [0.0, 0.0];
    // AC1020 (R2006) omits these two; every other version written by our
    // supported readers has them. The header's dwg_version byte, not the
    // file magic, is what identifies that writer.
    if (_dwgVersion != 0x1a) {
      snapAngle = br.bd();
      snapBase[0] = br.rd();
      snapBase[1] = br.rd();
    }
    final snapUnit = [br.rd(), br.rd()];
    if (!br.ok) return null;
    return DwgVPort(
      handle: handle,
      name: head.name,
      flags: _tableFlags(head.ref, head.dep),
      viewHeight: viewHeight,
      viewWidth: viewWidth,
      viewCenter: [centerX, centerY],
      viewTarget: target,
      viewDirection: direction,
      viewTwist: twist,
      lensLength: lensLength,
      frontZ: frontZ,
      backZ: backZ,
      lowerLeft: lowerLeft,
      upperRight: upperRight,
      snapBase: snapBase,
      snapUnit: snapUnit,
      gridUnit: gridUnit,
      snapAngle: snapAngle,
      viewMode: viewMode,
    );
  }

  DwgLayout? _readLayout(
    DwgBitReader br,
    int handle,
    int objectStartBit,
    int bitsize,
    int? limit,
  ) {
    final reactors = br.bl();
    final xdicMissing = _version >= 2004 ? br.b() != 0 : false;
    if (_version >= 2013) br.b(); // has_ds_data

    _text(br); // printer_cfg_file
    _text(br); // paper_size
    br.bs(); // plot_flags
    br.bd(); // left_margin
    br.bd(); // bottom_margin
    br.bd(); // right_margin
    br.bd(); // top_margin
    final paperWidth = br.bd();
    final paperHeight = br.bd();
    _text(br); // canonical_media_name
    br.bd(); // plot_origin.x
    br.bd(); // plot_origin.y
    br.bs(); // plot_paper_unit
    final plotRotationMode = br.bs();
    br.bs(); // plot_type
    br.bd(); // plot_window_ll.x
    br.bd(); // plot_window_ll.y
    br.bd(); // plot_window_ur.x
    br.bd(); // plot_window_ur.y
    // R2004+ stores the named view as a handle in the handle stream instead.
    if (_version < 2004) _text(br); // plotview_name
    br.bd(); // paper_units
    br.bd(); // drawing_units
    _text(br); // stylesheet
    br.bs(); // std_scale_type
    br.bd(); // std_scale_factor
    br.bd(); // paper_image_origin.x
    br.bd(); // paper_image_origin.y
    if (_version >= 2004) {
      br.bs(); // shadeplot_type
      br.bs(); // shadeplot_reslevel
      br.bs(); // shadeplot_customdpi
    }

    final name = _text(br);
    final tabOrder = br.bs();
    final flags = br.bs();
    br.bd(); // INSBASE.x
    br.bd(); // INSBASE.y
    br.bd(); // INSBASE.z
    br.rd(); // LIMMIN.x
    br.rd(); // LIMMIN.y
    br.rd(); // LIMMAX.x
    br.rd(); // LIMMAX.y
    br.bd(); // UCSORG.x
    br.bd(); // UCSORG.y
    br.bd(); // UCSORG.z
    br.bd(); // UCSXDIR.x
    br.bd(); // UCSXDIR.y
    br.bd(); // UCSXDIR.z
    br.bd(); // UCSYDIR.x
    br.bd(); // UCSYDIR.y
    br.bd(); // UCSYDIR.z
    br.bd(); // ucs_elevation
    br.bs(); // UCSORTHOVIEW
    br.bd(); // EXTMIN.x
    br.bd(); // EXTMIN.y
    br.bd(); // EXTMIN.z
    br.bd(); // EXTMAX.x
    br.bd(); // EXTMAX.y
    br.bd(); // EXTMAX.z
    final numViewports = _version >= 2004 ? br.bl() : 0;
    if (!br.ok || name.isEmpty) return null;

    // Handle stream: owner, reactors, xdic, block_header, ...
    var blockHandle = 0;
    final handleAt = objectStartBit + bitsize;
    if (bitsize > 0 && handleAt < (limit ?? _data.length * 8)) {
      final h = DwgBitReader(_data)
        ..bitPos = handleAt
        ..limitBits = limit;
      h.h(); // owner
      for (var i = 0; i < reactors && i < 10000; i++) {
        h.h();
      }
      if (_version >= 2004) {
        if (!xdicMissing) h.h(); // xdic
      } else {
        h.h(); // xdic
      }
      if (_version >= 2004) h.h(); // plotview
      if (_version >= 2007) h.h(); // shadeplot
      blockHandle = _handleOf(h, handle);
    }

    return DwgLayout(
      handle: handle,
      name: name,
      blockHandle: blockHandle,
      tabOrder: tabOrder,
      flags: flags,
      paperWidth: paperWidth,
      paperHeight: paperHeight,
      plotRotationMode: plotRotationMode,
      numViewports: numViewports,
    );
  }

  DwgDimStyle? _readDimStyle(
    DwgBitReader br,
    int handle,
    int objectStartBit,
    int bitsize,
    int? limit,
  ) {
    final head = _readTableHead(br);
    if (!br.ok) return null;
    final values = <String, Object?>{};

    // The object handle stream always starts at the bitsize, and begins with
    // the owner, reactors and xdic handles before the dimension style's own.
    DwgBitReader? handleStream;
    final handleAt = objectStartBit + bitsize;
    if (bitsize > 0 && handleAt < (limit ?? _data.length * 8)) {
      final reader = DwgBitReader(_data)
        ..bitPos = handleAt
        ..limitBits = limit;
      reader.h(); // owner
      for (var i = 0; i < head.reactors && i < 10000; i++) {
        reader.h();
      }
      if (_version >= 2004) {
        if (!head.xdicMissing) reader.h();
      } else {
        reader.h();
      }
      reader.h(); // xref handle from COMMON_TABLE_FLAGS
      handleStream = reader;
    }

    int b(String key) {
      final value = br.b();
      values[key] = value;
      return value;
    }

    int bs(String key) {
      final value = br.bs();
      values[key] = value;
      return value;
    }

    int bsd(String key) {
      final raw = br.bs();
      final value = raw >= 0x8000 ? raw - 0x10000 : raw;
      values[key] = value;
      return value;
    }

    int rc(String key) {
      final value = br.rc();
      values[key] = value;
      return value;
    }

    double bd(String key) {
      final value = br.bd();
      values[key] = value;
      return value;
    }

    void text(String key) => values[key] = _text(br);

    void cmc(String key) {
      final index = br.bs();
      if (_version < 2004) {
        values[key] = index;
        return;
      }
      final rgb = br.bl() & 0xffffffff;
      final flag = br.rc();
      final aci = index > 0 && index < 256 ? index : aciIndexForRgb(rgb);
      values[key] = <String, Object?>{
        'index': aci,
        'rgb': rgb.toRadixString(16).padLeft(8, '0'),
      };
      if (flag < 4) {
        if ((flag & 1) != 0) _text(br);
        if ((flag & 2) != 0) _text(br);
      }
    }

    void h(String key) {
      final reader = handleStream;
      if (reader == null) return;
      final value = reader.h();
      values[key] = [reader.hCode, value];
    }

    if (_version <= 14) {
      // R13/R14 store the dimension fields directly, without the common
      // R2000 block or the text style handle in the data stream.
      b('DIMTOL');
      b('DIMLIM');
      b('DIMTIH');
      b('DIMTOH');
      b('DIMSE1');
      b('DIMSE2');
      b('DIMALT');
      b('DIMTOFL');
      b('DIMSAH');
      b('DIMTIX');
      b('DIMSOXD');
      rc('DIMALTD');
      rc('DIMZIN');
      b('DIMSD1');
      b('DIMSD2');
      rc('DIMTOLJ');
      rc('DIMJUST');
      rc('DIMFIT');
      b('DIMUPT');
      rc('DIMTZIN');
      rc('DIMALTZ');
      rc('DIMALTTZ');
      rc('DIMTAD');
      bs('DIMUNIT');
      bs('DIMAUNIT');
      bs('DIMDEC');
      bs('DIMTDEC');
      bs('DIMALTU');
      bs('DIMALTTD');
      bd('DIMSCALE');
      bd('DIMASZ');
      bd('DIMEXO');
      bd('DIMDLI');
      bd('DIMEXE');
      bd('DIMRND');
      bd('DIMDLE');
      bd('DIMTP');
      bd('DIMTM');
      bd('DIMTXT');
      bd('DIMCEN');
      bd('DIMTSZ');
      bd('DIMALTF');
      bd('DIMLFAC');
      bd('DIMTVP');
      bd('DIMTFAC');
      bd('DIMGAP');
      text('DIMPOST');
      text('DIMAPOST');
      text('DIMBLK_T');
      text('DIMBLK1_T');
      text('DIMBLK2_T');
      cmc('DIMCLRD');
      cmc('DIMCLRE');
      cmc('DIMCLRT');
    } else {
      text('DIMPOST');
      text('DIMAPOST');
      bd('DIMSCALE');
      bd('DIMASZ');
      bd('DIMEXO');
      bd('DIMDLI');
      bd('DIMEXE');
      bd('DIMRND');
      bd('DIMDLE');
      bd('DIMTP');
      bd('DIMTM');
      if (_version >= 2007) {
        bd('DIMFXL');
        bd('DIMJOGANG');
        bs('DIMTFILL');
        cmc('DIMTFILLCLR');
      }
      b('DIMTOL');
      b('DIMLIM');
      b('DIMTIH');
      b('DIMTOH');
      b('DIMSE1');
      b('DIMSE2');
      bs('DIMTAD');
      bs('DIMZIN');
      bs('DIMAZIN');
      if (_version >= 2007) bs('DIMARCSYM');
      bd('DIMTXT');
      bd('DIMCEN');
      bd('DIMTSZ');
      bd('DIMALTF');
      bd('DIMLFAC');
      bd('DIMTVP');
      bd('DIMTFAC');
      bd('DIMGAP');
      bd('DIMALTRND');
      b('DIMALT');
      bs('DIMALTD');
      b('DIMTOFL');
      b('DIMSAH');
      b('DIMTIX');
      b('DIMSOXD');
      cmc('DIMCLRD');
      cmc('DIMCLRE');
      cmc('DIMCLRT');
      bs('DIMADEC');
      bs('DIMDEC');
      bs('DIMTDEC');
      bs('DIMALTU');
      bs('DIMALTTD');
      bs('DIMAUNIT');
      bs('DIMFRAC');
      bs('DIMLUNIT');
      bs('DIMDSEP');
      bs('DIMTMOVE');
      bs('DIMJUST');
      b('DIMSD1');
      b('DIMSD2');
      bs('DIMTOLJ');
      bs('DIMTZIN');
      bs('DIMALTZ');
      bs('DIMALTTZ');
      b('DIMUPT');
      bs('DIMATFIT');
      h('DIMTXSTY');
      if (_version >= 2007) b('DIMFXLON');
      if (_version >= 2010) {
        b('DIMTXTDIRECTION');
        bd('DIMALTMZF');
        text('DIMALTMZS');
        bd('DIMMZF');
        text('DIMMZS');
      }
      bsd('DIMLWD');
      bsd('DIMLWE');
    }

    b('flag0');
    if (_version <= 14) h('DIMTXSTY');
    if (_version >= 2000) {
      h('DIMLDRBLK');
      h('DIMBLK');
      h('DIMBLK1');
      h('DIMBLK2');
    }
    if (_version >= 2007) {
      h('DIMLTYPE');
      h('DIMLTEX1');
      h('DIMLTEX2');
    }

    return DwgDimStyle(
      handle: handle,
      name: head.name,
      flags: _tableFlags(head.ref, head.dep),
      values: values,
    );
  }
}
