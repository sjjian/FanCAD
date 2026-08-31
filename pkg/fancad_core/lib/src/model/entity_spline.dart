part of 'entity.dart';

/// A NURBS curve.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class SplineEntity extends CadEntity {
  const SplineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.controlPoints,
    this.knots = const [],
    this.weights = const [],
    this.degree = 3,
    this.closed = false,
    this.fitPoints,
  });

  static SplineEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => SplineEntity(
    id: id,
    props: props,
    controlPoints: _pointBuffer(json['controlPoints']),
    knots: _doubleList(json['knots']),
    weights: _doubleList(json['weights']),
    degree: (json['degree'] as num?)?.toInt() ?? 3,
    closed: json['closed'] as bool? ?? false,
    fitPoints: _pointBuffer(json['fitPoints']),
  );

  /// Interleaved `[x, y, ...]`.
  @JsonKey(toJson: pointBufferToJson)
  final Float64List controlPoints;
  @JsonKey(toJson: doubleListToJsonIfNotEmpty)
  final List<double> knots;
  @JsonKey(toJson: doubleListToJsonIfNotEmpty)
  final List<double> weights;
  @JsonKey()
  final int degree;
  @JsonKey(toJson: omitFalse)
  final bool closed;

  /// Interleaved `[x, y, ...]` fit points, when the spline was defined by
  /// interpolation rather than by control points. Preserved for round-tripping.
  @JsonKey(toJson: optionalPointBufferToJson)
  final Float64List? fitPoints;

  Float64List get fitPointBuffer => fitPoints ?? _emptyBuffer;

  int get controlPointCount => controlPoints.length ~/ 2;

  int get fitPointCount => fitPointBuffer.length ~/ 2;

  /// Control polygon used to draw and measure. Stored controls win; a
  /// fit-only spline interpolates them without writing them back.
  _SplineGeom get _geom {
    if (controlPointCount >= 2) {
      return _SplineGeom(controlPoints, knots, weights, degree);
    }
    final fits = <Vec2>[
      for (var i = 0; i + 1 < fitPointBuffer.length; i += 2)
        Vec2(fitPointBuffer[i], fitPointBuffer[i + 1]),
    ];
    final interpolated = Flatten.interpolateFit(fits);
    if (interpolated == null) {
      return _SplineGeom(controlPoints, knots, weights, degree);
    }
    return _SplineGeom(
      interpolated.controlPoints,
      interpolated.knots,
      const [],
      interpolated.degree,
    );
  }

  Float64List _centreline(double tolerance) {
    final geom = _geom;
    if (geom.controlPoints.length < 4) return Float64List(0);
    return Flatten.bspline(
      controlPoints: geom.controlPoints,
      knots: geom.knots,
      degree: geom.degree,
      weights: geom.weights,
      tolerance: tolerance,
      closed: closed,
    );
  }

  @override
  EntityKind get kind => EntityKind.spline;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final points = _centreline(context.tolerance);
    if (points.length < 4) return;
    sink.polyline(
      context.applyBuffer(points),
      context.styleFor(props),
      closed: closed,
    );
  }

  @override
  SplineEntity withId(int id) => SplineEntity(
    id: id,
    props: props,
    controlPoints: controlPoints,
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    fitPoints: fitPoints,
  );

  @override
  SplineEntity withProps(EntityProps props) => SplineEntity(
    id: id,
    props: props,
    controlPoints: controlPoints,
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    fitPoints: fitPoints,
  );

  @override
  SplineEntity transformed(Mat3 matrix) => SplineEntity(
    id: id,
    props: props,
    controlPoints: _transformBuffer(controlPoints, matrix),
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    fitPoints: _transformBuffer(fitPointBuffer, matrix),
  );

  @override
  List<Vec2> grips() {
    final geom = _geom;
    final count = geom.controlPoints.length ~/ 2;
    return [
      for (var i = 0; i < count; i++)
        Vec2(geom.controlPoints[i * 2], geom.controlPoints[i * 2 + 1]),
    ];
  }

  @override
  SplineEntity withGrip(int index, Vec2 target) {
    final geom = _geom;
    final count = geom.controlPoints.length ~/ 2;
    if (index < 0 || index >= count) return this;
    final out = Float64List.fromList(geom.controlPoints);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: out,
      knots: geom.knots,
      weights: geom.weights,
      degree: geom.degree,
      closed: closed,
      fitPoints: fitPoints,
    );
  }

  /// Offsets the flattened centreline. A NURBS offset is not a NURBS of the
  /// same degree, so the result is a polyline the fillet/trim family can
  /// keep editing.
  @override
  CadEntity? offsetBy(double distance, Vec2 towards) {
    final xy = _centreline(1e-3);
    final points = <Vec2>[
      for (var i = 0; i + 1 < xy.length; i += 2) Vec2(xy[i], xy[i + 1]),
    ];
    if (points.length < 2) return null;
    return PolylineEntity.fromPoints(
      id: 0,
      props: props,
      points: points,
      closed: closed,
    ).offsetBy(distance, towards);
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    var any = false;
    final controls = Float64List.fromList(controlPoints);
    for (var i = 0; i < controlPointCount; i++) {
      final x = controls[i * 2];
      final y = controls[i * 2 + 1];
      if (!window.containsPoint(x, y)) continue;
      any = true;
      controls[i * 2] = x + delta.x;
      controls[i * 2 + 1] = y + delta.y;
    }
    Float64List? fits = fitPoints;
    if (fits != null) {
      final out = Float64List.fromList(fits);
      for (var i = 0; i < out.length; i += 2) {
        if (!window.containsPoint(out[i], out[i + 1])) continue;
        any = true;
        out[i] += delta.x;
        out[i + 1] += delta.y;
      }
      fits = out;
    }
    if (!any) return null;
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: controls,
      knots: knots,
      weights: weights,
      degree: degree,
      closed: closed,
      fitPoints: fits,
    );
  }

  @override
  double get pathLength {
    final xy = _centreline(1e-3);
    var total = 0.0;
    final count = xy.length ~/ 2;
    final segments = closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final dx = xy[((i + 1) % count) * 2] - xy[i * 2];
      final dy = xy[((i + 1) % count) * 2 + 1] - xy[i * 2 + 1];
      total += math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  @override
  Map<String, Object?> geometryToJson() => _$SplineEntityToJson(this);
}

class _SplineGeom {
  const _SplineGeom(
    this.controlPoints,
    this.knots,
    this.weights,
    this.degree,
  );

  final Float64List controlPoints;
  final List<double> knots;
  final List<double> weights;
  final int degree;
}
