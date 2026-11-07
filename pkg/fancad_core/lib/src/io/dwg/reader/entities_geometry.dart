part of '../dwg_reader.dart';

extension on DwgReader {
  List<double> _readLine(DwgBitReader br) {
    if (_version < 2000) {
      // Before R2000 both endpoints are stored in full; the zero-Z flag and
      // delta-coded x/y arrived with the R2000 object format.
      final x1 = br.bd();
      final y1 = br.bd();
      final z1 = br.bd();
      final x2 = br.bd();
      final y2 = br.bd();
      final z2 = br.bd();
      _bt(br);
      _be(br);
      return [x1, y1, z1, x2, y2, z2];
    }
    final zIsZero = br.b();
    final x1 = br.rd();
    final x2 = br.dd(x1);
    final y1 = br.rd();
    final y2 = br.dd(y1);
    var z1 = 0.0;
    var z2 = 0.0;
    if (zIsZero == 0) {
      z1 = br.rd();
      z2 = br.dd(z1);
    }
    _bt(br);
    _be(br);
    return [x1, y1, z1, x2, y2, z2];
  }

  List<double> _readCircle(DwgBitReader br) {
    final cx = br.bd();
    final cy = br.bd();
    final cz = br.bd();
    final radius = br.bd();
    _bt(br);
    _be(br);
    return [cx, cy, cz, radius];
  }

  List<double> _readArc(DwgBitReader br) {
    final cx = br.bd();
    final cy = br.bd();
    final cz = br.bd();
    final radius = br.bd();
    _bt(br);
    _be(br);
    final start = br.bd();
    final end = br.bd();
    return [cx, cy, cz, radius, start, end];
  }

  List<double> _readPoint(DwgBitReader br) {
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    _bt(br);
    _be(br);
    final angle = br.bd();
    return [x, y, z, angle];
  }

  List<double> _readEllipse(DwgBitReader br) {
    final cx = br.bd(), cy = br.bd(), cz = br.bd();
    final ax = br.bd(), ay = br.bd(), az = br.bd();
    br.bd();
    br.bd();
    br.bd(); // extrusion
    final ratio = br.bd();
    final start = br.bd();
    final end = br.bd();
    return [cx, cy, cz, ax, ay, az, ratio, start, end];
  }

  List<double> _readLwPolyline(DwgBitReader br) {
    final flag = br.bs();
    final constantWidth = (flag & 4) != 0 ? br.bd() : 0.0;
    if ((flag & 8) != 0) br.bd(); // elevation
    if ((flag & 2) != 0) br.bd(); // thickness
    if ((flag & 1) != 0) _be(br); // extrusion
    final numPoints = br.bl();
    final numBulges = (flag & 16) != 0 ? br.bl() : 0;
    // R2010+ stores persistent vertex ids after the bulges; without this
    // count the vertices, widths and bulges of such a polyline all shift.
    final numVertexIds = _version >= 2010 && (flag & 1024) != 0 ? br.bl() : 0;
    final numWidths = (flag & 32) != 0 ? br.bl() : 0;
    if (numPoints > 100000 || numBulges > numPoints || numWidths > numPoints) {
      throw const _InvalidObject();
    }

    final values = <double>[numPoints.toDouble(), flag.toDouble()];
    if (numPoints > 0) {
      if (_version < 2000) {
        // R13/R14 store every vertex in full; the delta-coded pairs are
        // R2000.
        for (var i = 0; i < numPoints; i++) {
          values
            ..add(br.rd())
            ..add(br.rd());
        }
      } else {
        var x = br.rd();
        var y = br.rd();
        values
          ..add(x)
          ..add(y);
        for (var i = 1; i < numPoints; i++) {
          x = br.dd(x);
          y = br.dd(y);
          values
            ..add(x)
            ..add(y);
        }
      }
    }
    final bulges = <double>[];
    for (var i = 0; i < numBulges; i++) {
      bulges.add(br.bd());
    }
    for (var i = 0; i < numVertexIds; i++) {
      br.bl();
    }
    for (var i = 0; i < numWidths; i++) {
      br.bd();
      br.bd();
    }
    return [...values, ...bulges, if ((flag & 4) != 0) constantWidth];
  }

  List<double> _readPolyline2d(DwgBitReader br) {
    final flag = br.bs();
    final curveType = br.bs();
    final startWidth = br.bd();
    final endWidth = br.bd();
    final thickness = _bt(br);
    final elevation = br.bd();
    _be(br);
    if (_version >= 2004) br.bl(); // num_owned
    return [
      flag.toDouble(),
      curveType.toDouble(),
      startWidth,
      endWidth,
      thickness,
      elevation,
    ];
  }

  List<double> _readVertex2d(DwgBitReader br) {
    final flag = br.rc();
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    var startWidth = br.bd();
    final double endWidth;
    if (startWidth < 0) {
      endWidth = -startWidth;
      startWidth = endWidth;
    } else {
      endWidth = br.bd();
    }
    final bulge = br.bd();
    if (_version >= 2010) br.bl(); // id
    final tangent = br.bd();
    return [flag.toDouble(), x, y, z, startWidth, endWidth, bulge, tangent];
  }

  List<double> _readPolyline3d(DwgBitReader br) {
    final curveType = br.rc();
    final flag = br.rc();
    if (_version >= 2004) br.bl(); // num_owned
    return [curveType.toDouble(), flag.toDouble()];
  }

  List<double> _readVertex3d(DwgBitReader br) {
    final flag = br.rc();
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    return [flag.toDouble(), x, y, z];
  }

  List<double> _readPolylineMesh(DwgBitReader br) {
    final flag = br.bs();
    final curveType = br.bs();
    final m = br.bs();
    final n = br.bs();
    final mDensity = br.bs();
    final nDensity = br.bs();
    if (_version >= 2004) br.bl(); // num_owned; handles carry the vertices
    return [
      flag.toDouble(),
      curveType.toDouble(),
      m.toDouble(),
      n.toDouble(),
      mDensity.toDouble(),
      nDensity.toDouble(),
    ];
  }

  List<double> _readOle2Frame(DwgBitReader br) {
    // The OLE object itself is opaque; skip it so the census and the
    // following handles stay aligned. Geometry is the frame corners, which
    // are only in the embedded header.
    br.bs(); // object type: link, embedded or static
    if (_version >= 2000) br.bs(); // tile mode
    final size = br.bl();
    if (size > 0) br.skip(size * 8);
    if (_version >= 2000) br.rc(); // lock aspect
    return const [];
  }

  List<double> _readShape(DwgBitReader br) {
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    final scale = br.bd();
    final rotation = br.bd();
    final width = br.bd();
    final oblique = br.bd();
    br.bs(); // style_id: index into the STYLE table
    br.bd();
    br.bd();
    br.bd(); // extrusion
    return [x, y, z, scale, rotation, width, oblique];
  }

  List<double> _readPolylinePface(DwgBitReader br) {
    final numVerts = br.bs();
    final numFaces = br.bs();
    if (_version >= 2004) br.bl(); // num_owned
    return [numVerts.toDouble(), numFaces.toDouble()];
  }

  List<double> _readVertexPface(DwgBitReader br) {
    final flag = br.rc();
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    return [flag.toDouble(), x, y, z];
  }

  List<double> _readVertexPfaceFace(DwgBitReader br) {
    // R13+ stores only the four vertex indices; the flag is implicit.
    final indices = <double>[128];
    for (var i = 0; i < 4; i++) {
      var value = br.bs();
      if (value > 0x7fff) value -= 0x10000;
      indices.add(value.toDouble());
    }
    return indices;
  }

  List<double> _readViewport(DwgBitReader br) {
    final x = br.bd();
    final y = br.bd();
    final z = br.bd();
    final width = br.bd();
    final height = br.bd();
    final values = <double>[x, y, z, width, height];
    if (_version < 2000) return values;

    // Model view and its projection. The layout mapping needs the view
    // centre and height to turn these into a PaperViewport.
    final target = [br.bd(), br.bd(), br.bd()];
    final direction = [br.bd(), br.bd(), br.bd()];
    final twist = br.bd();
    final viewSize = br.bd();
    final lensLength = br.bd();
    final frontZ = br.bd();
    final backZ = br.bd();
    final snapAngle = br.bd();
    final viewCenter = [br.rd(), br.rd()];
    final snapBase = [br.rd(), br.rd()];
    final snapUnit = [br.rd(), br.rd()];
    final gridUnit = [br.rd(), br.rd()];
    final circleZoom = br.bs();
    final gridMajor = _version >= 2007 ? br.bs() : 0;
    final numFrozen = br.bl();
    final statusFlag = br.bl();
    values.addAll([
      ...target,
      ...direction,
      twist,
      viewSize,
      lensLength,
      frontZ,
      backZ,
      snapAngle,
      ...viewCenter,
      ...snapBase,
      ...snapUnit,
      ...gridUnit,
      circleZoom.toDouble(),
      gridMajor.toDouble(),
      numFrozen.toDouble(),
      statusFlag.toDouble(),
    ]);
    _lastViewportFrozen = numFrozen;
    return values;
  }

  List<double> _readSolid(DwgBitReader br) {
    _bt(br);
    br.bd(); // elevation
    final values = <double>[];
    for (var i = 0; i < 4; i++) {
      values
        ..add(br.rd())
        ..add(br.rd());
    }
    _be(br);
    return values;
  }

  List<double> _read3dFace(DwgBitReader br) {
    if (_version < 2000) {
      // Before R2000 all four corners are plain BD triples and the
      // invisible-edge flags always follow.
      final values = <double>[];
      for (var i = 0; i < 4; i++) {
        values
          ..add(br.bd())
          ..add(br.bd())
          ..add(br.bd());
      }
      br.bs(); // invis_flags
      return values;
    }
    final hasNoFlags = br.b();
    final zIsZero = br.b();
    var x = br.rd();
    var y = br.rd();
    var z = zIsZero != 0 ? 0.0 : br.rd();
    final values = <double>[x, y, z];
    for (var i = 1; i < 4; i++) {
      x = br.dd(x);
      y = br.dd(y);
      z = br.dd(z);
      values
        ..add(x)
        ..add(y)
        ..add(z);
    }
    if (hasNoFlags == 0) br.bs();
    return values;
  }

  List<double> _readSpline(DwgBitReader br) {
    var scenario = br.bl();
    if (_version >= 2013) {
      final splineFlags = br.bl();
      final knotParam = br.bl();
      if ((splineFlags & 1) != 0) scenario = 2;
      if (knotParam == 15) scenario = 1;
    }
    final degree = br.bl();
    var closed = 0;
    var weighted = 0;
    var numKnots = 0;
    var numCtrl = 0;
    var numFit = 0;
    final knots = <double>[];
    final ctrl = <double>[];
    final fit = <double>[];

    if ((scenario & 1) != 0) {
      br.b(); // rational
      closed = br.b();
      br.b(); // periodic
      br.bd(); // knot tolerance
      br.bd(); // control tolerance
      numKnots = br.bl();
      numCtrl = br.bl();
      if (numKnots > 100000 || numCtrl > 100000) {
        throw const _InvalidObject();
      }
      weighted = br.b();
      for (var i = 0; i < numKnots && i < 100000; i++) {
        knots.add(br.bd());
      }
      for (var i = 0; i < numCtrl && i < 100000; i++) {
        final x = br.bd();
        final y = br.bd();
        br.bd(); // z
        final w = weighted != 0 ? br.bd() : 1.0;
        ctrl
          ..add(x)
          ..add(y)
          ..add(w);
      }
    } else {
      br.bd(); // fit tolerance
      br.bd();
      br.bd();
      br.bd(); // begin tangent
      br.bd();
      br.bd();
      br.bd(); // end tangent
      numFit = br.bl();
      if (numFit > 100000) throw const _InvalidObject();
      for (var i = 0; i < numFit; i++) {
        final x = br.bd();
        final y = br.bd();
        br.bd(); // z
        fit
          ..add(x)
          ..add(y);
      }
    }
    return [
      degree.toDouble(),
      closed.toDouble(),
      numKnots.toDouble(),
      numCtrl.toDouble(),
      weighted.toDouble(),
      numFit.toDouble(),
      ...knots,
      ...ctrl,
      ...fit,
    ];
  }

  List<double> _readRay(DwgBitReader br) {
    final x = br.bd(), y = br.bd(), z = br.bd();
    final dx = br.bd(), dy = br.bd(), dz = br.bd();
    return [x, y, z, dx, dy, dz];
  }

  List<double> _readMline(DwgBitReader br) {
    br.bd(); // scale
    br.rc(); // justification
    br.bd();
    br.bd();
    br.bd(); // base point
    br.bd();
    br.bd();
    br.bd(); // extrusion
    br.bs(); // flags
    final numLines = br.rc();
    final numVerts = br.bs();
    final values = <double>[numVerts.toDouble()];
    for (var v = 0; v < numVerts && v < 5000; v++) {
      values.add(br.bd());
      values.add(br.bd());
      br.bd(); // vertex z
      br.bd();
      br.bd();
      br.bd(); // vertex direction
      br.bd();
      br.bd();
      br.bd(); // miter direction
      for (var l = 0; l < numLines && l < 1000; l++) {
        final numSeg = br.bs();
        for (var k = 0; k < numSeg && k < 5000; k++) {
          br.bd();
        }
        final numFill = br.bs();
        for (var k = 0; k < numFill && k < 5000; k++) {
          br.bd();
        }
      }
    }
    return values;
  }
}
