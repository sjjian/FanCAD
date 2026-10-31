import '../document/entity.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';

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
    if (records.isEmpty) return null;
    final loops = <RegionLoop>[];
    final state = _ReadState()..approximated = _headerApproximated(sat);
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
          if (c == 0x49 || c == 0x46) {
            if (i + 1 >= text.length ||
                _isSpace(text.codeUnitAt(i + 1)) ||
                text.codeUnitAt(i + 1) == 0x23) {
              record.reversed = c == 0x49;
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
