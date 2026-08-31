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

  @override
  EntityKind get kind => EntityKind.spline;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (controlPointCount == 0) return;
    final points = Flatten.bspline(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
      weights: weights,
      tolerance: context.tolerance,
      closed: closed,
    );
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
  List<Vec2> grips() => [
    for (var i = 0; i < controlPointCount; i++)
      Vec2(controlPoints[i * 2], controlPoints[i * 2 + 1]),
  ];

  @override
  SplineEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= controlPointCount) return this;
    final out = Float64List.fromList(controlPoints);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: out,
      knots: knots,
      weights: weights,
      degree: degree,
      closed: closed,
      fitPoints: fitPoints,
    );
  }

  /// Offsets the flattened centreline. A NURBS offset is not a NURBS of the
  /// same degree, so the result is a polyline the fillet/trim family can
  /// keep editing.
  @override
  CadEntity? offsetBy(double distance, Vec2 towards) {
    final xy = Flatten.bspline(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
      weights: weights,
      tolerance: 1e-3,
      closed: closed,
    );
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
    final xy = Flatten.bspline(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
      weights: weights,
      tolerance: 1e-3,
      closed: closed,
    );
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
