part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readText(DwgBitReader br) {
    final parsed = _readTextLike(br);
    _lastText = parsed.text;
    _lastTag = '';
    _lastPrompt = '';
    _lastFlags = 0;
    return parsed.values;
  }

  List<double> _readAttrib(DwgBitReader br) {
    final parsed = _readTextLike(br);
    _lastText = parsed.text;
    _lastTag = _text(br);
    br.bs(); // field_length
    _lastFlags = br.rc();
    if (_version >= 2007) br.b(); // lock_position_flag
    _lastPrompt = '';
    return parsed.values;
  }

  List<double> _readAttdef(DwgBitReader br) {
    final parsed = _readTextLike(br);
    _lastText = parsed.text;
    _lastTag = _text(br);
    br.bs(); // field_length
    _lastFlags = br.rc();
    if (_version >= 2007) br.b(); // lock_position_flag
    _lastPrompt = _text(br);
    return parsed.values;
  }

  List<double> _readMtext(DwgBitReader br) {
    final x = br.bd(), y = br.bd(), z = br.bd();
    br.bd();
    br.bd();
    br.bd(); // extrusion
    final dirX = br.bd(), dirY = br.bd(), dirZ = br.bd();
    final width = br.bd();
    if (_version >= 2007) br.bd(); // rectangle height
    final height = br.bd();
    final attachment = br.bs();
    final flow = br.bs();
    final extH = br.bd();
    final extW = br.bd();
    final text = _text(br);
    if (_version >= 2000) {
      br.bs(); // linespace_style
      br.bd(); // linespace_factor
      br.b(); // unknown_b0
    }
    if (_version >= 2004) {
      final flag = br.bl();
      if ((flag & 1) != 0) {
        br.bl(); // fill scale
        br.bs(); // fill colour index
        br.bl(); // fill true colour
        br.rc(); // fill colour flag
        br.bl(); // fill transparency
      }
    }
    _lastText = text;
    return [
      x,
      y,
      z,
      dirX,
      dirY,
      dirZ,
      width,
      height,
      attachment.toDouble(),
      flow.toDouble(),
      extH,
      extW,
    ];
  }

  List<double> _readTolerance(DwgBitReader br) {
    if (_version < 2000) {
      br.bs(); // unknown_short (ODA encodes it as a bit short)
      br.bd(); // height
      br.bd(); // dimgap
    }
    final x = br.bd();
    final y = br.bd();
    br.bd(); // z
    final dx = br.bd();
    final dy = br.bd();
    br.bd(); // x direction z
    br.bd();
    br.bd();
    br.bd(); // extrusion
    _lastText = _text(br);
    _lastTag = '';
    _lastPrompt = '';
    _lastFlags = 0;
    return [x, y, dx, dy];
  }
}
