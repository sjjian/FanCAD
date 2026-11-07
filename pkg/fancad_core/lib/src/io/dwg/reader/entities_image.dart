part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readImage(DwgBitReader br) {
    br.bl(); // class version
    final x = br.bd(), y = br.bd();
    br.bd(); // z
    final ux = br.bd(), uy = br.bd();
    br.bd(); // uz
    final vx = br.bd(), vy = br.bd();
    br.bd(); // vz
    final width = br.rd();
    final height = br.rd(); // image size
    br.bs(); // display props
    br.b(); // clipping
    br.rc(); // brightness
    br.rc(); // contrast
    br.rc(); // fade
    if (_version >= 2010) br.b(); // clip mode
    final clipType = br.bs();
    final count = clipType == 1 ? 2 : br.bl();
    final verts = <double>[];
    for (var i = 0; i < count && i < 5000; i++) {
      verts.add(br.rd());
      verts.add(br.rd());
    }
    return [x, y, ux, uy, vx, vy, width, height, ...verts];
  }
}
