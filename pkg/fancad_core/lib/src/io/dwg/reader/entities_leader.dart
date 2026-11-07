part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readLeader(DwgBitReader br) {
    br.b(); // unknown_bit_1
    br.bs(); // annot_type
    br.bs(); // path_type
    final num = br.bl();
    final points = <double>[];
    for (var i = 0; i < num && i < 100000; i++) {
      points.add(br.bd());
      points.add(br.bd());
      br.bd(); // z
    }
    br.bd();
    br.bd();
    br.bd(); // origin
    br.bd();
    br.bd();
    br.bd(); // extrusion
    br.bd();
    br.bd();
    br.bd(); // x_direction
    br.bd();
    br.bd();
    br.bd(); // inspt_offset
    if (_version <= 2007) {
      br.bd();
      br.bd();
      br.bd(); // endptproj (R13c3-R2007)
    }
    br.bd(); // box_height
    br.bd(); // box_width
    br.b(); // hookline_dir
    final arrow = br.b();
    br.bs(); // arrowhead_type
    if (_version >= 2000) {
      br.b();
      br.b();
    }
    return [num.toDouble(), arrow.toDouble(), ...points];
  }

  List<double> _readMleader(DwgBitReader br) {
    if (_version >= 2010) br.bs(); // class version
    final numLeaders = br.bl();
    final points = <double>[];
    for (var i = 0; i < numLeaders && i < 5000; i++) {
      final hasLast = br.b();
      final hasDogleg = br.b();
      if (hasLast != 0) {
        points.add(br.bd());
        points.add(br.bd());
        br.bd();
      }
      if (hasDogleg != 0) {
        br.bd();
        br.bd();
        br.bd();
      }
      final numBreaks = br.bl();
      for (var b = 0; b < numBreaks && b < 5000; b++) {
        br.bd();
        br.bd();
        br.bd();
        br.bd();
        br.bd();
        br.bd();
      }
      br.bl(); // branch index
      br.bd(); // dogleg length
      final numLines = br.bl();
      for (var l = 0; l < numLines && l < 5000; l++) {
        final numPoints = br.bl();
        for (var p = 0; p < numPoints && p < 5000; p++) {
          points.add(br.bd());
          points.add(br.bd());
          br.bd();
        }
        final lineBreaks = br.bl();
        for (var b = 0; b < lineBreaks && b < 5000; b++) {
          br.bd();
          br.bd();
          br.bd();
          br.bd();
          br.bd();
          br.bd();
        }
        br.bl(); // line index
        if (_version >= 2010) {
          br.bs(); // line type
          _readCmc(br); // colour
          br.bl(); // line weight
          br.bd(); // arrow size
          br.bl(); // flags
        }
      }
    }
    if (_version >= 2010) br.bs(); // attach direction

    br.bd(); // scale factor
    br.bd();
    br.bd();
    br.bd(); // content base
    final textHeight = br.bd();
    br.bd(); // arrow size
    br.bd(); // landing gap
    br.bs();
    br.bs();
    br.bs();
    br.bs(); // text left/right/angle type/alignment
    final hasText = br.b();
    var text = '';
    var tx = 0.0;
    var ty = 0.0;
    var rotation = 0.0;
    var width = 0.0;
    if (hasText != 0) {
      text = _text(br);
      br.bd();
      br.bd();
      br.bd(); // normal
      tx = br.bd();
      ty = br.bd();
      br.bd(); // location
      br.bd();
      br.bd();
      br.bd(); // direction
      rotation = br.bd();
      width = br.bd();
      br.bd(); // height
      br.bd(); // line spacing factor
      br.bs(); // line spacing style
      _readCmc(br); // colour
      br.bs(); // alignment
      br.bs(); // flow
      _readCmc(br); // background colour
      br.bd(); // background scale
      br.bl(); // background transparency
      br.b();
      br.b(); // is_bg_fill, is_bg_mask_fill
      br.bs(); // column type
      br.b(); // is_height_auto
      br.bd(); // column width
      br.bd(); // gutter
      br.b(); // reversed
      final numCols = br.bl();
      for (var i = 0; i < numCols && i < 5000; i++) {
        br.bd();
      }
      br.b();
      br.b(); // word break, unknown
    } else {
      final hasBlock = br.b();
      if (hasBlock != 0) {
        br.bd();
        br.bd();
        br.bd(); // normal
        tx = br.bd();
        ty = br.bd();
        br.bd(); // location
        br.bd();
        br.bd();
        br.bd(); // scale
        br.bd(); // rotation
        _readCmc(br); // colour
        for (var i = 0; i < 16; i++) {
          br.bd();
        }
      }
    }
    _lastText = text;
    return [
      tx,
      ty,
      textHeight,
      width,
      rotation,
      points.length / 2.0,
      ...points,
    ];
  }

  int _readCmc(DwgBitReader br) {
    final index = br.bs();
    if (_version >= 2004) {
      br.bl(); // true colour
      br.rc(); // flag
    }
    return index;
  }
}
