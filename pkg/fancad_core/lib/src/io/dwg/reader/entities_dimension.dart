part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readDimension(DwgBitReader br, int type) {
    final c = _readDimensionCommon(br);
    final tx = c.tx;
    final ty = c.ty;
    final measurement = c.meas;
    final cx = c.cx;
    final cy = c.cy;
    final sx = c.sx;
    final sy = c.sy;
    final sz = c.sz;
    final rotation = c.rot;

    final points = <double>[];
    void addPoint(double x, double y) {
      points.add(x);
      points.add(y);
    }

    void read3(double Function() next) {
      addPoint(next(), next());
      next();
    }

    var family = 0;
    switch (type) {
      case DwgReader._typeDimOrdinate:
        family = 6;
        read3(br.bd);
        read3(br.bd);
        read3(br.bd);
        br.rc(); // flag2
      case DwgReader._typeDimLinear:
      case DwgReader._typeDimAligned:
        family = type == DwgReader._typeDimAligned ? 1 : 0;
        read3(br.bd);
        read3(br.bd);
        read3(br.bd);
        br.bd(); // oblique angle
      case DwgReader._typeDimAng3pt:
        family = 5;
        read3(br.bd);
        read3(br.bd);
        read3(br.bd);
        read3(br.bd);
      case DwgReader._typeDimAng2ln:
        family = 2;
        final defX = br.rd();
        final defY = br.rd(); // def_pt 2RD
        read3(br.bd); // xline1start_pt
        read3(br.bd); // xline1end_pt
        read3(br.bd); // xline2start_pt
        br.bd();
        br.bd();
        br.bd(); // xline2end_pt, not a definition point
        addPoint(defX, defY); // the arc point is the fourth definition point
      case DwgReader._typeDimRadius:
        family = 4;
        read3(br.bd);
        read3(br.bd);
        br.bd(); // leader length
      case DwgReader._typeDimDiameter:
        family = 3;
        read3(br.bd);
        read3(br.bd);
        br.bd(); // leader length
    }
    return [
      tx,
      ty,
      measurement,
      family.toDouble(),
      cx,
      cy,
      sx,
      sy,
      sz,
      rotation,
      points.length / 2.0,
      ...points,
    ];
  }

  List<double> _readArcDimension(DwgBitReader br) {
    final c = _readDimensionCommon(br);
    final points = <double>[];
    for (var i = 0; i < 4; i++) {
      points.add(br.bd());
      points.add(br.bd());
      br.bd();
    }
    br.b(); // is_partial
    br.bd(); // arc start
    br.bd(); // arc end
    final hasLeader = br.b();
    if (hasLeader != 0) {
      for (var i = 0; i < 2; i++) {
        points.add(br.bd());
        points.add(br.bd());
        br.bd();
      }
    }
    return [
      c.tx,
      c.ty,
      c.meas,
      8.0,
      c.cx,
      c.cy,
      c.sx,
      c.sy,
      c.sz,
      c.rot,
      points.length / 2.0,
      ...points,
    ];
  }
}
