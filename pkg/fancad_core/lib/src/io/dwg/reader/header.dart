part of '../dwg_reader.dart';

/// One decoded header-variable field.
///
/// Values are shaped like the reference decoder's JSON `HEADER` object so the comparison
/// tool can diff them directly: numbers, strings, point lists, `[days, ms]`
/// for TIMEBLL, CMC maps and `[code, value]` for handles.
final class _HeaderCtx {
  _HeaderCtx({
    required this.data,
    required this.handles,
    required this.version,
    this.strings,
  });

  final DwgBitReader data;

  /// Handle stream. Same instance as [data] before R2007, which stores
  /// header handles inline.
  final DwgBitReader handles;

  /// R2007+ string stream, or null when the version stores strings inline.
  final DwgBitReader? strings;

  final int version;

  final Map<String, Object?> out = {};

  bool get v2000 => version >= 2000;
  bool get v2004 => version >= 2004;
  bool get v2007 => version >= 2007;
  bool get v2010 => version >= 2010;
  bool get v2013 => version >= 2013;
  bool get pre2007 => version < 2007;
  bool get r13to14 => version <= 14;
  bool get r13to2000 => version <= 2000;
  bool get r13to2004 => version <= 2004;
  bool get upTo14 => version <= 14;

  void b(String name) => out[name] = data.b();
  void bs(String name) => out[name] = data.bs();
  void rc(String name) => out[name] = data.rc();
  void bl(String name) => out[name] = data.bl();
  void bll(String name) => out[name] = data.bll();
  void bd(String name) => out[name] = data.bd();

  void bsd(String name) => out[name] = _signed16(data.bs());
  void bld(String name) => out[name] = _signed32(data.bl());

  void p3(String name) => out[name] = [data.bd(), data.bd(), data.bd()];
  void p2rd(String name) => out[name] = [data.rd(), data.rd()];

  void inlineTv(String name) => out[name] = data.tv();

  void streamTu(String name) {
    final reader = strings;
    if (reader == null) {
      out[name] = '';
      return;
    }
    out[name] = _tu(reader);
  }

  void timebll(String name) => out[name] = [data.bl(), data.bl()];

  void handle(String name) {
    final value = handles.h();
    out[name] = [handles.hCode, value];
  }

  void dataHandle(String name) {
    final value = data.h();
    out[name] = [data.hCode, value];
  }

  void cmc(String name) {
    final index = data.bs();
    if (version < 2004) {
      out[name] = index;
      return;
    }
    // CMC stores the true colour as a BL (bit long), not a raw RL.
    final rgb = data.bl() & 0xffffffff;
    final flag = data.rc();
    // The stored ACI is only authoritative inside 1..255; otherwise CMC
    // resolves the true colour against the palette, as the reference decoder does.
    final aci = index > 0 && index < 256 ? index : aciIndexForRgb(rgb);
    final value = <String, Object?>{
      'index': aci,
      'rgb': rgb.toRadixString(16).padLeft(8, '0'),
    };
    if (flag < 4) {
      if ((flag & 1) != 0) _colourString();
      if ((flag & 2) != 0) _colourString();
    }
    out[name] = value;
  }

  void _colourString() {
    if (version >= 2007 && strings != null) {
      _tu(strings!);
    } else {
      data.tv();
    }
  }
}

int _signed16(int value) => value >= 0x8000 ? value - 0x10000 : value;

int _signed32(int value) => value >= 0x80000000 ? value - 0x100000000 : value;

/// `TU`: BS length in UTF-16 code units, then the units.
String _tu(DwgBitReader reader) {
  final length = reader.bs();
  if (!reader.ok || length < 0 || length > 1000000) return '';
  final units = <int>[];
  for (var i = 0; i < length; i++) {
    units.add(reader.rs());
  }
  return String.fromCharCodes(units);
}

extension on DwgReader {
  static const _headerSentinel = <int>[
    0xCF, 0x7B, 0x1F, 0x23, 0xFD, 0xDE, 0x38, 0xA9, //
    0x5F, 0x7C, 0x68, 0xB8, 0x4E, 0x6D, 0x33, 0x5F,
  ];

  /// R13-R2000: section 0, sentinel, size RL, then the fields inline.
  void _readHeaderClassic(Uint8List data, int address, int sectionSize) {
    if (address < 0 || address + 20 > data.length) return;
    var size = DwgReader._u32le(data, address + 16);
    if (size <= 0 || size > 2048 || address + 20 + size > data.length) {
      size = sectionSize > 20 ? sectionSize - 20 : 0;
    }
    final start = (address + 20) * 8;
    final end = ((address + 20 + size) * 8).clamp(start, data.length * 8);
    final reader = DwgBitReader(data)
      ..bitPos = start
      ..limitBits = end;
    final ctx = _HeaderCtx(
      data: reader,
      handles: reader,
      version: _version,
      strings: null,
    );
    _decodeHeaderVariables(ctx);
    _headerVariables = ctx.out;
  }

  /// R2004+: decompressed `AcDb:Header` section.
  ///
  /// R2004 still stores handles and strings inline; R2007+ split the data,
  /// handle and string streams and add a bitsize that locates them.
  void _readHeaderPacked(Uint8List buffer) {
    if (buffer.isEmpty) return;
    var sentinelAt = -1;
    for (var i = 0; i + _headerSentinel.length <= buffer.length; i++) {
      var match = true;
      for (var j = 0; j < _headerSentinel.length; j++) {
        if (buffer[i + j] != _headerSentinel[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        sentinelAt = i;
        break;
      }
    }
    final sentinelStart = sentinelAt < 0 ? 0 : sentinelAt;
    final base = (sentinelStart + 16) * 8;
    if (base + 32 > buffer.length * 8) return;
    final head = DwgBitReader(buffer)..bitPos = base;
    final size = head.rl();

    if (_version < 2007) {
      final reader = DwgBitReader(buffer)..bitPos = head.bitPos;
      final end = (head.bitPos + size * 8).clamp(0, buffer.length * 8);
      reader.limitBits = end;
      final ctx = _HeaderCtx(
        data: reader,
        handles: reader,
        version: _version,
        strings: null,
      );
      _decodeHeaderVariables(ctx);
      _headerVariables = ctx.out;
      return;
    }

    // R2007+: [sentinel][size][bitsize_hi?][bitsize][variables][handles].
    // R2007 never has bitsize_hi; R2010+ adds it for maintenance versions
    // above 3 (and always for R2018).
    var hasHi = false;
    if (_version >= 2010 && (_maintVersion > 3 || _version >= 2018)) {
      head.rl();
      hasHi = true;
    }
    final bitsize = head.rl();
    final dataStart = head.bitPos;
    final handleStart = base + (hasHi ? 64 : 32) + bitsize;
    final data = DwgBitReader(buffer)
      ..bitPos = dataStart
      ..limitBits = handleStart.clamp(0, buffer.length * 8);
    final handles = DwgBitReader(buffer)
      ..bitPos = handleStart.clamp(0, buffer.length * 8)
      ..limitBits = buffer.length * 8;

    final strings = _sectionStringStream(buffer, bitsize, sentinelStart * 8);
    final ctx = _HeaderCtx(
      data: data,
      handles: handles,
      strings: strings,
      version: _version,
    );
    _decodeHeaderVariables(ctx);
    _headerVariables = ctx.out;
  }

  /// Mirrors the reference decoder's `section_string_stream` for R2007+ sections.
  DwgBitReader? _sectionStringStream(
    Uint8List buffer,
    int bitsize,
    int sentinelBits,
  ) {
    var start =
        bitsize +
        (_version < 2010 || (_version == 2010 && _maintVersion < 3)
            ? 159
            : 191) +
        sentinelBits;
    if (start < 0 || start >= buffer.length * 8) return null;
    final reader = DwgBitReader(buffer)..bitPos = start;
    final endbit = reader.b();
    if (endbit == 0) return null;
    start -= 16;
    if (start < 0 || start >= buffer.length * 8) return null;
    reader.bitPos = start;
    var dataSize = reader.rs();
    if ((dataSize & 0x8000) != 0) {
      start -= 16;
      if (start < 0 || start >= buffer.length * 8) return null;
      reader.bitPos = start;
      final hi = reader.rs();
      dataSize = (dataSize & 0x7fff) | (hi << 15);
    }
    start -= dataSize;
    if (start < 0 || start >= buffer.length * 8) return null;
    reader.bitPos = start;
    return reader;
  }

  void _decodeHeaderVariables(_HeaderCtx c) {
    final v2000 = c.v2000;
    final v2004 = c.v2004;
    final v2007 = c.v2007;
    final v2010 = c.v2010;
    final v2013 = c.v2013;
    final pre2007 = c.pre2007;
    final r13to14 = c.r13to14;
    final r13to2000 = c.r13to2000;
    final r13to2004 = c.r13to2004;
    final upTo14 = c.upTo14;

    if (v2013) c.bll('REQUIREDVERSIONS');

    c.bd('unit1_ratio');
    c.bd('unit2_ratio');
    c.bd('unit3_ratio');
    c.bd('unit4_ratio');
    if (r13to2004) {
      c.inlineTv('unit1_name');
      c.inlineTv('unit2_name');
      c.inlineTv('unit3_name');
      c.inlineTv('unit4_name');
    }

    c.bl('unknown_8');
    c.bl('unknown_9');
    if (r13to14) c.bs('unknown_10');
    if (r13to2000) c.handle('VX_TABLE_RECORD');

    c.b('DIMASO');
    c.b('DIMSHO');
    if (r13to14) c.b('DIMSAV');
    c.b('PLINEGEN');
    c.b('ORTHOMODE');
    c.b('REGENMODE');
    c.b('FILLMODE');
    c.b('QTEXTMODE');
    c.b('PSLTSCALE');
    c.b('LIMCHECK');
    if (r13to14) c.b('BLIPMODE');
    if (v2004) c.b('unknown_11');

    c.b('USRTIMER');
    c.b('SKPOLY');
    c.b('ANGDIR');
    c.b('SPLFRAME');

    if (r13to14) {
      c.b('ATTREQ');
      c.b('ATTDIA');
    }
    c.b('MIRRTEXT');
    c.b('WORLDVIEW');
    if (r13to14) c.b('WIREFRAME');
    c.b('TILEMODE');
    c.b('PLIMCHECK');
    c.b('VISRETAIN');
    if (r13to14) c.b('DELOBJ');
    c.b('DISPSILH');
    c.b('PELLIPSE');

    c.bs('PROXYGRAPHICS');
    if (upTo14) c.bs('DRAGMODE');
    c.bsd('TREEDEPTH');
    c.bs('LUNITS');
    c.bs('LUPREC');
    c.bs('AUNITS');
    c.bs('AUPREC');
    if (upTo14) c.bs('OSMODE');
    c.bs('ATTMODE');
    if (upTo14) c.bs('COORDS');
    c.bs('PDMODE');
    if (upTo14) c.bs('PICKSTYLE');
    if (v2004) {
      c.bl('unknown_12');
      c.bl('unknown_13');
      c.bl('unknown_14');
    }

    c.bsd('USERI1');
    c.bsd('USERI2');
    c.bsd('USERI3');
    c.bsd('USERI4');
    c.bsd('USERI5');
    c.bs('SPLINESEGS');
    c.bs('SURFU');
    c.bs('SURFV');
    c.bs('SURFTYPE');
    c.bs('SURFTAB1');
    c.bs('SURFTAB2');
    c.bs('SPLINETYPE');
    c.bs('SHADEDGE');
    c.bs('SHADEDIF');
    c.bs('UNITMODE');
    c.bs('MAXACTVP');
    c.bs('ISOLINES');
    c.bs('CMLJUST');
    c.bs('TEXTQLTY');

    c.bd('LTSCALE');
    c.bd('TEXTSIZE');
    c.bd('TRACEWID');
    c.bd('SKETCHINC');
    c.bd('FILLETRAD');
    c.bd('THICKNESS');
    c.bd('ANGBASE');
    c.bd('PDSIZE');
    c.bd('PLINEWID');
    c.bd('USERR1');
    c.bd('USERR2');
    c.bd('USERR3');
    c.bd('USERR4');
    c.bd('USERR5');
    c.bd('CHAMFERA');
    c.bd('CHAMFERB');
    c.bd('CHAMFERC');
    c.bd('CHAMFERD');
    c.bd('FACETRES');
    c.bd('CMLSCALE');
    c.bd('CELTSCALE');
    if (pre2007) c.inlineTv('MENU');
    c.timebll('TDUCREATE');
    c.timebll('TDUUPDATE');
    if (v2004) {
      c.bl('unknown_15');
      c.bl('unknown_16');
      c.bl('unknown_17');
    }
    c.timebll('TDINDWG');
    c.timebll('TDUSRTIMER');
    c.cmc('CECOLOR');
    c.dataHandle('HANDSEED');
    c.handle('CLAYER');
    c.handle('TEXTSTYLE');
    c.handle('CELTYPE');
    if (v2007) c.handle('CMATERIAL');
    c.handle('DIMSTYLE');
    c.handle('CMLSTYLE');

    if (v2000) c.bd('PSVPSCALE');

    c.p3('PINSBASE');
    c.p3('PEXTMIN');
    c.p3('PEXTMAX');
    c.p2rd('PLIMMIN');
    c.p2rd('PLIMMAX');
    c.bd('PELEVATION');
    c.p3('PUCSORG');
    c.p3('PUCSXDIR');
    c.p3('PUCSYDIR');
    c.handle('PUCSNAME');

    if (v2000) {
      c.handle('PUCSORTHOREF');
      c.bs('PUCSORTHOVIEW');
      c.handle('PUCSBASE');
      c.p3('PUCSORGTOP');
      c.p3('PUCSORGBOTTOM');
      c.p3('PUCSORGLEFT');
      c.p3('PUCSORGRIGHT');
      c.p3('PUCSORGFRONT');
      c.p3('PUCSORGBACK');
    }

    c.p3('INSBASE');
    c.p3('EXTMIN');
    c.p3('EXTMAX');
    c.p2rd('LIMMIN');
    c.p2rd('LIMMAX');
    c.bd('ELEVATION');
    c.p3('UCSORG');
    c.p3('UCSXDIR');
    c.p3('UCSYDIR');
    c.handle('UCSNAME');

    if (v2000) {
      c.handle('UCSORTHOREF');
      c.bs('UCSORTHOVIEW');
      c.handle('UCSBASE');
      c.p3('UCSORGTOP');
      c.p3('UCSORGBOTTOM');
      c.p3('UCSORGLEFT');
      c.p3('UCSORGRIGHT');
      c.p3('UCSORGFRONT');
      c.p3('UCSORGBACK');
      if (pre2007) {
        c.inlineTv('DIMPOST');
        c.inlineTv('DIMAPOST');
      }
    }

    if (r13to14) {
      c.b('DIMTOL');
      c.b('DIMLIM');
      c.b('DIMTIH');
      c.b('DIMTOH');
      c.b('DIMSE1');
      c.b('DIMSE2');
      c.b('DIMALT');
      c.b('DIMTOFL');
      c.b('DIMSAH');
      c.b('DIMTIX');
      c.b('DIMSOXD');
      c.rc('DIMALTD');
      c.rc('DIMZIN');
      c.b('DIMSD1');
      c.b('DIMSD2');
      c.rc('DIMTOLJ');
      c.rc('DIMJUST');
      c.rc('DIMFIT');
      c.b('DIMUPT');
      c.rc('DIMTZIN');
      c.rc('DIMALTZ');
      c.rc('DIMALTTZ');
      c.rc('DIMTAD');
      c.bs('DIMUNIT');
      c.bs('DIMAUNIT');
      c.bs('DIMDEC');
      c.bs('DIMTDEC');
      c.bs('DIMALTU');
      c.bs('DIMALTTD');
      c.handle('DIMTXSTY');
    }

    c.bd('DIMSCALE');
    c.bd('DIMASZ');
    c.bd('DIMEXO');
    c.bd('DIMDLI');
    c.bd('DIMEXE');
    c.bd('DIMRND');
    c.bd('DIMDLE');
    c.bd('DIMTP');
    c.bd('DIMTM');

    if (v2007) {
      c.bd('DIMFXL');
      c.bd('DIMJOGANG');
      c.bs('DIMTFILL');
      c.cmc('DIMTFILLCLR');
    }

    if (v2000) {
      c.b('DIMTOL');
      c.b('DIMLIM');
      c.b('DIMTIH');
      c.b('DIMTOH');
      c.b('DIMSE1');
      c.b('DIMSE2');
      c.bs('DIMTAD');
      c.bs('DIMZIN');
      c.bs('DIMAZIN');
    }
    if (v2007) c.bs('DIMARCSYM');

    c.bd('DIMTXT');
    c.bd('DIMCEN');
    c.bd('DIMTSZ');
    c.bd('DIMALTF');
    c.bd('DIMLFAC');
    c.bd('DIMTVP');
    c.bd('DIMTFAC');
    c.bd('DIMGAP');

    if (r13to14) {
      c.inlineTv('DIMPOST');
      c.inlineTv('DIMAPOST');
      c.inlineTv('DIMBLK_T');
      c.inlineTv('DIMBLK1_T');
      c.inlineTv('DIMBLK2_T');
    }

    if (v2000) {
      c.bd('DIMALTRND');
      c.b('DIMALT');
      c.bs('DIMALTD');
      c.b('DIMTOFL');
      c.b('DIMSAH');
      c.b('DIMTIX');
      c.b('DIMSOXD');
    }

    c.cmc('DIMCLRD');
    c.cmc('DIMCLRE');
    c.cmc('DIMCLRT');

    if (v2000) {
      c.bs('DIMADEC');
      c.bs('DIMDEC');
      c.bs('DIMTDEC');
      c.bs('DIMALTU');
      c.bs('DIMALTTD');
      c.bs('DIMAUNIT');
      c.bs('DIMFRAC');
      c.bs('DIMLUNIT');
      c.bs('DIMDSEP');
      c.bs('DIMTMOVE');
      c.bs('DIMJUST');
      c.b('DIMSD1');
      c.b('DIMSD2');
      c.bs('DIMTOLJ');
      c.bs('DIMTZIN');
      c.bs('DIMALTZ');
      c.bs('DIMALTTZ');
      c.b('DIMUPT');
      c.bs('DIMATFIT');
    }
    if (v2007) c.b('DIMFXLON');
    if (v2010) {
      c.b('DIMTXTDIRECTION');
      c.bd('DIMALTMZF');
      c.bd('DIMMZF');
    }

    if (v2000) {
      c.handle('DIMTXSTY');
      c.handle('DIMLDRBLK');
      c.handle('DIMBLK');
      c.handle('DIMBLK1');
      c.handle('DIMBLK2');
    }
    if (v2007) {
      c.handle('DIMLTYPE');
      c.handle('DIMLTEX1');
      c.handle('DIMLTEX2');
    }
    if (v2000) {
      c.bsd('DIMLWD');
      c.bsd('DIMLWE');
    }

    c.handle('BLOCK_CONTROL_OBJECT');
    c.handle('LAYER_CONTROL_OBJECT');
    c.handle('STYLE_CONTROL_OBJECT');
    c.handle('LTYPE_CONTROL_OBJECT');
    c.handle('VIEW_CONTROL_OBJECT');
    c.handle('UCS_CONTROL_OBJECT');
    c.handle('VPORT_CONTROL_OBJECT');
    c.handle('APPID_CONTROL_OBJECT');
    c.handle('DIMSTYLE_CONTROL_OBJECT');
    if (r13to2000) c.handle('VX_CONTROL_OBJECT');

    c.handle('DICTIONARY_ACAD_GROUP');
    c.handle('DICTIONARY_ACAD_MLINESTYLE');
    c.handle('DICTIONARY_NAMED_OBJECT');

    if (v2000) {
      c.bs('TSTACKALIGN');
      c.bs('TSTACKSIZE');
      if (pre2007) {
        c.inlineTv('HYPERLINKBASE');
        c.inlineTv('STYLESHEET');
      }
      c.handle('DICTIONARY_LAYOUT');
      c.handle('DICTIONARY_PLOTSETTINGS');
      c.handle('DICTIONARY_PLOTSTYLENAME');
    }
    if (v2004) {
      c.handle('DICTIONARY_MATERIAL');
      c.handle('DICTIONARY_COLOR');
    }
    if (v2007) c.handle('DICTIONARY_VISUALSTYLE');
    if (v2013) c.handle('unknown_20');

    if (v2000) {
      c.bl('FLAGS');
      c.bs('INSUNITS');
      c.bs('CEPSNTYPE');
      final cepsn = c.out['CEPSNTYPE'] as int? ?? 0;
      if (cepsn == 3) c.handle('CPSNID');
      if (pre2007) {
        c.inlineTv('FINGERPRINTGUID');
        c.inlineTv('VERSIONGUID');
      }
    }

    if (v2004) {
      c.rc('SORTENTS');
      c.rc('INDEXCTL');
      c.rc('HIDETEXT');
      c.rc('XCLIPFRAME');
      c.rc('DIMASSOC');
      c.rc('HALOGAP');
      c.bs('OBSCOLOR');
      c.bs('INTERSECTIONCOLOR');
      c.rc('OBSLTYPE');
      c.rc('INTERSECTIONDISPLAY');
      if (pre2007) c.inlineTv('PROJECTNAME');
    }

    c.handle('BLOCK_RECORD_PSPACE');
    c.handle('BLOCK_RECORD_MSPACE');
    c.handle('LTYPE_BYLAYER');
    c.handle('LTYPE_BYBLOCK');
    c.handle('LTYPE_CONTINUOUS');

    if (v2007) {
      c.b('CAMERADISPLAY');
      c.bl('unknown_21');
      c.bl('unknown_22');
      c.bd('unknown_23');
      c.bd('STEPSPERSEC');
      c.bd('STEPSIZE');
      c.bd('_3DDWFPREC');
      c.bd('LENSLENGTH');
      c.bd('CAMERAHEIGHT');
      c.rc('SOLIDHIST');
      c.rc('SHOWHIST');
      c.bd('PSOLWIDTH');
      c.bd('PSOLHEIGHT');
      c.bd('LOFTANG1');
      c.bd('LOFTANG2');
      c.bd('LOFTMAG1');
      c.bd('LOFTMAG2');
      c.bs('LOFTPARAM');
      c.rc('LOFTNORMALS');
      c.bd('LATITUDE');
      c.bd('LONGITUDE');
      c.bd('NORTHDIRECTION');
      c.bld('TIMEZONE');
      c.rc('LIGHTGLYPHDISPLAY');
      c.rc('TILEMODELIGHTSYNCH');
      c.rc('DWFFRAME');
      c.rc('DGNFRAME');
      c.b('REALWORLDSCALE');
      c.cmc('INTERFERECOLOR');
      c.handle('INTERFEREOBJVS');
      c.handle('INTERFEREVPVS');
      c.handle('DRAGVS');
      c.rc('CSHADOW');
      c.bd('SHADOWPLANELOCATION');
    }

    if (versionAtLeast14(c.version)) {
      c.bs('unknown_54');
      c.bs('unknown_55');
      c.bs('unknown_56');
      c.bs('unknown_57');
    }

    if (v2007) {
      // The R2007+ string stream is read in this fixed order.
      c.streamTu('unit1_name');
      c.streamTu('unit2_name');
      c.streamTu('unit3_name');
      c.streamTu('unit4_name');
      c.streamTu('MENU');
      c.streamTu('DIMPOST');
      c.streamTu('DIMAPOST');
      if (v2010) {
        c.streamTu('DIMALTMZS');
        c.streamTu('DIMMZS');
      }
      c.streamTu('HYPERLINKBASE');
      c.streamTu('STYLESHEET');
      c.streamTu('FINGERPRINTGUID');
      c.streamTu('VERSIONGUID');
      c.streamTu('PROJECTNAME');
    }
  }

  static bool versionAtLeast14(int version) => version >= 14;
}
