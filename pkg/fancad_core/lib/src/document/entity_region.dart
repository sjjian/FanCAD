part of 'entity.dart';

/// One curve of a REGION boundary.
///
/// A REGION is stored as closed loops, not as a list of sampled points. The
/// curve types keep arcs and ellipses analytic so a transform or an area
/// calculation does not have to approximate them.
abstract class RegionCurve {
  const RegionCurve();

  Vec2 get start;
  Vec2 get end;
  bool get isClosed;

  double get length;
  double get signedAreaContribution;
  Bounds2 get bounds;

  RegionCurve transformed(Mat3 matrix);
  RegionCurve reversed();

  /// Samples the curve for display and polygon fallbacks.
  ///
  /// The first point is [start] and the last is [end].
  List<Vec2> samplePoints(double tolerance);

  Map<String, Object?> toJson();

  static RegionCurve fromJson(Map<String, Object?> json) {
    switch (json['type']) {
      case 'line':
        return RegionLine(
          start: vec2FromJson(json['start']),
          end: vec2FromJson(json['end']),
        );
      case 'conic':
        return RegionConicArc(
          center: vec2FromJson(json['center']),
          u: vec2FromJson(json['u']),
          v: vec2FromJson(json['v']),
          startParameter: (json['start'] as num?)?.toDouble() ?? 0,
          sweep: (json['sweep'] as num?)?.toDouble() ?? 0,
        );
      case 'polyline':
        return RegionPolyline(pointBufferFromJson(json['points']));
      case 'spline':
        return RegionSpline(
          controlPoints: pointBufferFromJson(json['controlPoints']),
          knots: doubleListFromJson(json['knots']),
          weights: doubleListFromJson(json['weights']),
          degree: (json['degree'] as num?)?.toInt() ?? 3,
          closed: json['closed'] as bool? ?? false,
          rangeStart: (json['rangeStart'] as num?)?.toDouble() ?? 0,
          rangeEnd: (json['rangeEnd'] as num?)?.toDouble() ?? 1,
        );
      default:
        throw FormatException('Unknown region curve ${json['type']}');
    }
  }
}

final class RegionLine extends RegionCurve {
  const RegionLine({required this.start, required this.end});

  @override
  final Vec2 start;
  @override
  final Vec2 end;

  @override
  bool get isClosed => start == end;

  @override
  double get length => (end - start).length;

  @override
  double get signedAreaContribution => (start.x * end.y - start.y * end.x) / 2;

  @override
  Bounds2 get bounds => Bounds2.fromCorners(start, end);

  @override
  RegionLine transformed(Mat3 matrix) =>
      RegionLine(start: matrix.transform(start), end: matrix.transform(end));

  @override
  RegionLine reversed() => RegionLine(start: end, end: start);

  @override
  List<Vec2> samplePoints(double tolerance) => [start, end];

  @override
  Map<String, Object?> toJson() => {
    'type': 'line',
    'start': vec2ToJson(start),
    'end': vec2ToJson(end),
  };
}

/// A circular or elliptical arc.
///
/// `p(t) = center + u * cos(t) + v * sin(t)` for `t` from [start] through
/// [sweep]. This conjugate-axis form is why an affine transform is exact: it
/// only has to map [center], [u] and [v].
final class RegionConicArc extends RegionCurve {
  const RegionConicArc({
    required this.center,
    required this.u,
    required this.v,
    required this.startParameter,
    required this.sweep,
  });

  final Vec2 center;
  final Vec2 u;
  final Vec2 v;

  /// Parameter of [start].
  final double startParameter;

  /// Signed parameter span. `±2π` is a full ellipse.
  final double sweep;

  @override
  Vec2 get start => pointAt(startParameter);

  @override
  Vec2 get end => pointAt(startParameter + sweep);

  @override
  bool get isClosed => (sweep.abs() - math.pi * 2).abs() < 1e-9;

  Vec2 pointAt(double t) => Vec2(
    center.x + u.x * math.cos(t) + v.x * math.sin(t),
    center.y + u.y * math.cos(t) + v.y * math.sin(t),
  );

  @override
  double get length {
    final steps = math.max(32, (sweep.abs() / (math.pi / 128)).ceil());
    var length = 0.0;
    var previous = pointAt(startParameter);
    for (var i = 1; i <= steps; i++) {
      final point = pointAt(startParameter + sweep * i / steps);
      length += (point - previous).length;
      previous = point;
    }
    return length;
  }

  @override
  double get signedAreaContribution {
    final a = startParameter;
    final b = startParameter + sweep;
    final pa = pointAt(a);
    final pb = pointAt(b);
    final area2 =
        center.x * (pb.y - pa.y) -
        center.y * (pb.x - pa.x) +
        (u.x * v.y - u.y * v.x) * sweep;
    return area2 / 2;
  }

  @override
  Bounds2 get bounds {
    var box = Bounds2.fromPoints([
      start,
      end,
      pointAt(startParameter + sweep / 2),
    ]);
    final span = sweep.abs();
    final full = span >= math.pi * 2 - 1e-9;
    if (full) {
      for (final t in _extremumParameters) {
        box = box.expandToInclude(pointAt(t).x, pointAt(t).y);
      }
      return box;
    }
    for (final t in _extremumParameters) {
      if (_containsParameter(t)) {
        box = box.expandToInclude(pointAt(t).x, pointAt(t).y);
      }
    }
    return box;
  }

  List<double> get _extremumParameters {
    final xs = math.atan2(v.x, u.x);
    final ys = math.atan2(v.y, u.y);
    return [xs, xs + math.pi, ys, ys + math.pi];
  }

  bool _containsParameter(double t) {
    final span = sweep.abs();
    if (span >= math.pi * 2 - 1e-9) return true;
    final direction = sweep < 0 ? -1.0 : 1.0;
    var delta = ((t - startParameter) * direction) % (math.pi * 2);
    if (delta < 0) delta += math.pi * 2;
    return delta <= span + 1e-9;
  }

  /// Whether the conic is a circular arc.
  bool get isCircular =>
      (u.length - v.length).abs() < 1e-9 && u.dot(v).abs() < 1e-9;

  double get circularRadius => (u.length + v.length) / 2;

  /// The parameter of [point] on this conic, or null when it is degenerate.
  double? parameterOf(Vec2 point) {
    final determinant = u.x * v.y - u.y * v.x;
    if (determinant.abs() < 1e-20) return null;
    final delta = point - center;
    final cosine = (delta.x * v.y - delta.y * v.x) / determinant;
    final sine = (u.x * delta.y - u.y * delta.x) / determinant;
    if (cosine.abs() < 1e-12 && sine.abs() < 1e-12) return null;
    return math.atan2(sine, cosine);
  }

  /// Whether [parameter] falls inside the arc's sweep.
  bool containsParameter(double parameter) => _containsParameter(parameter);

  /// The four axis endpoints of this conic.
  ///
  /// For a circle these are world X/Y quadrants; for a general ellipse they
  /// come from the singular values of `[u v]`, so a sheared ellipse still
  /// snaps to its true axes rather than its conjugate diameters.
  List<Vec2> get quadrantPoints {
    if (isCircular) {
      final radius = circularRadius;
      return [
        center + Vec2(radius, 0),
        center + Vec2(0, radius),
        center + Vec2(-radius, 0),
        center + Vec2(0, -radius),
      ];
    }
    final a = u.x * u.x + v.x * v.x;
    final b = u.x * u.y + v.x * v.y;
    final c = u.y * u.y + v.y * v.y;
    final trace = a + c;
    final discriminant = math.sqrt(math.max(0, (a - c) * (a - c) + 4 * b * b));
    final major = (trace + discriminant) / 2;
    final minor = (trace - discriminant) / 2;
    if (major <= 1e-20) return const [];
    final majorAxis = b.abs() > 1e-15
        ? Vec2(b, major - a).normalized()
        : (a >= c ? const Vec2(1, 0) : const Vec2(0, 1));
    final minorAxis = majorAxis.perpendicular;
    final majorRadius = math.sqrt(major);
    final minorRadius = math.sqrt(math.max(0, minor));
    return [
      center + majorAxis * majorRadius,
      center - majorAxis * majorRadius,
      if (minorRadius > 1e-9) center + minorAxis * minorRadius,
      if (minorRadius > 1e-9) center - minorAxis * minorRadius,
    ];
  }

  @override
  RegionConicArc transformed(Mat3 matrix) => RegionConicArc(
    center: matrix.transform(center),
    u: matrix.transformDirection(u),
    v: matrix.transformDirection(v),
    startParameter: startParameter,
    sweep: sweep,
  );

  @override
  RegionConicArc reversed() => RegionConicArc(
    center: center,
    u: u,
    v: v,
    startParameter: startParameter + sweep,
    sweep: -sweep,
  );

  @override
  List<Vec2> samplePoints(double tolerance) {
    final radius = math.max(u.length, v.length);
    final chord =
        2 *
        math.acos(
          math.max(-1.0, math.min(1.0, 1 - tolerance / math.max(radius, 1e-9))),
        );
    final safe = chord.isFinite && chord > 0 ? chord : math.pi / 16;
    final steps = (sweep.abs() / safe).ceil().clamp(2, 512);
    return [
      for (var i = 0; i <= steps; i++)
        pointAt(startParameter + sweep * i / steps),
    ];
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'conic',
    'center': vec2ToJson(center),
    'u': vec2ToJson(u),
    'v': vec2ToJson(v),
    'start': startParameter,
    'sweep': sweep,
  };
}

/// A straight-segment fallback inside a boundary.
final class RegionPolyline extends RegionCurve {
  RegionPolyline(Float64List points)
    : points = points.length.isEven
          ? points
          : Float64List.fromList(points.sublist(0, points.length - 1));

  /// Interleaved `[x, y, ...]`.
  final Float64List points;

  int get pointCount => points.length ~/ 2;

  @override
  Vec2 get start => pointCount == 0 ? Vec2.zero() : _pointAt(0);

  @override
  Vec2 get end => pointCount == 0 ? Vec2.zero() : _pointAt(pointCount - 1);

  Vec2 _pointAt(int index) => Vec2(points[index * 2], points[index * 2 + 1]);

  @override
  bool get isClosed => pointCount > 1 && start == end;

  @override
  double get length {
    var sum = 0.0;
    for (var i = 1; i < pointCount; i++) {
      sum += (_pointAt(i) - _pointAt(i - 1)).length;
    }
    return sum;
  }

  @override
  double get signedAreaContribution {
    var sum = 0.0;
    for (var i = 1; i < pointCount; i++) {
      final a = _pointAt(i - 1);
      final b = _pointAt(i);
      sum += (a.x * b.y - a.y * b.x) / 2;
    }
    return sum;
  }

  @override
  Bounds2 get bounds => Bounds2.fromXY(points);

  @override
  RegionPolyline transformed(Mat3 matrix) =>
      RegionPolyline(_transformBuffer(points, matrix));

  @override
  RegionPolyline reversed() {
    final out = Float64List(points.length);
    for (var i = 0; i < pointCount; i++) {
      out[i * 2] = points[(pointCount - 1 - i) * 2];
      out[i * 2 + 1] = points[(pointCount - 1 - i) * 2 + 1];
    }
    return RegionPolyline(out);
  }

  @override
  List<Vec2> samplePoints(double tolerance) => [
    for (var i = 0; i < pointCount; i++) _pointAt(i),
  ];

  @override
  Map<String, Object?> toJson() => {
    'type': 'polyline',
    'points': pointBufferToJson(points),
  };
}

/// A NURBS segment. Kept for files whose ACIS reader cannot resolve a curve
/// into a line or conic; transforms stay exact on the control points.
final class RegionSpline extends RegionCurve {
  RegionSpline({
    required this.controlPoints,
    required this.knots,
    required this.weights,
    required this.degree,
    required this.closed,
    this.rangeStart = 0,
    this.rangeEnd = 1,
  });

  final Float64List controlPoints;
  final List<double> knots;
  final List<double> weights;
  final int degree;
  final bool closed;

  /// The portion of the original NURBS parameter domain this curve keeps.
  ///
  /// Trimming a spline stores a sub-range instead of re-approximating its
  /// control points, so the trimmed edge stays the same exact curve.
  final double rangeStart;
  final double rangeEnd;

  int get controlPointCount => controlPoints.length ~/ 2;

  bool get isFullRange => rangeStart <= 1e-12 && rangeEnd >= 1 - 1e-12;

  Vec2 _controlAt(int index) =>
      Vec2(controlPoints[index * 2], controlPoints[index * 2 + 1]);

  RegionSpline withRange(double start, double end) => RegionSpline(
    controlPoints: controlPoints,
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    rangeStart: start,
    rangeEnd: end,
  );

  /// A standalone spline entity with the same geometry as this (possibly
  /// trimmed) region edge.
  ///
  /// A trimmed range is converted by extracting the exact polynomial span, so
  /// the result stores standard control points and knots rather than a
  /// REGION-only parameter range. Null when the curve data is inconsistent.
  SplineEntity? asSpline({
    int id = 0,
    EntityProps props = EntityProps.defaults,
  }) {
    if (isFullRange) {
      return SplineEntity(
        id: id,
        props: props,
        controlPoints: controlPoints,
        knots: knots,
        weights: weights,
        degree: degree,
        closed: closed,
      );
    }
    final subcurve = SplineSubcurve.extract(
      controlPoints: controlPoints,
      knots: knots,
      weights: weights,
      degree: degree,
      start: rangeStart,
      end: rangeEnd,
    );
    if (subcurve == null) return null;
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: subcurve.controlPoints,
      knots: subcurve.knots,
      weights: subcurve.weights,
      degree: subcurve.degree,
      closed: false,
    );
  }

  Vec2 _evaluate(double fraction) {
    final count = controlPointCount;
    if (count == 0) return Vec2.zero();
    if (count <= degree || knots.length != count + degree + 1) {
      return _controlAt(0);
    }
    final minimum = knots[degree];
    final maximum = knots[count];
    if (!(maximum > minimum)) return _controlAt(0);
    final t = minimum + (maximum - minimum) * fraction.clamp(0.0, 1.0);
    return Flatten.bsplineEvaluate(
          controlPoints: controlPoints,
          knots: knots,
          degree: degree,
          t: t,
          weights: weights,
        ) ??
        _controlAt(0);
  }

  @override
  Vec2 get start => controlPointCount == 0
      ? Vec2.zero()
      : isFullRange
      ? _controlAt(0)
      : _evaluate(rangeStart);

  @override
  Vec2 get end => controlPointCount == 0
      ? Vec2.zero()
      : isFullRange
      ? _controlAt(controlPointCount - 1)
      : _evaluate(rangeEnd);

  @override
  bool get isClosed => closed && isFullRange;

  Float64List _sampled(double tolerance) => Flatten.bspline(
    controlPoints: controlPoints,
    knots: knots,
    degree: degree,
    weights: weights,
    tolerance: tolerance,
    closed: closed,
    start: rangeStart,
    end: rangeEnd,
  );

  @override
  double get length {
    final points = _sampled(0.01);
    var sum = 0.0;
    for (var i = 2; i < points.length; i += 2) {
      final dx = points[i] - points[i - 2];
      final dy = points[i + 1] - points[i - 1];
      sum += math.sqrt(dx * dx + dy * dy);
    }
    return sum;
  }

  @override
  double get signedAreaContribution {
    final points = _sampled(0.01);
    var sum = 0.0;
    for (var i = 2; i < points.length; i += 2) {
      sum += (points[i - 2] * points[i + 1] - points[i - 1] * points[i]) / 2;
    }
    return sum;
  }

  @override
  Bounds2 get bounds => Bounds2.fromXY(_sampled(0.01));

  @override
  RegionSpline transformed(Mat3 matrix) => RegionSpline(
    controlPoints: _transformBuffer(controlPoints, matrix),
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );

  @override
  RegionCurve reversed() {
    final count = controlPointCount;
    if (count == 0 || knots.length != count + degree + 1) {
      final points = _sampled(0.01);
      final out = Float64List(points.length);
      final sampleCount = points.length ~/ 2;
      for (var i = 0; i < sampleCount; i++) {
        out[i * 2] = points[(sampleCount - 1 - i) * 2];
        out[i * 2 + 1] = points[(sampleCount - 1 - i) * 2 + 1];
      }
      return RegionPolyline(out);
    }
    final reversedControl = Float64List(controlPoints.length);
    for (var i = 0; i < count; i++) {
      reversedControl[i * 2] = controlPoints[(count - 1 - i) * 2];
      reversedControl[i * 2 + 1] = controlPoints[(count - 1 - i) * 2 + 1];
    }
    final last = knots.length - 1;
    final minimum = knots.first;
    final maximum = knots.last;
    final reversedKnots = [
      for (var i = 0; i <= last; i++) minimum + maximum - knots[last - i],
    ];
    final reversedWeights = weights.length == count
        ? [for (var i = 0; i < count; i++) weights[count - 1 - i]]
        : weights;
    return RegionSpline(
      controlPoints: reversedControl,
      knots: reversedKnots,
      weights: reversedWeights,
      degree: degree,
      closed: closed,
      rangeStart: 1 - rangeEnd,
      rangeEnd: 1 - rangeStart,
    );
  }

  @override
  List<Vec2> samplePoints(double tolerance) {
    final points = _sampled(tolerance);
    final out = [
      for (var i = 0; i < points.length ~/ 2; i++)
        Vec2(points[i * 2], points[i * 2 + 1]),
    ];
    if (isClosed && out.isNotEmpty && out.first != out.last) out.add(out.first);
    return out;
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'spline',
    'controlPoints': pointBufferToJson(controlPoints),
    'knots': doubleListToJsonIfNotEmpty(knots),
    'weights': doubleListToJsonIfNotEmpty(weights),
    'degree': degree,
    'closed': closed,
    if (!isFullRange) 'rangeStart': rangeStart,
    if (!isFullRange) 'rangeEnd': rangeEnd,
  };
}

/// A closed chain of [RegionCurve]s.
final class RegionLoop {
  const RegionLoop(this.curves);

  final List<RegionCurve> curves;

  bool get isEmpty => curves.isEmpty;

  double get signedArea {
    var sum = curves.fold(
      0.0,
      (sum, curve) => sum + curve.signedAreaContribution,
    );
    if (curves.isNotEmpty) {
      final a = curves.last.end;
      final b = curves.first.start;
      sum += (a.x * b.y - a.y * b.x) / 2;
    }
    return sum;
  }

  double get length => curves.fold(0.0, (sum, curve) => sum + curve.length);

  Bounds2 get bounds {
    var box = const Bounds2.empty();
    for (final curve in curves) {
      box = box.union(curve.bounds);
    }
    return box;
  }

  List<Vec2> samplePoints(double tolerance) {
    final out = <Vec2>[];
    for (final curve in curves) {
      final points = curve.samplePoints(tolerance);
      for (final point in points) {
        if (out.isNotEmpty && (out.last - point).lengthSquared < 1e-20) {
          continue;
        }
        out.add(point);
      }
    }
    if (out.length > 1 && (out.last - out.first).lengthSquared < 1e-20) {
      out.removeLast();
    }
    return out;
  }

  Float64List toBuffer(double tolerance) {
    final points = samplePoints(tolerance);
    final out = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      out[i * 2] = points[i].x;
      out[i * 2 + 1] = points[i].y;
    }
    return out;
  }

  RegionLoop transformed(Mat3 matrix) =>
      RegionLoop([for (final curve in curves) curve.transformed(matrix)]);

  RegionLoop reversed() =>
      RegionLoop([for (final curve in curves.reversed) curve.reversed()]);

  RegionLoop normalized({required bool outer}) {
    final area = signedArea;
    if ((outer && area < 0) || (!outer && area > 0)) return reversed();
    return this;
  }

  Map<String, Object?> toJson() => {
    'curves': [for (final curve in curves) curve.toJson()],
  };

  static RegionLoop fromJson(Object? value) {
    if (value is! Map) return const RegionLoop([]);
    final raw = value['curves'];
    return RegionLoop([
      if (raw is List)
        for (final item in raw)
          if (item is Map) RegionCurve.fromJson(item.cast<String, Object?>()),
    ]);
  }
}

/// One connected face: outer boundary plus holes.
final class RegionComponent {
  const RegionComponent({required this.outer, this.holes = const []});

  final RegionLoop outer;
  final List<RegionLoop> holes;

  double get signedArea =>
      outer.signedArea -
      holes.fold(0.0, (sum, hole) => sum + hole.signedArea.abs());

  Bounds2 get bounds {
    var box = outer.bounds;
    for (final hole in holes) {
      box = box.union(hole.bounds);
    }
    return box;
  }

  bool contains(Vec2 point, {double tolerance = 1e-3}) {
    if (!outer.bounds.containsPoint(point.x, point.y)) return false;
    if (!Intersect.polygonContains(outer.toBuffer(tolerance), point)) {
      return false;
    }
    for (final hole in holes) {
      if (Intersect.polygonContains(hole.toBuffer(tolerance), point)) {
        return false;
      }
    }
    return true;
  }

  RegionComponent transformed(Mat3 matrix) => RegionComponent(
    outer: outer.transformed(matrix),
    holes: [for (final hole in holes) hole.transformed(matrix)],
  );

  RegionComponent normalized() => RegionComponent(
    outer: outer.normalized(outer: true),
    holes: [for (final hole in holes) hole.normalized(outer: false)],
  );

  Map<String, Object?> toJson() => {
    'outer': outer.toJson(),
    'holes': [for (final hole in holes) hole.toJson()],
  };

  static RegionComponent fromJson(Object? value) {
    if (value is! Map) {
      return const RegionComponent(outer: RegionLoop([]));
    }
    final holes = value['holes'];
    return RegionComponent(
      outer: RegionLoop.fromJson(value['outer']),
      holes: [
        if (holes is List)
          for (final item in holes) RegionLoop.fromJson(item),
      ],
    );
  }
}

/// Pure geometry of a REGION, independent of identity and layer.
final class RegionGeometry {
  const RegionGeometry({required this.components, this.approximated = false});

  final List<RegionComponent> components;
  final bool approximated;

  bool get isEmpty => components.isEmpty;

  double get signedArea =>
      components.fold(0.0, (sum, component) => sum + component.signedArea);

  double get pathLength => components.fold(0.0, (sum, component) {
    var length = component.outer.length;
    for (final hole in component.holes) {
      length += hole.length;
    }
    return sum + length;
  });

  Bounds2 get bounds {
    var box = const Bounds2.empty();
    for (final component in components) {
      box = box.union(component.bounds);
    }
    return box;
  }

  bool contains(Vec2 point, {double tolerance = 1e-3}) => components.any(
    (component) => component.contains(point, tolerance: tolerance),
  );

  RegionGeometry transformed(Mat3 matrix) => RegionGeometry(
    components: [
      for (final component in components)
        component.transformed(matrix).normalized(),
    ],
    approximated: approximated,
  );

  RegionGeometry normalized() => RegionGeometry(
    components: [for (final component in components) component.normalized()],
    approximated: approximated,
  );

  /// Groups [loops] into components by containment.
  ///
  /// The largest loop is an outer boundary; a loop inside it is a hole; a
  /// loop inside a hole starts a new component (an island).
  static RegionGeometry fromLoops(
    List<RegionLoop> loops, {
    bool approximated = false,
    double tolerance = 1e-6,
  }) {
    if (loops.isEmpty) {
      return const RegionGeometry(components: []);
    }
    final ordered = [...loops]
      ..sort((a, b) => b.signedArea.abs().compareTo(a.signedArea.abs()));
    final polygons = [for (final loop in ordered) loop.toBuffer(tolerance)];
    final depths = List<int>.filled(ordered.length, 0);
    for (var i = 0; i < ordered.length; i++) {
      final probe = _interiorProbe(ordered[i], polygons[i]);
      for (var j = 0; j < ordered.length; j++) {
        if (i == j) continue;
        if (ordered[j].signedArea.abs() <= ordered[i].signedArea.abs()) {
          continue;
        }
        if (Intersect.polygonContains(polygons[j], probe)) depths[i]++;
      }
    }
    final components = <RegionComponent>[];
    final outerIndexes = <int, int>{}; // loop index -> component index
    for (var i = 0; i < ordered.length; i++) {
      if (depths[i].isEven) {
        components.add(RegionComponent(outer: ordered[i]).normalized());
        outerIndexes[i] = components.length - 1;
      }
    }
    for (var i = 0; i < ordered.length; i++) {
      if (depths[i].isOdd) {
        final parent = _smallestContainingOuter(ordered, depths, polygons, i);
        final componentIndex = outerIndexes[parent];
        if (componentIndex != null) {
          final component = components[componentIndex];
          components[componentIndex] = RegionComponent(
            outer: component.outer,
            holes: [...component.holes, ordered[i].normalized(outer: false)],
          );
        }
      }
    }
    return RegionGeometry(components: components, approximated: approximated);
  }

  static Vec2 _interiorProbe(RegionLoop loop, Float64List polygon) {
    // The vertex average is inside for the simple convex and ring-shaped
    // profiles REGION files normally contain. A boundary sample is the
    // fallback for a concave loop whose average falls outside.
    var x = 0.0;
    var y = 0.0;
    final count = polygon.length ~/ 2;
    for (var i = 0; i < count; i++) {
      x += polygon[i * 2];
      y += polygon[i * 2 + 1];
    }
    if (count > 0) {
      final p = Vec2(x / count, y / count);
      if (Intersect.polygonContains(polygon, p)) return p;
    }
    return loop.samplePoints(1e-3).first;
  }

  static int _smallestContainingOuter(
    List<RegionLoop> loops,
    List<int> depths,
    List<Float64List> polygons,
    int hole,
  ) {
    final probe = _interiorProbe(loops[hole], polygons[hole]);
    var best = -1;
    var bestArea = double.infinity;
    for (var j = 0; j < loops.length; j++) {
      if (depths[j].isOdd) continue;
      if (loops[j].signedArea.abs() <= loops[hole].signedArea.abs()) continue;
      if (!Intersect.polygonContains(polygons[j], probe)) continue;
      final area = loops[j].signedArea.abs();
      if (area < bestArea) {
        bestArea = area;
        best = j;
      }
    }
    return best;
  }

  Map<String, Object?> toJson() => {
    'components': [for (final component in components) component.toJson()],
    'approximated': approximated,
  };
}

/// Original ACIS data kept for a lossless save when the REGION is untouched.
final class AcisPayload {
  const AcisPayload({
    required this.format,
    required this.bytes,
    this.transform,
    this.sourceType = 'REGION',
  });

  /// `sat` (ASCII SAT v1) or `sab` (binary SAB v2).
  final String format;
  final Uint8List bytes;
  final Mat3? transform;
  final String sourceType;

  String get text => String.fromCharCodes(bytes);

  Map<String, Object?> toJson() => {
    'format': format,
    'data': base64Encode(bytes),
    if (transform != null) 'transform': _matrixToJson(transform!),
    'sourceType': sourceType,
  };

  static AcisPayload? fromJson(Object? value) {
    if (value is! Map) return null;
    final data = value['data'];
    if (data is! String) return null;
    return AcisPayload(
      format: '${value['format'] ?? 'sat'}',
      bytes: base64Decode(data),
      transform: _matrixFromJson(value['transform']),
      sourceType: '${value['sourceType'] ?? 'REGION'}',
    );
  }
}

/// A planar REGION with one or more connected components and optional holes.
final class RegionEntity extends CadEntity {
  const RegionEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.components,
    this.source,
    this.approximated = false,
    this.valid = true,
  });

  static RegionEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) {
    final raw = json['components'];
    return RegionEntity(
      id: id,
      props: props,
      components: [
        if (raw is List)
          for (final item in raw) RegionComponent.fromJson(item),
      ],
      source: AcisPayload.fromJson(json['source']),
      approximated: json['approximated'] as bool? ?? false,
      valid: json['valid'] as bool? ?? true,
    );
  }

  final List<RegionComponent> components;
  final AcisPayload? source;
  final bool approximated;
  final bool valid;

  RegionGeometry get geometry =>
      RegionGeometry(components: components, approximated: approximated);

  @override
  EntityKind get kind => EntityKind.region;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (components.isEmpty) return;
    if (emitAsPixel(context, sink, computeBounds())) return;
    final style = context.styleFor(props);
    for (final component in components) {
      for (final loop in [component.outer, ...component.holes]) {
        final points = loop.toBuffer(context.tolerance);
        if (points.length >= 4) {
          sink.polyline(context.applyBuffer(points), style, closed: true);
        }
      }
    }
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) {
    for (final component in components) {
      for (final loop in [component.outer, ...component.holes]) {
        final singlePolyline =
            loop.curves.length == 1 && loop.curves.single is RegionPolyline;
        for (final curve in loop.curves) {
          switch (curve) {
            case RegionLine(:final start, :final end):
              sink.endpoint(start);
              sink.endpoint(end);
              sink.midpoint(start.lerp(end, 0.5));
              sink.segment(start, end);
            case RegionPolyline(:final points):
              final pointsList = [
                for (var i = 0; i < points.length ~/ 2; i++)
                  Vec2(points[i * 2], points[i * 2 + 1]),
              ];
              for (final point in pointsList) {
                sink.endpoint(point);
              }
              for (var i = 1; i < pointsList.length; i++) {
                final a = pointsList[i - 1];
                final b = pointsList[i];
                sink.midpoint(a.lerp(b, 0.5));
                sink.segment(a, b);
              }
              if (singlePolyline && pointsList.length > 1) {
                final a = pointsList.last;
                final b = pointsList.first;
                if (a.distanceTo(b) > 1e-9) {
                  sink.midpoint(a.lerp(b, 0.5));
                  sink.segment(a, b);
                }
              }
            case RegionSpline():
              sink.endpoint(curve.start);
              sink.endpoint(curve.end);
            case final RegionConicArc conic:
              sink.center(conic.center);
              if (conic.isCircular) {
                sink.circle(conic.center, conic.circularRadius);
              }
              for (final point in conic.quadrantPoints) {
                final parameter = conic.parameterOf(point);
                if (parameter != null && conic.containsParameter(parameter)) {
                  sink.quadrant(point);
                }
              }
              if (!conic.isClosed) {
                sink.endpoint(conic.start);
                sink.endpoint(conic.end);
                sink.midpoint(
                  conic.pointAt(conic.startParameter + conic.sweep / 2),
                );
              }
          }
        }
      }
    }
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => geometry.bounds;

  @override
  double get signedArea => geometry.signedArea;

  @override
  double get pathLength => geometry.pathLength;

  /// True when [point] is inside any component and outside its holes.
  bool contains(Vec2 point, {double tolerance = 1e-3}) =>
      geometry.contains(point, tolerance: tolerance);

  @override
  RegionEntity withId(int id) => RegionEntity(
    id: id,
    props: props,
    components: components,
    source: source,
    approximated: approximated,
    valid: valid,
  );

  @override
  RegionEntity withProps(EntityProps props) => RegionEntity(
    id: id,
    props: props,
    components: components,
    source: source,
    approximated: approximated,
    valid: valid,
  );

  @override
  RegionEntity transformed(Mat3 matrix) {
    if (matrix.isIdentity) return this;
    final transformed = geometry.transformed(matrix);
    return RegionEntity(
      id: id,
      props: props,
      components: transformed.components,
      approximated: transformed.approximated,
      valid: valid,
    );
  }

  @override
  List<Vec2> grips() => const [];

  @override
  RegionEntity withGrip(int index, Vec2 target) => this;

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return window.containsBox(computeBounds())
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  List<CadEntity> explode(ExplodeSource drawing) {
    final pieces = <CadEntity>[];
    for (final component in components) {
      for (final loop in [component.outer, ...component.holes]) {
        for (final curve in loop.curves) {
          pieces.add(_curveEntity(curve));
        }
      }
    }
    return pieces;
  }

  CadEntity _curveEntity(RegionCurve curve) {
    switch (curve) {
      case RegionLine(:final start, :final end):
        return LineEntity(id: 0, props: props, start: start, end: end);
      case RegionPolyline(:final points):
        return PolylineEntity(
          id: 0,
          props: props,
          vertices: Float64List.fromList([
            for (var i = 0; i < points.length ~/ 2; i++) ...[
              points[i * 2],
              points[i * 2 + 1],
              0.0,
            ],
          ]),
        );
      case RegionSpline():
        final spline = curve.asSpline(props: props);
        if (spline != null) return spline;
        final points = curve.samplePoints(0.01);
        return PolylineEntity.fromPoints(id: 0, props: props, points: points);
      case final RegionConicArc conic:
        final circular =
            (conic.u.length - conic.v.length).abs() < 1e-9 &&
            conic.u.dot(conic.v).abs() < 1e-9;
        if (circular) {
          final radius = conic.u.length;
          if (conic.isClosed) {
            return CircleEntity(
              id: 0,
              props: props,
              center: conic.center,
              radius: radius,
            );
          }
          var a0 = conic.startParameter;
          var a1 = conic.startParameter + conic.sweep;
          if (a1 < a0) {
            final swap = a0;
            a0 = a1;
            a1 = swap;
          }
          return ArcEntity(
            id: 0,
            props: props,
            center: conic.center,
            radius: radius,
            startAngle: a0,
            endAngle: a1,
          );
        }
        final points = conic.samplePoints(0.01);
        return PolylineEntity(
          id: 0,
          props: props,
          vertices: Float64List.fromList([
            for (final point in points) ...[point.x, point.y, 0.0],
          ]),
        );
      default:
        throw UnsupportedError('Cannot explode ${curve.runtimeType}');
    }
  }

  @override
  Map<String, Object?> geometryToJson() => {
    'components': [for (final component in components) component.toJson()],
    'approximated': approximated,
    'valid': valid,
    if (source != null) 'source': source!.toJson(),
  };
}

List<double> _matrixToJson(Mat3 matrix) => [
  matrix.a,
  matrix.b,
  matrix.c,
  matrix.d,
  matrix.e,
  matrix.f,
];

Mat3? _matrixFromJson(Object? value) {
  if (value is! List || value.length < 6) return null;
  final values = [
    for (final item in value)
      if (item is num) item.toDouble(),
  ];
  if (values.length < 6) return null;
  return Mat3(values[0], values[1], values[2], values[3], values[4], values[5]);
}
