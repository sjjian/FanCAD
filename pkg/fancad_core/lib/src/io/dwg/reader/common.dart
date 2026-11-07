part of '../dwg_reader.dart';

extension on DwgReader {
  /// Common entity data, shared by every entity type.
  ///
  /// [previewRead] is true for R13/R14, whose preview bitmap and bitsize are
  /// already consumed while framing the object: those versions put the object
  /// handle and EED ahead of the bitsize (see [_decodeObject]).
  void _readCommonEntity(DwgBitReader br, {bool previewRead = false}) {
    if (!previewRead) {
      final preview = br.b();
      if (preview != 0) {
        final previewSize = _version >= 2010 ? br.bll() : br.rl();
        br.skip(previewSize * 8);
      }
    }
    _entmode = br.bb();
    _numReactors = br.bl();
    _colorRgb = null;
    _alpha = 255;
    _alphaType = 0;
    _lineWeight = 29;
    if (_version < 2000) {
      // R13/R14: one bit says the linetype is ByLayer, there is no colour
      // encoding word, no plot style, and no line weight.
      final isByLayerLtype = br.b() != 0;
      _ltypeFlags = isByLayerLtype ? 0 : 3;
      _nolinks = br.b();
      _colorIndex = br.bs(); // CMC: ACI index with flags in the high byte
      _lineTypeScale = br.bd();
      _invisible = br.bs();
      return;
    }
    if (_version >= 2004) {
      _isXdicMissing = br.b() != 0;
      if (_version >= 2013) br.b(); // has_ds_data
      final raw = br.bs();
      _colorIndex = raw & 0x1ff;
      final flags = raw >> 8;
      if ((flags & 0x80) != 0) _colorRgb = br.bl(); // true colour
      if ((flags & 0x20) != 0) {
        final encoded = br.bl();
        _alphaType = encoded >> 24;
        _alpha = encoded & 0xff;
      }
      if ((flags & 0x41) == 0x41) _text(br); // colour name
      if ((flags & 0x42) == 0x42) _text(br); // colour book
    } else {
      _nolinks = br.b();
      _colorIndex = br.bs();
    }
    _lineTypeScale = br.bd();
    _ltypeFlags = br.bb();
    _plotstyleFlags = br.bb();
    if (_version >= 2007) {
      br.bb(); // material flags
      br.rc(); // shadow flags
    }
    if (_version >= 2010) {
      br.b(); // full visual style
      br.b(); // face visual style
      br.b(); // edge visual style
    }
    _invisible = br.bs();
    _lineWeight = br.rc();
  }
}

extension on DwgReader {
  /// `BT` thickness: R2000+ prefixes a bit meaning the default zero, while
  /// R13/R14 store only the BD value.
  double _bt(DwgBitReader br) {
    if (_version >= 2000 && br.b() != 0) return 0;
    return br.bd();
  }

  /// `BE` extrusion: R2000+ may encode the default (0, 0, 1) in a single bit.
  List<double> _be(DwgBitReader br) {
    if (_version >= 2000 && br.b() != 0) return const [0, 0, 1];
    final x = br.bd();
    final y = br.bd();
    var z = br.bd();
    if (x == 0 && y == 0) z = z <= 0 ? -1 : 1;
    return [x, y, z];
  }
}
