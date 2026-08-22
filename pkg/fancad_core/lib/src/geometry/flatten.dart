import 'dart:math' as math;
import 'dart:typed_data';

import 'vector.dart';

/// Curve discretization.
///
/// Every tessellation entry point takes a `tolerance` expressed in *model
/// units*: the maximum allowed deviation between the true curve and the
/// polyline that approximates it. The render pipeline derives it from the
/// current zoom (`tolerance = pixelTolerance / scale`) so that a curve is
/// re-flattened only when the viewer crosses an LOD bucket, not on every frame.
class Flatten {
  const Flatten._();

  /// Hard ceiling on segments per curve. Protects against absurd tolerances
  /// on drawings that contain arcs with astronomically large radii.
  static const int maxSegments = 4096;
  static const int minSegments = 4;

  /// Number of chords needed so that the sagitta of each chord stays within
  /// [tolerance] for a circular arc of the given [radius] and [sweep].
  static int arcSegmentCount(double radius, double sweep, double tolerance) {
    final r = radius.abs();
    final s = sweep.abs();
    if (r <= 0 || s <= 0) return 1;
    if (tolerance <= 0 || tolerance >= r) return minSegments;
    // sagitta = r * (1 - cos(theta / 2)) where theta is the per-chord angle.
    final ratio = 1 - tolerance / r;
    if (ratio <= -1 || ratio >= 1) return minSegments;
    final maxChordAngle = 2 * math.acos(ratio);
    if (maxChordAngle <= 0 || !maxChordAngle.isFinite) return maxSegments;
    final count = (s / maxChordAngle).ceil();
    return count.clamp(minSegments, maxSegments);
  }

  /// Discretizes a circular arc into an interleaved `[x, y, ...]` buffer.
  ///
  /// The sweep is taken counter-clockwise from [startAngle] to [endAngle],
  /// matching DWG arc semantics.
  static Float64List arc({
    required Vec2 center,
    required double radius,
    required double startAngle,
    required double endAngle,
    required double tolerance,
  }) {
    final sweep = angularSweep(startAngle, endAngle);
    final effectiveSweep = sweep == 0 ? math.pi * 2 : sweep;
    final segments = arcSegmentCount(radius, effectiveSweep, tolerance);
    final out = Float64List((segments + 1) * 2);
    final step = effectiveSweep / segments;
    for (var i = 0; i <= segments; i++) {
      final angle = startAngle + step * i;
      out[i * 2] = center.x + math.cos(angle) * radius;
      out[i * 2 + 1] = center.y + math.sin(angle) * radius;
    }
    return out;
  }

  /// Discretizes a full circle as a closed ring (first point not repeated).
  static Float64List circle({
    required Vec2 center,
    required double radius,
    required double tolerance,
  }) {
    final segments = arcSegmentCount(radius, math.pi * 2, tolerance);
    final out = Float64List(segments * 2);
    final step = math.pi * 2 / segments;
    for (var i = 0; i < segments; i++) {
      final angle = step * i;
      out[i * 2] = center.x + math.cos(angle) * radius;
      out[i * 2 + 1] = center.y + math.sin(angle) * radius;
    }
    return out;
  }

  /// Discretizes an elliptical arc.
  ///
  /// [major] is the major axis vector measured from [center]; [ratio] is the
  /// minor/major axis ratio; the angles are ellipse parameters (not true
  /// angles), which is how DWG stores them.
  static Float64List ellipse({
    required Vec2 center,
    required Vec2 major,
    required double ratio,
    required double startParam,
    required double endParam,
    required double tolerance,
  }) {
    final majorLength = major.length;
    final minorLength = majorLength * ratio;
    final sweep = angularSweep(startParam, endParam);
    final effectiveSweep = sweep == 0 ? math.pi * 2 : sweep;
    // Use the larger radius to bound the error conservatively.
    final segments = arcSegmentCount(
      math.max(majorLength, minorLength),
      effectiveSweep,
      tolerance,
    );
    final axisAngle = major.angle;
    final cosAxis = math.cos(axisAngle);
    final sinAxis = math.sin(axisAngle);
    final out = Float64List((segments + 1) * 2);
    final step = effectiveSweep / segments;
    for (var i = 0; i <= segments; i++) {
      final t = startParam + step * i;
      final localX = math.cos(t) * majorLength;
      final localY = math.sin(t) * minorLength;
      out[i * 2] = center.x + localX * cosAxis - localY * sinAxis;
      out[i * 2 + 1] = center.y + localX * sinAxis + localY * cosAxis;
    }
    return out;
  }

  /// The arc implied by a polyline `bulge` value between two vertices.
  ///
  /// A bulge is `tan(sweep / 4)`; positive means counter-clockwise. Returns
  /// null when the segment is straight.
  static BulgeArc? bulgeArc(Vec2 start, Vec2 end, double bulge) {
    if (bulge == 0 || !bulge.isFinite) return null;
    final chord = end - start;
    final chordLength = chord.length;
    if (chordLength == 0) return null;
    final sweep = 4 * math.atan(bulge);
    final radius = chordLength / 2 / math.sin(sweep.abs() / 2);
    if (!radius.isFinite || radius == 0) return null;
    // A positive bulge is the counter-clockwise (left-of-chord) included
    // arc. The signed apothem puts the centre on that side, and flips
    // across the chord when |sweep| exceeds π.
    final mid = start.lerp(end, 0.5);
    final normal = chord.perpendicular.normalized();
    final center = mid + normal * (radius * math.cos(sweep / 2));
    final startAngle = (start - center).angle;
    final endAngle = (end - center).angle;
    return BulgeArc(
      center: center,
      radius: radius.abs(),
      startAngle: sweep > 0 ? startAngle : endAngle,
      endAngle: sweep > 0 ? endAngle : startAngle,
      counterClockwise: sweep > 0,
    );
  }

  /// Expands a polyline with per-vertex bulges into a plain point buffer.
  ///
  /// [vertices] is interleaved `[x, y, bulge, ...]`, which is exactly how
  /// LWPOLYLINE data arrives from the DWG importer.
  static Float64List polylineWithBulges({
    required Float64List vertices,
    required bool closed,
    required double tolerance,
  }) {
    final count = vertices.length ~/ 3;
    if (count == 0) return Float64List(0);
    if (count == 1) {
      return Float64List.fromList([vertices[0], vertices[1]]);
    }
    final out = <double>[];
    final segmentCount = closed ? count : count - 1;
    for (var i = 0; i < segmentCount; i++) {
      final j = (i + 1) % count;
      final start = Vec2(vertices[i * 3], vertices[i * 3 + 1]);
      final end = Vec2(vertices[j * 3], vertices[j * 3 + 1]);
      final bulge = vertices[i * 3 + 2];
      if (out.isEmpty) {
        out.add(start.x);
        out.add(start.y);
      }
      final arcDef = bulgeArc(start, end, bulge);
      if (arcDef == null) {
        out.add(end.x);
        out.add(end.y);
        continue;
      }
      final pts = arc(
        center: arcDef.center,
        radius: arcDef.radius,
        startAngle: arcDef.startAngle,
        endAngle: arcDef.endAngle,
        tolerance: tolerance,
      );
      // The arc buffer always runs counter-clockwise; walk it backwards when
      // the bulge is negative so the traversal direction stays consistent.
      if (arcDef.counterClockwise) {
        for (var k = 1; k < pts.length ~/ 2; k++) {
          out.add(pts[k * 2]);
          out.add(pts[k * 2 + 1]);
        }
      } else {
        for (var k = (pts.length ~/ 2) - 2; k >= 0; k--) {
          out.add(pts[k * 2]);
          out.add(pts[k * 2 + 1]);
        }
      }
    }
    return Float64List.fromList(out);
  }

  /// Evaluates a NURBS curve with the de Boor algorithm and samples it.
  ///
  /// [controlPoints] is interleaved `[x, y, ...]`, [weights] may be empty for
  /// a non-rational curve, and [knots] must have
  /// `controlPointCount + degree + 1` entries. Falls back to the control
  /// polygon when the knot vector is inconsistent, which real-world files do
  /// occasionally contain.
  static Float64List bspline({
    required Float64List controlPoints,
    required List<double> knots,
    required int degree,
    List<double> weights = const [],
    required double tolerance,
    bool closed = false,
  }) {
    final n = controlPoints.length ~/ 2;
    if (n == 0) return Float64List(0);
    if (n <= degree || degree < 1 || knots.length != n + degree + 1) {
      return Float64List.fromList(controlPoints);
    }
    // Sample density scales with the control polygon length so that long,
    // wiggly splines get proportionally more samples.
    var polygonLength = 0.0;
    for (var i = 1; i < n; i++) {
      final dx = controlPoints[i * 2] - controlPoints[(i - 1) * 2];
      final dy = controlPoints[i * 2 + 1] - controlPoints[(i - 1) * 2 + 1];
      polygonLength += math.sqrt(dx * dx + dy * dy);
    }
    final samples = tolerance <= 0
        ? maxSegments
        : (polygonLength / math.max(tolerance * 8, 1e-9))
              .ceil()
              .clamp(n * 4, maxSegments);
    final tMin = knots[degree];
    final tMax = knots[n];
    if (!(tMax > tMin)) return Float64List.fromList(controlPoints);

    final out = Float64List((samples + 1) * 2);
    final rational = weights.length == n;
    for (var s = 0; s <= samples; s++) {
      var t = tMin + (tMax - tMin) * s / samples;
      if (s == samples) t = tMax - 1e-12;
      final span = _findSpan(knots, n, degree, t);
      final basis = _basisFunctions(knots, span, degree, t);
      var x = 0.0, y = 0.0, w = 0.0;
      for (var i = 0; i <= degree; i++) {
        final index = span - degree + i;
        final weight = rational ? weights[index] : 1.0;
        final influence = basis[i] * weight;
        x += controlPoints[index * 2] * influence;
        y += controlPoints[index * 2 + 1] * influence;
        w += influence;
      }
      if (w != 0) {
        x /= w;
        y /= w;
      }
      out[s * 2] = x;
      out[s * 2 + 1] = y;
    }
    return out;
  }

  static int _findSpan(List<double> knots, int n, int degree, double t) {
    if (t >= knots[n]) return n - 1;
    var low = degree;
    var high = n;
    var mid = (low + high) ~/ 2;
    while (t < knots[mid] || t >= knots[mid + 1]) {
      if (t < knots[mid]) {
        high = mid;
      } else {
        low = mid;
      }
      mid = (low + high) ~/ 2;
      if (mid == low) break;
    }
    return mid;
  }

  static List<double> _basisFunctions(
    List<double> knots,
    int span,
    int degree,
    double t,
  ) {
    final basis = List<double>.filled(degree + 1, 0);
    final left = List<double>.filled(degree + 1, 0);
    final right = List<double>.filled(degree + 1, 0);
    basis[0] = 1;
    for (var j = 1; j <= degree; j++) {
      left[j] = t - knots[span + 1 - j];
      right[j] = knots[span + j] - t;
      var saved = 0.0;
      for (var r = 0; r < j; r++) {
        final denominator = right[r + 1] + left[j - r];
        final temp = denominator == 0 ? 0.0 : basis[r] / denominator;
        basis[r] = saved + right[r + 1] * temp;
        saved = left[j - r] * temp;
      }
      basis[j] = saved;
    }
    return basis;
  }
}

/// The circular arc that a polyline bulge expands to.
class BulgeArc {
  const BulgeArc({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
    required this.counterClockwise,
  });

  final Vec2 center;
  final double radius;
  final double startAngle;
  final double endAngle;
  final bool counterClockwise;
}
