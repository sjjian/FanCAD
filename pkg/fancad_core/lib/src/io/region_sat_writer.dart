import 'dart:math' as math;

import '../document/entity.dart';
import '../geometry/vector.dart';

/// Writes a planar REGION as ACIS SAT v1 text.
///
/// This is the lossy path used after an edit or when the original ACIS blob is
/// unavailable. Lines and orthogonal conics stay analytic; sheared conics and
/// splines are flattened to short line segments.
class RegionSatWriter {
  const RegionSatWriter();

  /// Writes [geometry], and reports whether the stored form is approximate.
  ///
  /// Splines and sheared conics cannot be represented by this SAT subset, so
  /// they are flattened and [RegionSatWriteResult.approximated] is true.
  RegionSatWriteResult writeResult(
    RegionGeometry geometry, {
    double tolerance = 0.01,
  }) {
    final approximated = geometry.approximated || _hasFlattenedCurves(geometry);
    final product = approximated ? 'FanCAD_APPROX' : 'FanCAD';
    final out = StringBuffer()
      ..writeln('700 0 1 0 ')
      ..writeln('8 $product 8 ACIS 1.7.0 24 Thu Jan 01 00:00:00 1998 ')
      ..writeln('18 1e-6 1e-10 ');
    var record = 0;
    var wrote = false;
    for (final component in geometry.components) {
      final loops = [component.outer, ...component.holes];
      final plans = <_LoopPlan>[];
      var cursor = record + 4;
      for (final loop in loops) {
        final segments = _segments(loop, tolerance);
        if (segments.length < 2) continue;
        final n = segments.length;
        final curves = segments.where((segment) => segment.arc != null).length;
        plans.add(
          _LoopPlan(
            segments: segments,
            loopRecord: cursor,
            co0: cursor + 1,
            ed0: cursor + 1 + n,
            v0: cursor + 1 + n * 2,
            p0: cursor + 1 + n * 3,
            curve0: cursor + 1 + n * 3 + n,
          ),
        );
        cursor += 1 + n * 4 + curves;
      }
      if (plans.isEmpty) continue;
      final body = record;
      final lump = body + 1;
      final shell = body + 2;
      final face = body + 3;
      out
        ..writeln('body \$-1 \$-1 \$-1 \$$lump \$-1 \$-1 #')
        ..writeln('lump \$-1 \$-1 \$-1 \$-1 \$$shell \$$body #')
        ..writeln('shell \$-1 \$-1 \$-1 \$-1 \$-1 \$$face \$-1 \$$lump #')
        ..writeln(
          'face \$-1 \$-1 \$-1 \$-1 \$${plans.first.loopRecord} \$$shell '
          '\$-1 \$-1 forward single #',
        );
      for (var i = 0; i < plans.length; i++) {
        final plan = plans[i];
        final next = i + 1 < plans.length ? plans[i + 1].loopRecord : -1;
        out.writeln('loop \$-1 \$-1 \$-1 \$$next \$${plan.co0} \$$face #');
        _writePlan(out, plan, face);
      }
      record = cursor;
      wrote = true;
    }
    if (!wrote) {
      return RegionSatWriteResult(null, approximated: approximated);
    }
    out.writeln('End-of-ACIS-data ');
    return RegionSatWriteResult(out.toString(), approximated: approximated);
  }

  String? write(RegionGeometry geometry, {double tolerance = 0.01}) =>
      writeResult(geometry, tolerance: tolerance).text;

  /// Marks an existing SAT/SAB text as an approximate REGION.
  ///
  /// The ACIS product field on the second header line is informational, so
  /// adding the marker does not change the geometry or break other readers.
  static String markApproximated(String sat) {
    final first = sat.indexOf('\n');
    if (first < 0) return sat;
    final second = sat.indexOf('\n', first + 1);
    if (second < 0) return sat;
    final line = sat.substring(first + 1, second);
    if (line.contains('FanCAD_APPROX')) return sat;
    final marked = line.replaceFirst(
      RegExp(r'^(\s*8\s+)\S+'),
      r'$1FanCAD_APPROX',
    );
    if (marked == line) return sat;
    return sat.substring(0, first + 1) + marked + sat.substring(second);
  }

  bool _hasFlattenedCurves(RegionGeometry geometry) {
    for (final component in geometry.components) {
      for (final loop in [component.outer, ...component.holes]) {
        for (final curve in loop.curves) {
          switch (curve) {
            case RegionSpline():
              return true;
            case RegionConicArc():
              if (_canonicalCurve(curve) == null) return true;
            case RegionLine():
            case RegionPolyline():
              break;
          }
        }
      }
    }
    return false;
  }

  void _writePlan(StringBuffer out, _LoopPlan plan, int face) {
    final segments = plan.segments;
    final n = segments.length;
    for (var i = 0; i < n; i++) {
      final next = plan.co0 + ((i + 1) % n);
      out.writeln(
        'coedge \$-1 \$-1 \$-1 \$$next \$-1 \$-1 \$${plan.ed0 + i} forward #',
      );
    }
    var curveIndex = plan.curve0;
    final edgeCurve = <int>[];
    for (final segment in segments) {
      edgeCurve.add(segment.arc != null ? curveIndex++ : -1);
    }
    for (var i = 0; i < n; i++) {
      final segment = segments[i];
      final start = plan.v0 + i;
      final end = plan.v0 + ((i + 1) % n);
      final curve = edgeCurve[i] >= 0 ? edgeCurve[i] : plan.co0 + i;
      final a0 = segment.arc == null ? 0.0 : (_canonical(segment)?.start ?? 0);
      final a1 = segment.arc == null ? 1.0 : (_canonical(segment)?.end ?? 0);
      out.writeln(
        'edge \$-1 \$-1 \$${plan.co0 + i} \$$start \$$end \$-1 \$$curve '
        '${_fmt(a0)} ${_fmt(a1)} #',
      );
    }
    for (var i = 0; i < n; i++) {
      out.writeln('vertex \$-1 \$-1 \$-1 \$${plan.p0 + i} #');
    }
    for (var i = 0; i < n; i++) {
      final point = segments[i].start;
      out.writeln('point \$-1 \$-1 ${_fmt(point.x)} ${_fmt(point.y)} 0 #');
    }
    for (final segment in segments) {
      final arc = segment.arc;
      if (arc == null) continue;
      final canonical = _canonical(segment);
      if (canonical == null) continue;
      out.writeln(
        'ellipse-curve \$-1 \$-1 ${_fmt(arc.center.x)} ${_fmt(arc.center.y)} 0 '
        '0 0 1 ${_fmt(canonical.major.x)} ${_fmt(canonical.major.y)} 0 '
        '${_fmt(canonical.ratio)} ${_fmt(canonical.start)} ${_fmt(canonical.end)} #',
      );
    }
  }

  List<_SatSegment> _segments(RegionLoop loop, double tolerance) {
    final out = <_SatSegment>[];
    for (final curve in loop.curves) {
      switch (curve) {
        case RegionLine(:final start, :final end):
          out.add(_SatSegment(start, end));
        case RegionConicArc():
          final canonical = _canonicalCurve(curve);
          if (canonical == null) {
            final points = curve.samplePoints(tolerance);
            for (var i = 1; i < points.length; i++) {
              out.add(_SatSegment(points[i - 1], points[i]));
            }
          } else if (curve.isClosed) {
            final half = curve.sweep / 2;
            out
              ..add(
                _SatSegment(
                  curve.pointAt(curve.startParameter),
                  curve.pointAt(curve.startParameter + half),
                  arc: curve,
                  startParam: curve.startParameter,
                  endParam: curve.startParameter + half,
                ),
              )
              ..add(
                _SatSegment(
                  curve.pointAt(curve.startParameter + half),
                  curve.pointAt(curve.startParameter + curve.sweep),
                  arc: curve,
                  startParam: curve.startParameter + half,
                  endParam: curve.startParameter + curve.sweep,
                ),
              );
          } else {
            out.add(
              _SatSegment(
                curve.start,
                curve.end,
                arc: curve,
                startParam: curve.startParameter,
                endParam: curve.startParameter + curve.sweep,
              ),
            );
          }
        case RegionPolyline(:final points):
          for (var i = 1; i < points.length ~/ 2; i++) {
            out.add(
              _SatSegment(
                Vec2(points[(i - 1) * 2], points[(i - 1) * 2 + 1]),
                Vec2(points[i * 2], points[i * 2 + 1]),
              ),
            );
          }
        case RegionSpline():
          final points = curve.samplePoints(tolerance);
          for (var i = 1; i < points.length; i++) {
            out.add(_SatSegment(points[i - 1], points[i]));
          }
      }
    }
    return out;
  }

  _Canonical? _canonicalCurve(RegionConicArc arc) {
    final uLength = arc.u.length;
    final vLength = arc.v.length;
    if (uLength < 1e-12 || vLength < 1e-12) return null;
    if (arc.u.dot(arc.v).abs() > 1e-6 * uLength * vLength) return null;
    if (uLength >= vLength) {
      return _Canonical(
        major: arc.u,
        ratio: vLength / uLength,
        start: arc.startParameter,
        end: arc.startParameter + arc.sweep,
      );
    }
    return _Canonical(
      major: arc.v,
      ratio: uLength / vLength,
      start: math.pi / 2 - arc.startParameter,
      end: math.pi / 2 - (arc.startParameter + arc.sweep),
    );
  }

  _Canonical? _canonical(_SatSegment segment) {
    final arc = segment.arc;
    if (arc == null) return null;
    final base = _canonicalCurve(arc);
    if (base == null) return null;
    // The segment may be one half of a full ellipse. Recover its parameters
    // by mapping the original parameter interval through the same swap.
    final a0 = segment.startParam;
    final a1 = segment.endParam;
    final swapped = base.major != arc.u;
    return _Canonical(
      major: base.major,
      ratio: base.ratio,
      start: swapped ? math.pi / 2 - a0 : a0,
      end: swapped ? math.pi / 2 - a1 : a1,
    );
  }

  static String _fmt(double value) {
    if (!value.isFinite) return '0';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class RegionSatWriteResult {
  const RegionSatWriteResult(this.text, {required this.approximated});

  final String? text;
  final bool approximated;
}

class _LoopPlan {
  const _LoopPlan({
    required this.segments,
    required this.loopRecord,
    required this.co0,
    required this.ed0,
    required this.v0,
    required this.p0,
    required this.curve0,
  });

  final List<_SatSegment> segments;
  final int loopRecord;
  final int co0;
  final int ed0;
  final int v0;
  final int p0;
  final int curve0;
}

class _SatSegment {
  const _SatSegment(
    this.start,
    this.end, {
    this.arc,
    this.startParam = 0,
    this.endParam = 0,
  });

  final Vec2 start;
  final Vec2 end;
  final RegionConicArc? arc;
  final double startParam;
  final double endParam;
}

class _Canonical {
  const _Canonical({
    required this.major,
    required this.ratio,
    required this.start,
    required this.end,
  });

  final Vec2 major;
  final double ratio;
  final double start;
  final double end;
}
