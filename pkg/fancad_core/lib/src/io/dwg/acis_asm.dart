import 'dart:math' as math;

import '../../geometry/vector.dart';
import '../../model/entity/entity.dart';

/// Reads the ASM 223 record dialect used by current AutoCAD REGIONs.
///
/// The older SAT1 parser in `acis_sat.dart` cannot read this: ASM records are
/// `$-1 $next $prev ...` reference lists. The indices used here were derived
/// from an `example_2000.dwg` REGION:
///   loop   refs[2] = first coedge
///   coedge refs[1] = next coedge, refs[4] = edge
///   edge   refs[1] = start vertex, refs[2] = end vertex, refs[4] = curve
///   vertex refs.last = point
List<RegionLoop>? readAcisAsmLoopText(String sat) {
  if (sat.isEmpty) return null;
  final lines = sat.split('\n');
  if (lines.length < 4) return null;
  final body = lines.skip(3).join('\n');
  final records = <_Rec>[];
  for (final chunk in body.split('#')) {
    final rec = _Rec.parse(chunk);
    if (rec != null && rec.kind.isNotEmpty) records.add(rec);
  }
  if (records.isEmpty) return null;

  final loops = <RegionLoop>[];
  final used = List<bool>.filled(records.length, false);
  for (var i = 0; i < records.length; i++) {
    final loop = records[i];
    if (loop.kind != 'L') continue;
    var start = -1;
    for (final ref in loop.refs) {
      if (ref >= 0 && ref < records.length && records[ref].kind == 'C') {
        start = ref;
        break;
      }
    }
    if (start < 0 || used[start]) continue;

    final points = <Vec2>[];
    var current = start;
    var steps = 0;
    while (steps++ < records.length) {
      final coedge = records[current];
      if (coedge.kind != 'C' || used[current]) break;
      used[current] = true;
      final edge = coedge.refs.length > 4 ? coedge.refs[4] : -1;
      _emitEdge(points, records, edge, coedge.reversed);
      final next = coedge.refs.length > 1 ? coedge.refs[1] : -1;
      if (next == start) break;
      if (next < 0 || next >= records.length) break;
      current = next;
    }
    _finishLoop(points, loops);
  }

  if (loops.isEmpty) {
    for (var i = 0; i < records.length; i++) {
      if (records[i].kind != 'E') continue;
      final points = <Vec2>[];
      _emitEdge(points, records, i, false);
      _finishLoop(points, loops);
    }
  }
  return loops.isEmpty ? null : loops;
}

void _finishLoop(List<Vec2> points, List<RegionLoop> loops) {
  if (points.length < 2) return;
  final first = points.first;
  if (first.x != points.last.x || first.y != points.last.y) {
    points.add(first);
  }
  final curves = <RegionCurve>[];
  for (var i = 0; i + 1 < points.length; i++) {
    if (points[i].x == points[i + 1].x && points[i].y == points[i + 1].y) {
      continue;
    }
    curves.add(RegionLine(start: points[i], end: points[i + 1]));
  }
  if (curves.length >= 2) loops.add(RegionLoop(curves));
}

void _emitEdge(
  List<Vec2> out,
  List<_Rec> records,
  int edgeIndex,
  bool reversed,
) {
  if (edgeIndex < 0 || edgeIndex >= records.length) return;
  final edge = records[edgeIndex];
  if (edge.kind != 'E' || edge.refs.length < 5) return;
  var startVertex = edge.refs[1];
  var endVertex = edge.refs[2];
  if (reversed) {
    final swap = startVertex;
    startVertex = endVertex;
    endVertex = swap;
  }
  final start = _vertexXY(records, startVertex);
  final end = _vertexXY(records, endVertex);
  if (start == null || end == null) return;
  _push(out, start);

  final curveIndex = edge.refs[4];
  if (curveIndex >= 0 &&
      curveIndex < records.length &&
      records[curveIndex].kind == 'O' &&
      records[curveIndex].nums.length >= 10) {
    final c = records[curveIndex].nums;
    final cx = c[0], cy = c[1];
    final nx = c[3], ny = c[4], nz = c[5];
    final mx = c[6], my = c[7], mz = c[8];
    final ratio = c[9];
    var bx = ny * mz - nz * my;
    var by = nz * mx - nx * mz;
    final bz = nx * my - ny * mx;
    final mlen = math.sqrt(mx * mx + my * my + mz * mz);
    final clen = math.sqrt(bx * bx + by * by + bz * bz);
    final a0 = edge.nums.isNotEmpty ? edge.nums[0] : 0.0;
    final a1 = edge.nums.length > 1 ? edge.nums[1] : math.pi * 2;
    final sweep = a1 - a0;
    if (clen > 0) {
      final scale = (mlen * ratio) / clen;
      bx *= scale;
      by *= scale;
    }
    var steps = (sweep.abs() / 0.39269908169872414).ceil();
    if (steps < 4) steps = 4;
    if (steps > 64) steps = 64;
    for (var i = 1; i < steps; i++) {
      final t = a0 + sweep * i / steps;
      _push(
        out,
        Vec2(
          cx + mx * math.cos(t) + bx * math.sin(t),
          cy + my * math.cos(t) + by * math.sin(t),
        ),
      );
    }
  }
  _push(out, end);
}

void _push(List<Vec2> out, Vec2 point) {
  if (out.isNotEmpty) {
    final last = out.last;
    if ((last - point).lengthSquared < 1e-20) return;
  }
  out.add(point);
}

Vec2? _vertexXY(List<_Rec> records, int vertexIndex) {
  if (vertexIndex < 0 || vertexIndex >= records.length) return null;
  final vertex = records[vertexIndex];
  if (vertex.kind != 'V' || vertex.refs.isEmpty) return null;
  final pointIndex = vertex.refs.last;
  if (pointIndex < 0 || pointIndex >= records.length) return null;
  final point = records[pointIndex];
  if (point.kind != 'P' || point.nums.length < 3) return null;
  return Vec2(
    point.nums[point.nums.length - 3],
    point.nums[point.nums.length - 2],
  );
}

final class _Rec {
  _Rec(this.kind, this.refs, this.nums, this.reversed);

  final String kind;
  final List<int> refs;
  final List<double> nums;
  final bool reversed;

  static _Rec? parse(String chunk) {
    final text = chunk.trim();
    if (text.isEmpty) return null;
    final tokens = text.split(RegExp(r'\s+'));
    final name = tokens.first.toLowerCase();
    final kind = switch (name) {
      'loop' => 'L',
      'coedge' => 'C',
      'edge' => 'E',
      'vertex' => 'V',
      'point' => 'P',
      'ellipse' => 'O',
      'straight-curve' => 'S',
      'transform' => 'T',
      _ => name.isEmpty ? '' : name[0].toUpperCase(),
    };
    final refs = <int>[];
    final nums = <double>[];
    var reversed = false;
    for (final token in tokens.skip(1)) {
      if (token.startsWith(r'$')) {
        final value = int.tryParse(token.substring(1));
        if (value != null) refs.add(value);
      } else if (token == 'I' || token == 'reversed') {
        reversed = true;
      } else if (token == 'F' || token == 'forward') {
        reversed = false;
      } else {
        final value = double.tryParse(token);
        if (value != null) nums.add(value);
      }
    }
    return _Rec(kind, refs, nums, reversed);
  }
}
