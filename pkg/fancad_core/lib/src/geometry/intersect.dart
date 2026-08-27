import 'dart:math' as math;
import 'dart:typed_data';

import 'flatten.dart';
import 'vector.dart';

/// Analytic intersection and projection helpers.
///
/// These back object snapping (intersection / perpendicular / nearest) and the
/// trim / extend / fillet family of editing commands, so they operate on exact
/// primitives rather than on the flattened render geometry.
class Intersect {
  const Intersect._();

  static const double epsilon = 1e-10;

  /// Intersection of two infinite lines. Null when parallel.
  static Vec2? lineLine(Vec2 p1, Vec2 p2, Vec2 p3, Vec2 p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denominator = d1.cross(d2);
    if (denominator.abs() < epsilon) return null;
    final t = (p3 - p1).cross(d2) / denominator;
    return p1 + d1 * t;
  }

  /// Intersection of two finite segments, honouring both parameter ranges.
  static Vec2? segmentSegment(Vec2 p1, Vec2 p2, Vec2 p3, Vec2 p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denominator = d1.cross(d2);
    if (denominator.abs() < epsilon) return null;
    final delta = p3 - p1;
    final t = delta.cross(d2) / denominator;
    final u = delta.cross(d1) / denominator;
    if (t < -epsilon || t > 1 + epsilon || u < -epsilon || u > 1 + epsilon) {
      return null;
    }
    return p1 + d1 * t;
  }

  /// Intersections of an infinite line with a circle (0, 1 or 2 points).
  static List<Vec2> lineCircle(
    Vec2 p1,
    Vec2 p2,
    Vec2 center,
    double radius,
  ) {
    final d = p2 - p1;
    final lengthSquared = d.lengthSquared;
    if (lengthSquared < epsilon) return const [];
    final delta = p1 - center;
    final b = 2 * d.dot(delta);
    final c = delta.lengthSquared - radius * radius;
    final discriminant = b * b - 4 * lengthSquared * c;
    if (discriminant < 0) return const [];
    if (discriminant.abs() < epsilon) {
      return [p1 + d * (-b / (2 * lengthSquared))];
    }
    final root = math.sqrt(discriminant);
    return [
      p1 + d * ((-b - root) / (2 * lengthSquared)),
      p1 + d * ((-b + root) / (2 * lengthSquared)),
    ];
  }

  /// Intersections of two circles.
  static List<Vec2> circleCircle(
    Vec2 c1,
    double r1,
    Vec2 c2,
    double r2,
  ) {
    final delta = c2 - c1;
    final distance = delta.length;
    if (distance < epsilon) return const [];
    if (distance > r1 + r2 + epsilon) return const [];
    if (distance < (r1 - r2).abs() - epsilon) return const [];
    final a = (r1 * r1 - r2 * r2 + distance * distance) / (2 * distance);
    final hSquared = r1 * r1 - a * a;
    final h = hSquared <= 0 ? 0.0 : math.sqrt(hSquared);
    final base = c1 + delta * (a / distance);
    if (h == 0) return [base];
    final offset = delta.perpendicular * (h / distance);
    return [base + offset, base - offset];
  }

  /// Closest point on the segment `[a, b]` to [p], clamped to the segment.
  static Vec2 closestPointOnSegment(Vec2 p, Vec2 a, Vec2 b) {
    final d = b - a;
    final lengthSquared = d.lengthSquared;
    if (lengthSquared < epsilon) return a;
    final t = ((p - a).dot(d) / lengthSquared).clamp(0.0, 1.0);
    return a + d * t;
  }

  /// Perpendicular distance from [p] to the segment `[a, b]`.
  static double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) =>
      p.distanceTo(closestPointOnSegment(p, a, b));

  /// Closest point on an interleaved `[x, y, ...]` polyline, plus the index of
  /// the segment that owns it. Returns null for degenerate input.
  static PolylineHit? closestPointOnPolyline(
    Vec2 p,
    Float64List xy, {
    bool closed = false,
  }) {
    final count = xy.length ~/ 2;
    if (count == 0) return null;
    if (count == 1) {
      return PolylineHit(Vec2(xy[0], xy[1]), 0, p.distanceTo(Vec2(xy[0], xy[1])));
    }
    var best = double.infinity;
    var bestPoint = Vec2(xy[0], xy[1]);
    var bestSegment = 0;
    final segmentCount = closed ? count : count - 1;
    for (var i = 0; i < segmentCount; i++) {
      final j = (i + 1) % count;
      final a = Vec2(xy[i * 2], xy[i * 2 + 1]);
      final b = Vec2(xy[j * 2], xy[j * 2 + 1]);
      final candidate = closestPointOnSegment(p, a, b);
      final distance = p.distanceSquaredTo(candidate);
      if (distance < best) {
        best = distance;
        bestPoint = candidate;
        bestSegment = i;
      }
    }
    return PolylineHit(bestPoint, bestSegment, math.sqrt(best));
  }

  /// Whether an interleaved polygon ring contains [p] (even-odd rule).
  static bool polygonContains(Float64List xy, Vec2 p) {
    final count = xy.length ~/ 2;
    if (count < 3) return false;
    var inside = false;
    for (var i = 0, j = count - 1; i < count; j = i++) {
      final xi = xy[i * 2], yi = xy[i * 2 + 1];
      final xj = xy[j * 2], yj = xy[j * 2 + 1];
      if ((yi > p.y) != (yj > p.y) &&
          p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Whether the polyline crosses the axis-aligned rectangle. Used by crossing
  /// window selection, which must hit entities that merely pass through.
  static bool polylineCrossesRect(
    Float64List xy,
    double minX,
    double minY,
    double maxX,
    double maxY, {
    bool closed = false,
  }) {
    final count = xy.length ~/ 2;
    if (count == 0) return false;
    if (count == 1) {
      final x = xy[0], y = xy[1];
      return x >= minX && x <= maxX && y >= minY && y <= maxY;
    }
    final segmentCount = closed ? count : count - 1;
    for (var i = 0; i < segmentCount; i++) {
      final j = (i + 1) % count;
      if (_segmentCrossesRect(
        xy[i * 2],
        xy[i * 2 + 1],
        xy[j * 2],
        xy[j * 2 + 1],
        minX,
        minY,
        maxX,
        maxY,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Cohen-Sutherland style trivial accept / reject followed by an exact test.
  static bool _segmentCrossesRect(
    double x0,
    double y0,
    double x1,
    double y1,
    double minX,
    double minY,
    double maxX,
    double maxY,
  ) {
    if ((x0 >= minX && x0 <= maxX && y0 >= minY && y0 <= maxY) ||
        (x1 >= minX && x1 <= maxX && y1 >= minY && y1 <= maxY)) {
      return true;
    }
    if (math.max(x0, x1) < minX ||
        math.min(x0, x1) > maxX ||
        math.max(y0, y1) < minY ||
        math.min(y0, y1) > maxY) {
      return false;
    }
    final a = Vec2(x0, y0);
    final b = Vec2(x1, y1);
    final corners = [
      Vec2(minX, minY),
      Vec2(maxX, minY),
      Vec2(maxX, maxY),
      Vec2(minX, maxY),
    ];
    for (var i = 0; i < 4; i++) {
      if (segmentSegment(a, b, corners[i], corners[(i + 1) % 4]) != null) {
        return true;
      }
    }
    return false;
  }

  /// Intersections of an infinite line with an ellipse (0, 1 or 2 points).
  ///
  /// The ellipse is mapped to the unit circle so the hit is the same
  /// quadratic as [lineCircle], then mapped back. [major] is the centre-to-
  /// end vector of the major axis; [ratio] is minor/major, as in DWG.
  static List<Vec2> lineEllipse(
    Vec2 p1,
    Vec2 p2,
    Vec2 center,
    Vec2 major,
    double ratio,
  ) {
    final frame = _EllipseFrame.tryParse(center, major, ratio);
    if (frame == null) return const [];
    return [
      for (final hit in lineCircle(
        frame.toUnit(p1),
        frame.toUnit(p2),
        const Vec2.zero(),
        1,
      ))
        frame.fromUnit(hit),
    ];
  }

  /// Intersections of a finite segment with an ellipse.
  static List<Vec2> segmentEllipse(
    Vec2 p1,
    Vec2 p2,
    Vec2 center,
    Vec2 major,
    double ratio,
  ) => [
    for (final hit in lineEllipse(p1, p2, center, major, ratio))
      if (distanceToSegment(hit, p1, p2) < 1e-6) hit,
  ];

  /// Intersections of a circle with an ellipse.
  ///
  /// Parameterising the ellipse turns `|P(t) − centre|² = r²` into a quartic
  /// in `tan(t/2)`. That is the same closed-form family as line/circle, just
  /// one degree higher, and it stays exact for a rotated oval.
  static List<Vec2> circleEllipse(
    Vec2 circleCenter,
    double radius,
    Vec2 ellipseCenter,
    Vec2 major,
    double ratio,
  ) {
    if (radius < 0 || !radius.isFinite) return const [];
    final frame = _EllipseFrame.tryParse(ellipseCenter, major, ratio);
    if (frame == null) return const [];
    return _conicCircleHits(
      ellipseCenter,
      major,
      major.perpendicular * ratio,
      circleCenter,
      radius,
    );
  }

  /// Intersections of two ellipses, including when one is a circle.
  ///
  /// The first ellipse is mapped to the unit circle; the second is pushed
  /// through the same affine map (still an ellipse, axes no longer required
  /// to be orthogonal) and the unit-circle ∩ ellipse quartic is solved.
  static List<Vec2> ellipseEllipse(
    Vec2 c1,
    Vec2 major1,
    double ratio1,
    Vec2 c2,
    Vec2 major2,
    double ratio2,
  ) {
    final frame = _EllipseFrame.tryParse(c1, major1, ratio1);
    if (frame == null) return const [];
    final center = frame.toUnit(c2);
    final axisA = frame.toUnit(c2 + major2) - center;
    final axisB = frame.toUnit(c2 + major2.perpendicular * ratio2) - center;
    return [
      for (final hit in _conicCircleHits(
        center,
        axisA,
        axisB,
        const Vec2.zero(),
        1,
      ))
        frame.fromUnit(hit),
    ];
  }

  /// Intersections of a line (or segment) with a flattened polyline.
  ///
  /// Used for NURBS and any other curve that has already been sampled to
  /// [tolerance]. Each chord is exact; the deviation from the true curve is
  /// the same bound [Flatten] already promises.
  static List<Vec2> linePolyline(
    Vec2 p1,
    Vec2 p2,
    Float64List xy, {
    bool closed = false,
    bool infinite = false,
  }) {
    final count = xy.length ~/ 2;
    if (count < 2) return const [];
    final out = <Vec2>[];
    final segments = closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final a = Vec2(xy[i * 2], xy[i * 2 + 1]);
      final b = Vec2(xy[((i + 1) % count) * 2], xy[((i + 1) % count) * 2 + 1]);
      final hit = infinite ? lineLine(p1, p2, a, b) : segmentSegment(p1, p2, a, b);
      if (hit == null) continue;
      if (infinite && distanceToSegment(hit, a, b) > 1e-6) continue;
      if (!_containsPoint(out, hit)) out.add(hit);
    }
    return out;
  }

  /// Intersections of a circle with a flattened polyline.
  static List<Vec2> circlePolyline(
    Vec2 center,
    double radius,
    Float64List xy, {
    bool closed = false,
  }) {
    final count = xy.length ~/ 2;
    if (count < 2) return const [];
    final out = <Vec2>[];
    final segments = closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final a = Vec2(xy[i * 2], xy[i * 2 + 1]);
      final b = Vec2(xy[((i + 1) % count) * 2], xy[((i + 1) % count) * 2 + 1]);
      for (final hit in lineCircle(a, b, center, radius)) {
        if (distanceToSegment(hit, a, b) > 1e-6) continue;
        if (!_containsPoint(out, hit)) out.add(hit);
      }
    }
    return out;
  }

  /// Intersections of two flattened polylines.
  static List<Vec2> polylinePolyline(
    Float64List a,
    Float64List b, {
    bool aClosed = false,
    bool bClosed = false,
  }) {
    final n = a.length ~/ 2;
    final m = b.length ~/ 2;
    if (n < 2 || m < 2) return const [];
    final out = <Vec2>[];
    final aSegs = aClosed ? n : n - 1;
    final bSegs = bClosed ? m : m - 1;
    for (var i = 0; i < aSegs; i++) {
      final p = Vec2(a[i * 2], a[i * 2 + 1]);
      final q = Vec2(a[((i + 1) % n) * 2], a[((i + 1) % n) * 2 + 1]);
      for (var j = 0; j < bSegs; j++) {
        final r = Vec2(b[j * 2], b[j * 2 + 1]);
        final s = Vec2(b[((j + 1) % m) * 2], b[((j + 1) % m) * 2 + 1]);
        final hit = segmentSegment(p, q, r, s);
        if (hit != null && !_containsPoint(out, hit)) out.add(hit);
      }
    }
    return out;
  }

  /// Samples a spline the way [Flatten.bspline] does, then intersects it
  /// with the line [p1]–[p2] and pulls each hit back onto the real curve.
  ///
  /// The flatten is still the search; the refine is a bisection on signed
  /// distance so TRIM and snaps land on the spline, not on a chord.
  static List<Vec2> lineSpline(
    Vec2 p1,
    Vec2 p2,
    Float64List controlPoints, {
    required List<double> knots,
    required int degree,
    List<double> weights = const [],
    bool closed = false,
    double tolerance = 1e-3,
    bool infinite = false,
  }) {
    final xy = Flatten.bspline(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
      weights: weights,
      tolerance: tolerance,
      closed: closed,
    );
    final count = xy.length ~/ 2;
    if (count < 2) return const [];
    final n = controlPoints.length ~/ 2;
    final canRefine =
        n > degree &&
        degree >= 1 &&
        knots.length == n + degree + 1 &&
        knots[n] > knots[degree];
    final tMin = canRefine ? knots[degree] : 0.0;
    final tMax = canRefine ? knots[n] : 0.0;
    final lastIndex = count - 1;
    final out = <Vec2>[];
    final segments = closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final a = Vec2(xy[i * 2], xy[i * 2 + 1]);
      final next = (i + 1) % count;
      final b = Vec2(xy[next * 2], xy[next * 2 + 1]);
      final hit = infinite
          ? lineLine(p1, p2, a, b)
          : segmentSegment(p1, p2, a, b);
      if (hit == null) continue;
      if (infinite && distanceToSegment(hit, a, b) > 1e-6) continue;
      final wraps = closed && next == 0;
      var point = hit;
      if (canRefine && !wraps) {
        final t0 = tMin + (tMax - tMin) * i / lastIndex;
        final t1 = i + 1 == lastIndex
            ? tMax - 1e-12
            : tMin + (tMax - tMin) * (i + 1) / lastIndex;
        final chord = b - a;
        final along = chord.lengthSquared < epsilon
            ? 0.0
            : ((hit - a).dot(chord) / chord.lengthSquared).clamp(0.0, 1.0);
        point =
            _refineLineSplineHit(
              p1,
              p2,
              controlPoints,
              knots,
              degree,
              weights,
              tMin,
              tMax,
              t0 + along * (t1 - t0),
            ) ??
            hit;
      }
      point = _projectOntoLine(p1, p2, point);
      if (!infinite && distanceToSegment(point, p1, p2) > 1e-6) continue;
      if (!_containsPoint(out, point)) out.add(point);
    }
    return out;
  }

  static Vec2 _projectOntoLine(Vec2 p1, Vec2 p2, Vec2 point) {
    final d = p2 - p1;
    final lengthSquared = d.lengthSquared;
    if (lengthSquared < epsilon) return p1;
    return p1 + d * ((point - p1).dot(d) / lengthSquared);
  }

  static Vec2? _refineLineSplineHit(
    Vec2 p1,
    Vec2 p2,
    Float64List controlPoints,
    List<double> knots,
    int degree,
    List<double> weights,
    double tMin,
    double tMax,
    double tGuess,
  ) {
    final dir = p2 - p1;
    if (dir.lengthSquared < epsilon) return null;
    final span = tMax - tMin;
    if (span <= 0) return null;
    double side(Vec2 p) => (p - p1).cross(dir);
    Vec2? eval(double t) => Flatten.bsplineEvaluate(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
      t: t,
      weights: weights,
    );
    var t = tGuess.clamp(tMin, tMax - 1e-12);
    for (var i = 0; i < 16; i++) {
      final p = eval(t);
      if (p == null) break;
      final f = side(p);
      if (f.abs() < 1e-12) return p;
      final dt = math.max(span * 1e-5, 1e-8);
      final plus = eval((t + dt).clamp(tMin, tMax - 1e-12));
      final minus = eval((t - dt).clamp(tMin, tMax - 1e-12));
      if (plus == null || minus == null) break;
      final fp = (side(plus) - side(minus)) / (2 * dt);
      if (fp.abs() < 1e-14) break;
      t = (t - f / fp).clamp(tMin, tMax - 1e-12);
    }
    final newton = eval(t);
    if (newton != null && side(newton).abs() < 1e-8) return newton;

    // Coarse flatten can put the true crossing outside the hit chord.
    // Walk a neighbourhood of the guess until the signed distance flips.
    final pad = math.max(span * 0.05, 1e-6);
    var lo = (tGuess - pad).clamp(tMin, tMax - 1e-12);
    var hi = (tGuess + pad).clamp(tMin, tMax - 1e-12);
    var a = eval(lo);
    var b = eval(hi);
    if (a == null || b == null) return newton;
    var sa = side(a);
    var sb = side(b);
    if (sa * sb > 0) {
      lo = tMin;
      hi = tMax - 1e-12;
      a = eval(lo);
      b = eval(hi);
      if (a == null || b == null) return newton;
      sa = side(a);
      sb = side(b);
      if (sa * sb > 0) return newton;
    }
    if (sa.abs() < 1e-14) return a;
    if (sb.abs() < 1e-14) return b;
    for (var i = 0; i < 24; i++) {
      final mid = 0.5 * (lo + hi);
      final p = eval(mid);
      if (p == null) return newton;
      final sm = side(p);
      if (sm.abs() < 1e-14) return p;
      if (sa * sm <= 0) {
        hi = mid;
      } else {
        lo = mid;
        sa = sm;
      }
    }
    return eval(0.5 * (lo + hi)) ?? newton;
  }

  /// `|Q + cos(t) A + sin(t) B|² = r²` as a quartic in `tan(t/2)`.
  ///
  /// [A] and [B] need not be perpendicular: after an affine map an ellipse
  /// is still an ellipse, but its conjugate diameters rotate independently.
  static List<Vec2> _conicCircleHits(
    Vec2 origin,
    Vec2 axisA,
    Vec2 axisB,
    Vec2 circleCenter,
    double radius,
  ) {
    if (axisA.lengthSquared < epsilon || axisB.lengthSquared < epsilon) {
      return const [];
    }
    final q = origin - circleCenter;
    final k = q.lengthSquared - radius * radius;
    final aa = axisA.lengthSquared;
    final bb = axisB.lengthSquared;
    final ab = axisA.dot(axisB);
    final qa = q.dot(axisA);
    final qb = q.dot(axisB);
    // Weierstrass: c = (1−u²)/(1+u²), s = 2u/(1+u²). Multiply through by
    // (1+u²)² to get c4 u⁴ + c3 u³ + c2 u² + c1 u + c0 = 0.
    final c4 = k - 2 * qa + aa;
    final c3 = 4 * qb - 4 * ab;
    final c2 = 2 * k - 2 * aa + 4 * bb;
    final c1 = 4 * qb + 4 * ab;
    final c0 = k + 2 * qa + aa;
    final us = _realQuarticRoots(c4, c3, c2, c1, c0);
    final out = <Vec2>[];
    void consider(double t) {
      final point = origin + axisA * math.cos(t) + axisB * math.sin(t);
      if ((point.distanceTo(circleCenter) - radius).abs() > 1e-5) return;
      if (!_containsPoint(out, point)) out.add(point);
    }

    for (final u in us) {
      consider(2 * math.atan(u));
    }
    // u → ∞ is t = π, which tan(t/2) cannot represent.
    consider(math.pi);
    return out;
  }

  /// Real roots of `c4 x⁴ + c3 x³ + c2 x² + c1 x + c0 = 0`.
  ///
  /// Durand–Kerner on the monic companion is enough here: the coefficients
  /// come from a geometric quartic, so four seeds around the unit circle
  /// converge, and we only keep roots whose imaginary part has collapsed.
  static List<double> _realQuarticRoots(
    double c4,
    double c3,
    double c2,
    double c1,
    double c0,
  ) {
    if (c4.abs() < 1e-16) {
      if (c3.abs() < 1e-16) {
        return _realQuadraticRoots(c2, c1, c0);
      }
      return _realCubicRoots(c3, c2, c1, c0);
    }
    final a = c3 / c4;
    final b = c2 / c4;
    final c = c1 / c4;
    final d = c0 / c4;
    final radius = 1 + [a.abs(), b.abs(), c.abs(), d.abs()].reduce(math.max);
    var z0 = _Cx(radius, 0);
    var z1 = _Cx(0, radius);
    var z2 = _Cx(-radius, 0);
    var z3 = _Cx(0, -radius);
    _Cx poly(_Cx z) =>
        (((z + _Cx(a, 0)) * z + _Cx(b, 0)) * z + _Cx(c, 0)) * z + _Cx(d, 0);
    for (var i = 0; i < 48; i++) {
      _Cx step(_Cx z, _Cx o1, _Cx o2, _Cx o3) {
        final den = (z - o1) * (z - o2) * (z - o3);
        if (den.abs2 < 1e-30) return z;
        return z - poly(z) / den;
      }

      final n0 = step(z0, z1, z2, z3);
      final n1 = step(z1, z0, z2, z3);
      final n2 = step(z2, z0, z1, z3);
      final n3 = step(z3, z0, z1, z2);
      z0 = n0;
      z1 = n1;
      z2 = n2;
      z3 = n3;
    }
    final out = <double>[];
    for (final z in [z0, z1, z2, z3]) {
      if (z.im.abs() > 1e-6) continue;
      if (out.any((u) => (u - z.re).abs() < 1e-8)) continue;
      out.add(z.re);
    }
    return out;
  }

  static List<double> _realCubicRoots(double a, double b, double c, double d) {
    if (a.abs() < 1e-16) return _realQuadraticRoots(b, c, d);
    final p = b / a;
    final q = c / a;
    final r = d / a;
    // Depress: x = y − p/3.
    final shift = p / 3;
    final aa = q - p * p / 3;
    final bb = 2 * p * p * p / 27 - p * q / 3 + r;
    final disc = bb * bb / 4 + aa * aa * aa / 27;
    final ys = <double>[];
    if (disc.abs() < 1e-16 && aa.abs() < 1e-16) {
      ys.add(0);
    } else if (disc > 0) {
      final root = math.sqrt(disc);
      final u = _cbrt(-bb / 2 + root);
      final v = _cbrt(-bb / 2 - root);
      ys.add(u + v);
    } else {
      final rho = math.sqrt(-aa / 3);
      final theta = math.acos(
        ((-bb / 2) / (rho * rho * rho)).clamp(-1.0, 1.0),
      );
      ys
        ..add(2 * rho * math.cos(theta / 3))
        ..add(2 * rho * math.cos((theta + 2 * math.pi) / 3))
        ..add(2 * rho * math.cos((theta + 4 * math.pi) / 3));
    }
    return [for (final y in ys) y - shift];
  }

  static List<double> _realQuadraticRoots(double a, double b, double c) {
    if (a.abs() < 1e-16) {
      if (b.abs() < 1e-16) return const [];
      return [-c / b];
    }
    final disc = b * b - 4 * a * c;
    if (disc < -1e-12) return const [];
    if (disc.abs() < 1e-12) return [-b / (2 * a)];
    final root = math.sqrt(disc);
    return [(-b - root) / (2 * a), (-b + root) / (2 * a)];
  }

  static double _cbrt(double value) =>
      value < 0 ? -math.pow(-value, 1 / 3).toDouble() : math.pow(value, 1 / 3).toDouble();

  static bool _containsPoint(List<Vec2> points, Vec2 hit) {
    for (final point in points) {
      if (point.distanceSquaredTo(hit) < 1e-12) return true;
    }
    return false;
  }
}

/// Affine frame that sends an ellipse to the unit circle.
class _EllipseFrame {
  const _EllipseFrame(this.center, this.major, this.minor);

  final Vec2 center;
  final Vec2 major;
  final Vec2 minor;

  static _EllipseFrame? tryParse(Vec2 center, Vec2 major, double ratio) {
    if (major.lengthSquared < Intersect.epsilon) return null;
    if (!ratio.isFinite || ratio.abs() < 1e-15) return null;
    return _EllipseFrame(center, major, major.perpendicular * ratio);
  }

  Vec2 toUnit(Vec2 world) {
    final delta = world - center;
    final det = major.cross(minor);
    if (det.abs() < Intersect.epsilon) return const Vec2.zero();
    return Vec2(delta.cross(minor) / det, major.cross(delta) / det);
  }

  Vec2 fromUnit(Vec2 unit) => center + major * unit.x + minor * unit.y;
}

class _Cx {
  const _Cx(this.re, this.im);

  final double re;
  final double im;

  double get abs2 => re * re + im * im;

  _Cx operator +(_Cx other) => _Cx(re + other.re, im + other.im);
  _Cx operator -(_Cx other) => _Cx(re - other.re, im - other.im);
  _Cx operator *(_Cx other) =>
      _Cx(re * other.re - im * other.im, re * other.im + im * other.re);
  _Cx operator /(_Cx other) {
    final den = other.abs2;
    if (den < 1e-30) return this;
    return _Cx(
      (re * other.re + im * other.im) / den,
      (im * other.re - re * other.im) / den,
    );
  }
}

/// The result of projecting a point onto a polyline.
class PolylineHit {
  const PolylineHit(this.point, this.segmentIndex, this.distance);

  final Vec2 point;
  final int segmentIndex;
  final double distance;
}
