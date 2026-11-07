part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readInsert(DwgBitReader br) {
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    if (_version < 2000) {
      // R13/R14 always store all three scales; the scale flag is R2000.
      final sx = br.bd();
      final sy = br.bd();
      final sz = br.bd();
      final rotation = br.bd();
      br.bd();
      br.bd();
      br.bd(); // extrusion
      br.b(); // has_attribs
      return [x, y, z, sx, sy, sz, rotation];
    }
    final scaleFlag = br.bb();
    double sx = 1, sy = 1, sz = 1;
    switch (scaleFlag) {
      case 1:
        sy = br.dd(1);
        sz = br.dd(1);
      case 2:
        sx = br.rd();
        sy = sx;
        sz = sx;
      case 0:
        sx = br.rd();
        sy = br.dd(sx);
        sz = br.dd(sx);
    }
    final rotation = br.bd();
    br.bd();
    br.bd();
    br.bd(); // extrusion (3BD)
    final hasAttribs = br.b();
    if (_version >= 2004 && hasAttribs != 0) br.bl(); // num_owned
    return [x, y, z, sx, sy, sz, rotation];
  }

  List<double> _readMinsert(DwgBitReader br) {
    final values = _readInsert(br);
    values.addAll([
      br.bs().toDouble(), // num_cols
      br.bs().toDouble(), // num_rows
      br.bd(), // col_spacing
      br.bd(), // row_spacing
    ]);
    return values;
  }
}
