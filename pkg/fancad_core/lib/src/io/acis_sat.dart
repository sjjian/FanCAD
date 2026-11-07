import 'dart:typed_data';

import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../model/entity/entity.dart';

/// Reads the planar loops of an ACIS SAT v1 REGION.
///
/// Only the subset a 2D REGION needs is interpreted: `loop`, `coedge`,
/// `edge`, `vertex`, `point` and `ellipse-curve`. Other curve records fall
/// back to a straight segment and mark the result as approximated, which is
/// better than dropping the REGION.
class AcisSatReader {
  const AcisSatReader();

  /// Parses [sat] into components.
  ///
  /// [transform] is the ACIS transform extracted from the original SAB
  /// payload. It is applied once here; the SAT conversion usually keeps only
  /// a `transform $-1 $-1 #` stub.
  RegionGeometry? read(String sat, {Mat3? transform, double tolerance = 1e-6}) {
    final records = _parse(_skipHeader(sat));
    return _fromRecords(
      records,
      approximated: _headerApproximated(sat),
      transform: transform,
      tolerance: tolerance,
    );
  }

  /// Parses an ACIS binary SAB payload without materialising SAT text first.
  ///
  /// The tag stream is mapped straight onto the same records [read] produces,
  /// so loop grouping and geometry are shared.
  RegionGeometry? readSab(
    Uint8List sab, {
    Mat3? transform,
    double tolerance = 1e-6,
  }) {
    final parsed = _parseSab(sab);
    if (parsed == null) return null;
    return _fromRecords(
      parsed.records,
      approximated: parsed.approximated,
      transform: transform,
      tolerance: tolerance,
    );
  }

  RegionGeometry? _fromRecords(
    List<_Record> records, {
    required bool approximated,
    Mat3? transform,
    double tolerance = 1e-6,
  }) {
    if (records.isEmpty) return null;
    final loops = <RegionLoop>[];
    final state = _ReadState()..approximated = approximated;
    final used = <int>{};
    for (var i = 0; i < records.length; i++) {
      if (records[i].kind != _Kind.loop) continue;
      final loop = _readLoop(records, i, used, state);
      if (loop == null || loop.isEmpty) continue;
      loops.add(loop);
    }
    if (loops.isEmpty) return null;
    final geometry = RegionGeometry.fromLoops(
      loops,
      approximated: state.approximated,
      tolerance: tolerance,
    );
    return transform == null ? geometry : geometry.transformed(transform);
  }

  RegionLoop? _readLoop(
    List<_Record> records,
    int loopIndex,
    Set<int> used,
    _ReadState state,
  ) {
    final loop = records[loopIndex];
    var start = -1;
    // SAT loop records differ by writer/version: some put the first coedge at
    // ref[3], newer ones at ref[4] with a next-loop link in ref[3]. Take the
    // first reference that actually points at a coedge.
    for (var r = 0; r < loop.refs.length; r++) {
      final index = loop.refs[r];
      if (index >= 0 &&
          index < records.length &&
          records[index].kind == _Kind.coedge) {
        start = index;
        break;
      }
    }
    if (start < 0 || used.contains(start)) return null;
    final curves = <RegionCurve>[];
    var current = start;
    for (var guard = 0; guard <= records.length; guard++) {
      if (current < 0 || current >= records.length) break;
      final coedge = records[current];
      if (coedge.kind != _Kind.coedge || used.contains(current)) break;
      used.add(current);
      final edgeIndex = coedge.refs.length > 6 ? coedge.refs[6] : -1;
      final edge = _edge(records, edgeIndex);
      if (edge != null) {
        final curve = _curveFor(records, edge, coedge.reversed, state);
        if (curve != null) curves.add(curve);
      }
      final next = coedge.refs.length > 3 ? coedge.refs[3] : -1;
      if (next == start) break;
      current = next;
    }
    if (curves.isEmpty) return null;
    return RegionLoop(curves);
  }

  _Edge? _edge(List<_Record> records, int index) {
    if (index < 0 || index >= records.length) return null;
    final record = records[index];
    if (record.kind != _Kind.edge || record.refs.length < 7) return null;
    return _Edge(
      start: record.refs[3],
      end: record.refs[4],
      curve: record.refs[6],
      startParam: record.nums.isNotEmpty ? record.nums[0] : 0,
      endParam: record.nums.length > 1 ? record.nums[1] : 0,
    );
  }

  RegionCurve? _curveFor(
    List<_Record> records,
    _Edge edge,
    bool reversed,
    _ReadState state,
  ) {
    final start = _vertex(records, edge.start);
    final end = _vertex(records, edge.end);
    final curveIndex = edge.curve;
    _Record? curve;
    if (curveIndex >= 0 && curveIndex < records.length) {
      curve = records[curveIndex];
    }
    if (curve != null &&
        curve.kind == _Kind.ellipse &&
        curve.nums.length >= 10) {
      final center = Vec2(curve.nums[0], curve.nums[1]);
      final nx = curve.nums[3];
      final ny = curve.nums[4];
      final nz = curve.nums[5];
      final mx = curve.nums[6];
      final my = curve.nums[7];
      final ratio = curve.nums[9];
      final vx = ny * 0 - nz * my;
      final vy = nz * mx - nx * 0;
      final u = Vec2(mx, my);
      final v = Vec2(vx, vy) * ratio;
      final arc = RegionConicArc(
        center: center,
        u: u,
        v: v,
        startParameter: reversed ? edge.endParam : edge.startParam,
        sweep: reversed
            ? edge.startParam - edge.endParam
            : edge.endParam - edge.startParam,
      );
      return arc;
    }
    if (curve != null &&
        curve.kind != _Kind.straight &&
        curve.name != 'coedge' &&
        curve.name != 'edge' &&
        curve.name != 'vertex') {
      state.approximated = true;
    }
    if (start == null || end == null) {
      if (curve != null) state.approximated = true;
      return null;
    }
    return reversed
        ? RegionLine(start: end, end: start)
        : RegionLine(start: start, end: end);
  }

  Vec2? _vertex(List<_Record> records, int index) {
    if (index < 0 || index >= records.length) return null;
    final vertex = records[index];
    if (vertex.kind != _Kind.vertex || vertex.refs.isEmpty) return null;
    final pointIndex = vertex.refs.last;
    if (pointIndex < 0 || pointIndex >= records.length) return null;
    final point = records[pointIndex];
    if (point.kind != _Kind.point || point.nums.length < 3) return null;
    return Vec2(
      point.nums[point.nums.length - 3],
      point.nums[point.nums.length - 2],
    );
  }

  static String _skipHeader(String sat) {
    var index = 0;
    for (var line = 0; line < 3; line++) {
      final next = sat.indexOf('\n', index);
      if (next < 0) return '';
      index = next + 1;
    }
    return sat.substring(index);
  }

  /// The product field on the second header line is the only safe place to
  /// carry a non-geometric marker through SAT, SAB, DXF and DWG: ACIS ignores
  /// the product name, while FanCAD can still distinguish a flattened REGION.
  static bool _headerApproximated(String sat) {
    final first = sat.indexOf('\n');
    if (first < 0) return false;
    final second = sat.indexOf('\n', first + 1);
    if (second < 0) return false;
    return sat.substring(first + 1, second).contains('FanCAD_APPROX');
  }

  List<_Record> _parse(String text) {
    final records = <_Record>[];
    var i = 0;
    while (i < text.length) {
      while (i < text.length && _isSpace(text.codeUnitAt(i))) {
        i++;
      }
      if (i >= text.length) break;
      if (text.codeUnitAt(i) == 0x2d && i + 1 < text.length) {
        final next = text.codeUnitAt(i + 1);
        if (next >= 0x30 && next <= 0x39) {
          i++;
          while (i < text.length) {
            final c = text.codeUnitAt(i);
            if (c < 0x30 || c > 0x39) break;
            i++;
          }
          while (i < text.length && _isSpace(text.codeUnitAt(i))) {
            i++;
          }
        }
      }
      final nameStart = i;
      while (i < text.length) {
        final c = text.codeUnitAt(i);
        if (_isSpace(c) || c == 0x23 || c == 0x7b) break;
        i++;
      }
      final name = text.substring(nameStart, i);
      final record = _Record(name, _kindOf(name));
      while (i < text.length && text.codeUnitAt(i) != 0x23) {
        while (i < text.length && _isSpace(text.codeUnitAt(i))) {
          i++;
        }
        if (i >= text.length || text.codeUnitAt(i) == 0x23) break;
        final c = text.codeUnitAt(i);
        if (c == 0x7b) {
          var depth = 1;
          i++;
          while (i < text.length && depth > 0) {
            if (text.codeUnitAt(i) == 0x7b) depth++;
            if (text.codeUnitAt(i) == 0x7d) depth--;
            i++;
          }
          continue;
        }
        if (c == 0x24) {
          i++;
          final start = i;
          if (i < text.length &&
              (text.codeUnitAt(i) == 0x2d || text.codeUnitAt(i) == 0x2b)) {
            i++;
          }
          while (i < text.length) {
            final d = text.codeUnitAt(i);
            if (d < 0x30 || d > 0x39) break;
            i++;
          }
          record.refs.add(int.tryParse(text.substring(start, i)) ?? -1);
          continue;
        }
        if (c == 0x2d || c == 0x2e || (c >= 0x30 && c <= 0x39)) {
          final start = i;
          if (text.codeUnitAt(i) == 0x2d) i++;
          var dot = false;
          while (i < text.length) {
            final d = text.codeUnitAt(i);
            if (d == 0x2e && !dot) {
              dot = true;
              i++;
              continue;
            }
            if (d < 0x30 || d > 0x39) break;
            i++;
          }
          if (i < text.length &&
              (text.codeUnitAt(i) == 0x65 || text.codeUnitAt(i) == 0x45)) {
            i++;
            if (i < text.length &&
                (text.codeUnitAt(i) == 0x2d || text.codeUnitAt(i) == 0x2b)) {
              i++;
            }
            while (i < text.length) {
              final d = text.codeUnitAt(i);
              if (d < 0x30 || d > 0x39) break;
              i++;
            }
          }
          record.nums.add(double.tryParse(text.substring(start, i)) ?? 0);
          continue;
        }
        if (record.kind == _Kind.coedge) {
          if (c == 0x49 || c == 0x46 || c == 0x54) {
            if (i + 1 >= text.length ||
                _isSpace(text.codeUnitAt(i + 1)) ||
                text.codeUnitAt(i + 1) == 0x23) {
              record.reversed = c == 0x49 || c == 0x54;
              i++;
              continue;
            }
          }
          if (text.startsWith('reversed', i)) {
            record.reversed = true;
            i += 8;
            continue;
          }
          if (text.startsWith('forward', i)) {
            record.reversed = false;
            i += 7;
            continue;
          }
          // SAB->SAT1 writes the coedge orientation as true/false; older
          // writers use the single letters T/F.
          if (text.startsWith('true', i) &&
              (i + 4 >= text.length ||
                  _isSpace(text.codeUnitAt(i + 4)) ||
                  text.codeUnitAt(i + 4) == 0x23)) {
            record.reversed = true;
            i += 4;
            continue;
          }
          if (text.startsWith('false', i) &&
              (i + 5 >= text.length ||
                  _isSpace(text.codeUnitAt(i + 5)) ||
                  text.codeUnitAt(i + 5) == 0x23)) {
            record.reversed = false;
            i += 5;
            continue;
          }
        }
        while (i < text.length) {
          final d = text.codeUnitAt(i);
          if (_isSpace(d) || d == 0x23) break;
          i++;
        }
      }
      if (i < text.length) i++;
      records.add(record);
    }
    return records;
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  /// Reads a binary SAB stream into the same records [_parse] builds from SAT.
  ///
  /// The tag-to-token mapping mirrors `sabToSat1`, including tag 14 as a
  /// prefix that joins the next identifier with a hyphen (`ellipse-` + `curve`).
  ({List<_Record> records, bool approximated})? _parseSab(Uint8List data) {
    if (data.length < 15) return null;
    final magic = String.fromCharCodes(Uint8List.sublistView(data, 0, 15));
    if (!magic.startsWith('ACIS BinaryFile')) return null;

    var at = 15;
    int rc() {
      if (at >= data.length) throw const FormatException('SAB overflow');
      return data[at++];
    }

    int rs() {
      final lo = rc();
      final hi = rc();
      return (hi << 8) | lo;
    }

    int rl() {
      final lo = rs();
      final hi = rs();
      return (hi << 16) | lo;
    }

    int rll() => rl() | (rl() << 32);

    final doubleBytes = ByteData(8);
    final floatBytes = ByteData(4);
    double rd() {
      for (var i = 0; i < 8; i++) {
        doubleBytes.setUint8(i, rc());
      }
      return doubleBytes.getFloat64(0, Endian.little);
    }

    double rlFloat() {
      floatBytes.setUint32(0, rl(), Endian.little);
      return floatBytes.getFloat32(0, Endian.little);
    }

    String taggedString() {
      rc();
      final length = rc();
      final end = at + length;
      if (end > data.length) {
        throw const FormatException('SAB string overflow');
      }
      final value = String.fromCharCodes(Uint8List.sublistView(data, at, end));
      at = end;
      return value;
    }

    try {
      rl(); // version
      rl(); // record count
      rl(); // entity count
      rl(); // history flag
      final product = taggedString();
      taggedString(); // acis version
      taggedString(); // date
      rc();
      rd();
      rc();
      rd();
      rc();
      rd();
      final approximated = product.contains('FanCAD_APPROX');

      final records = <_Record>[];
      _Record? current;
      var actRecord = '';
      var prefix = '';

      void addToken(String token, {String? actName}) {
        if (current == null) {
          current = _Record(token, _kindOf(token));
        } else {
          if (current!.kind == _Kind.coedge) {
            _applyCoedgeToken(current!, token);
          }
        }
        if (actName != null) actRecord = actName;
      }

      void addNumber(double value) {
        if (current == null) {
          addToken(value.toString());
        } else {
          current!.nums.add(value);
        }
      }

      void addRef(int value) {
        if (current == null) {
          addToken('\$$value');
        } else {
          current!.refs.add(value);
        }
      }

      void finish({required bool addEmpty}) {
        if (prefix.isNotEmpty) {
          addToken(prefix);
          prefix = '';
        }
        if (current != null || addEmpty) {
          records.add(current ?? _Record('', _Kind.other));
        }
        current = null;
      }

      while (at < data.length) {
        final tag = rc();
        switch (tag) {
          case 17: // end of record
            finish(addEmpty: true);
            break;
          case 13: // identifier
          case 7: // char length
          case 14: // subidentifier
            final length = rc();
            if (length == 0) {
              finish(addEmpty: false);
              return (records: records, approximated: approximated);
            }
            final end = at + length;
            if (end > data.length) return null;
            final value = String.fromCharCodes(
              Uint8List.sublistView(data, at, end),
            );
            at = end;
            if (tag == 14) {
              prefix += '$value-';
            } else {
              final token = prefix.isEmpty ? value : '$prefix$value';
              prefix = '';
              addToken(token, actName: tag == 13 ? value : null);
            }
            break;
          case 8:
            final length = rs();
            final end = at + length;
            if (end > data.length) return null;
            final value = String.fromCharCodes(
              Uint8List.sublistView(data, at, end),
            );
            at = end;
            final token = prefix.isEmpty ? value : '$prefix$value';
            prefix = '';
            addToken(token);
            break;
          case 9:
          case 18:
            final length = rl();
            final end = at + length;
            if (end > data.length) return null;
            final value = String.fromCharCodes(
              Uint8List.sublistView(data, at, end),
            );
            at = end;
            final token = prefix.isEmpty ? value : '$prefix$value';
            prefix = '';
            addToken(token);
            break;
          case 10:
          case 11:
            if (current != null && current!.kind == _Kind.coedge) {
              current!.reversed = tag == 10;
            } else {
              addToken(_booleanWord(actRecord, tag == 10));
            }
            break;
          case 15:
          case 16:
            break;
          case 2:
            addNumber(_signedValue(rc(), 8).toDouble());
            break;
          case 3:
            addNumber(_signedValue(rs(), 16).toDouble());
            break;
          case 4:
          case 12:
          case 21:
            addRef(_signedValue(rl(), 32));
            break;
          case 5:
            addNumber(rlFloat());
            break;
          case 6:
            addNumber(rd());
            break;
          case 19:
          case 20:
            addNumber(rd());
            addNumber(rd());
            addNumber(rd());
            break;
          case 23:
            addRef(rll());
            break;
          default:
            finish(addEmpty: false);
            return (records: records, approximated: approximated);
        }
        if (at >= data.length) break;
      }
      finish(addEmpty: false);
      return (records: records, approximated: approximated);
    } on FormatException {
      return null;
    }
  }

  static void _applyCoedgeToken(_Record record, String token) {
    switch (token) {
      case 'I':
      case 'T':
      case 'reversed':
      case 'true':
        record.reversed = true;
        break;
      case 'F':
      case 'forward':
      case 'false':
        record.reversed = false;
        break;
    }
  }

  static String _booleanWord(String record, bool value) {
    switch (record) {
      case 'edge':
      case 'spline':
      case 'meshsurf':
      case 'pcurve':
      case 'intcurve':
      case 'face':
        return value ? 'reversed' : 'forward';
      case 'sphere':
      case 'plane':
      case 'stripc':
      case 'torus':
        return value ? 'reverse_v' : 'forward_v';
      default:
        return value ? 'true' : 'false';
    }
  }

  static int _signedValue(int value, int bits) {
    final sign = 1 << (bits - 1);
    return (value & sign) != 0 ? value - (1 << bits) : value;
  }

  static _Kind _kindOf(String name) {
    switch (name) {
      case 'loop':
        return _Kind.loop;
      case 'coedge':
        return _Kind.coedge;
      case 'edge':
        return _Kind.edge;
      case 'vertex':
        return _Kind.vertex;
      case 'point':
        return _Kind.point;
      case 'ellipse-curve':
        return _Kind.ellipse;
      case 'straight-curve':
        return _Kind.straight;
      default:
        return _Kind.other;
    }
  }
}

enum _Kind { loop, coedge, edge, vertex, point, ellipse, straight, other }

class _Record {
  _Record(this.name, this.kind);

  final String name;
  final _Kind kind;
  final List<int> refs = [];
  final List<double> nums = [];
  bool reversed = false;
}

class _Edge {
  const _Edge({
    required this.start,
    required this.end,
    required this.curve,
    required this.startParam,
    required this.endParam,
  });

  final int start;
  final int end;
  final int curve;
  final double startParam;
  final double endParam;
}

class _ReadState {
  bool approximated = false;
}

/// Exposed for callers that need the loop grouping without an entity.
RegionGeometry? readAcisRegion(
  String sat, {
  Mat3? transform,
  double tolerance = 1e-6,
}) =>
    const AcisSatReader().read(sat, transform: transform, tolerance: tolerance);

/// Parses a binary SAB payload directly, without a SAT text intermediate.
RegionGeometry? readAcisSabRegion(
  Uint8List sab, {
  Mat3? transform,
  double tolerance = 1e-6,
}) => const AcisSatReader().readSab(
  sab,
  transform: transform,
  tolerance: tolerance,
);
