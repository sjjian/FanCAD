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
    // Signed radius: cos(sweep / 2) is even, so an abs() radius always
    // sat on the left of the chord. A negative bulge then tessellated
    // the complementary arc — the other half of the same circle.
    final radius = chordLength / 2 / math.sin(sweep / 2);
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

  /// Basis weights `N_{0,p}(t) … N_{n-1,p}(t)` for one parameter.
  ///
  /// Used to invert a clamped spline so fit points become control points.
  static List<double> bsplineBasis({
    required List<double> knots,
    required int count,
    required int degree,
    required double t,
  }) {
    final row = List<double>.filled(count, 0);
    if (count <= degree || degree < 1 || knots.length != count + degree + 1) {
      return row;
    }
    final tMin = knots[degree];
    final tMax = knots[count];
    if (!(tMax > tMin)) return row;
    var u = t;
    if (u >= tMax) u = tMax - 1e-12;
    if (u < tMin) u = tMin;
    final span = _findSpan(knots, count, degree, u);
    final basis = _basisFunctions(knots, span, degree, u);
    for (var i = 0; i <= degree; i++) {
      final index = span - degree + i;
      if (index >= 0 && index < count) row[index] = basis[i];
    }
    return row;
  }

  /// The curve point at parameter [t].
  static Vec2? bsplineEvaluate({
    required Float64List controlPoints,
    required List<double> knots,
    required int degree,
    required double t,
    List<double> weights = const [],
  }) {
    final n = controlPoints.length ~/ 2;
    final row = bsplineBasis(
      knots: knots,
      count: n,
      degree: degree,
      t: t,
    );
    if (row.every((w) => w == 0)) return null;
    var x = 0.0, y = 0.0, w = 0.0;
    final rational = weights.length == n;
    for (var i = 0; i < n; i++) {
      final weight = (rational ? weights[i] : 1.0) * row[i];
      x += controlPoints[i * 2] * weight;
      y += controlPoints[i * 2 + 1] * weight;
      w += weight;
    }
    if (w == 0) return null;
    return Vec2(x / w, y / w);
  }

  /// Control polygon that interpolates [points].
  ///
  /// Chord-length parameters and Piegl/Tiller averaging knots keep the
  /// interpolation matrix well-conditioned, so the curve actually passes
  /// through every click. Returns null when there are fewer than two points
  /// or the linear system is singular.
  static FitSpline? interpolateFit(List<Vec2> points) {
    if (points.length < 2) return null;
    final degree = math.min(3, points.length - 1);
    final params = _chordParams(points);
    final knots = _averagingKnots(params, degree);
    final matrix = [
      for (var i = 0; i < points.length; i++)
        bsplineBasis(
          knots: knots,
          count: points.length,
          degree: degree,
          t: params[i],
        ),
    ];
    final controls = _solveLinear(matrix, points);
    if (controls == null) return null;
    final controlPoints = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      controlPoints[i * 2] = controls[i].x;
      controlPoints[i * 2 + 1] = controls[i].y;
    }
    return FitSpline(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
    );
  }

  static List<double> _chordParams(List<Vec2> points) {
    final n = points.length;
    final params = List<double>.filled(n, 0);
    var total = 0.0;
    final chord = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      chord[i] = math.max(points[i].distanceTo(points[i - 1]), 1e-12);
      total += chord[i];
    }
    for (var i = 1; i < n; i++) {
      params[i] = params[i - 1] + chord[i] / total;
    }
    params[n - 1] = 1;
    return params;
  }

  /// Piegl/Tiller averaging knots so interpolation parameters sit inside
  /// spans rather than on uniform knots that miss uneven clicks.
  static List<double> _averagingKnots(List<double> params, int degree) {
    final n = params.length;
    final knots = List<double>.filled(n + degree + 1, 0);
    for (var i = 0; i <= degree; i++) {
      knots[i] = 0;
      knots[knots.length - 1 - i] = 1;
    }
    for (var j = 1; j <= n - degree - 1; j++) {
      var sum = 0.0;
      for (var i = j; i <= j + degree - 1; i++) {
        sum += params[i];
      }
      knots[j + degree] = sum / degree;
    }
    return knots;
  }

  /// Gauss-Jordan with two right-hand sides (x and y of each [rhs] point).
  static List<Vec2>? _solveLinear(List<List<double>> matrix, List<Vec2> rhs) {
    final n = rhs.length;
    if (matrix.length != n) return null;
    final work = List.generate(n, (i) {
      if (matrix[i].length != n) return <double>[];
      return [...matrix[i], rhs[i].x, rhs[i].y];
    });
    if (work.any((row) => row.length != n + 2)) return null;
    for (var k = 0; k < n; k++) {
      var pivot = k;
      var best = work[k][k].abs();
      for (var i = k + 1; i < n; i++) {
        final value = work[i][k].abs();
        if (value > best) {
          best = value;
          pivot = i;
        }
      }
      if (best < 1e-12) return null;
      if (pivot != k) {
        final swap = work[k];
        work[k] = work[pivot];
        work[pivot] = swap;
      }
      final diag = work[k][k];
      for (var j = k; j < n + 2; j++) {
        work[k][j] /= diag;
      }
      for (var i = 0; i < n; i++) {
        if (i == k) continue;
        final factor = work[i][k];
        if (factor.abs() < 1e-15) continue;
        for (var j = k; j < n + 2; j++) {
          work[i][j] -= factor * work[k][j];
        }
      }
    }
    return [for (var i = 0; i < n; i++) Vec2(work[i][n], work[i][n + 1])];
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

  /// Offsets a flattened centreline by half of [width] on each side.
  ///
  /// A donut is a closed polyline with [constantWidth]; without this fill it
  /// draws as a thin centreline and looks empty. Open strokes become one ring
  /// (left side, then the right side reversed). Closed strokes become an
  /// outer ring plus an inner hole so the middle stays clear.
  static WideStroke? wideStroke(
    Float64List xy,
    double width, {
    required bool closed,
  }) {
    final half = width.abs() / 2;
    if (half < 1e-12 || xy.length < 4) return null;
    final pts = <Vec2>[];
    for (var i = 0; i + 1 < xy.length; i += 2) {
      final p = Vec2(xy[i], xy[i + 1]);
      if (pts.isEmpty || pts.last.distanceSquaredTo(p) > 1e-24) {
        pts.add(p);
      }
    }
    if (closed &&
        pts.length >= 2 &&
        pts.first.distanceSquaredTo(pts.last) <= 1e-24) {
      pts.removeLast();
    }
    if (pts.length < 2) return null;

    final left = _offsetPoly(pts, half, closed);
    final right = _offsetPoly(pts, -half, closed);
    if (left.length < 2 || right.length < 2) return null;

    if (!closed) {
      return WideStroke(
        outer: _xyOf([...left, ...right.reversed]),
      );
    }
    final leftArea = _signedArea(left);
    final rightArea = _signedArea(right);
    if (leftArea.abs() >= rightArea.abs()) {
      return WideStroke(outer: _xyOf(left), hole: _xyOf(right));
    }
    return WideStroke(outer: _xyOf(right), hole: _xyOf(left));
  }

  static List<Vec2> _offsetPoly(List<Vec2> pts, double offset, bool closed) {
    final out = <Vec2>[];
    final count = pts.length;
    for (var i = 0; i < count; i++) {
      final p = pts[i];
      final prev = closed
          ? pts[(i - 1 + count) % count]
          : (i == 0 ? null : pts[i - 1]);
      final next = closed
          ? pts[(i + 1) % count]
          : (i == count - 1 ? null : pts[i + 1]);
      if (prev == null) {
        final dir = (next! - p).normalized();
        if (dir.lengthSquared < 1e-24) continue;
        out.add(p + dir.perpendicular * offset);
        continue;
      }
      if (next == null) {
        final dir = (p - prev).normalized();
        if (dir.lengthSquared < 1e-24) continue;
        out.add(p + dir.perpendicular * offset);
        continue;
      }
      final incoming = p - prev;
      final outgoing = next - p;
      final lenIn = incoming.length;
      final lenOut = outgoing.length;
      if (lenIn < 1e-12 || lenOut < 1e-12) continue;
      final nIn = (incoming / lenIn).perpendicular;
      final nOut = (outgoing / lenOut).perpendicular;
      final miter = nIn + nOut;
      final miterLen = miter.length;
      if (miterLen < 1e-9) {
        out.add(p + nIn * offset);
        continue;
      }
      final unit = miter / miterLen;
      final cosine = unit.dot(nIn);
      if (cosine.abs() < 1e-6) {
        out.add(p + nIn * offset);
        continue;
      }
      var scale = offset / cosine;
      final limit = offset.abs() * 4;
      if (scale.abs() > limit) scale = scale.sign * limit;
      out.add(p + unit * scale);
    }
    return out;
  }

  static double _signedArea(List<Vec2> ring) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  static Float64List _xyOf(List<Vec2> pts) {
    final xy = Float64List(pts.length * 2);
    for (var i = 0; i < pts.length; i++) {
      xy[i * 2] = pts[i].x;
      xy[i * 2 + 1] = pts[i].y;
    }
    return xy;
  }
}

/// A constant-width stroke: [outer] is the filled ring, [hole] the inner
/// island of a closed donut-like polyline.
class WideStroke {
  const WideStroke({required this.outer, this.hole});

  final Float64List outer;
  final Float64List? hole;
}

/// Control polygon recovered from interpolating fit points.
class FitSpline {
  const FitSpline({
    required this.controlPoints,
    required this.knots,
    required this.degree,
  });

  final Float64List controlPoints;
  final List<double> knots;
  final int degree;
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
