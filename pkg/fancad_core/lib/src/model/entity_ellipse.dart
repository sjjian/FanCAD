part of 'entity.dart';

/// An ellipse or elliptical arc. Angles are ellipse parameters, as in DWG.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class EllipseEntity extends CadEntity {
  const EllipseEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.center,
    required this.majorAxis,
    required this.ratio,
    this.startParam = 0,
    this.endParam = math.pi * 2,
  });

  static EllipseEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => EllipseEntity(
    id: id,
    props: props,
    center: _point(json['center']),
    majorAxis: _point(json['majorAxis']),
    ratio: (json['ratio'] as num?)?.toDouble() ?? 1,
    startParam: (json['startParam'] as num?)?.toDouble() ?? 0,
    endParam: (json['endParam'] as num?)?.toDouble() ?? math.pi * 2,
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 center;

  /// Vector from the centre to the end of the major axis.
  @JsonKey(toJson: vec2ToJson)
  final Vec2 majorAxis;
  @JsonKey()
  final double ratio;
  @JsonKey()
  final double startParam;
  @JsonKey()
  final double endParam;

  /// DWG treats equal parameters as a full ellipse. `endParam` defaults to
  /// `2π`, which [normalizeAngle] wraps to 0, so the comparison has to be
  /// on the circle rather than on the raw numbers.
  bool get isFullEllipse {
    const eps = 1e-9;
    final delta = (normalizeAngle(endParam) - normalizeAngle(startParam)).abs();
    return delta < eps || (math.pi * 2 - delta).abs() < eps;
  }

  double get majorLength => majorAxis.length;

  /// The minor-axis vector, perpendicular to [majorAxis] and scaled by [ratio].
  Vec2 get minorAxis => majorAxis.perpendicular * ratio;

  /// Parameter sweep. A full ellipse is `2π`, not the 0 that equal
  /// start/end parameters would otherwise compute.
  double get sweep =>
      isFullEllipse ? math.pi * 2 : angularSweep(startParam, endParam);

  Vec2 get startPoint => pointAt(startParam);
  Vec2 get endPoint => pointAt(endParam);

  /// The point at ellipse parameter [param], matching DWG (not a true angle).
  Vec2 pointAt(double param) =>
      center + majorAxis * math.cos(param) + minorAxis * math.sin(param);

  /// Maps [world] into the unit-circle space of this ellipse.
  ///
  /// The ellipse becomes `u² + v² = 1`, which is how line and circle
  /// intersections stay closed-form instead of falling back to flattening.
  Vec2 toUnit(Vec2 world) {
    final delta = world - center;
    final major = majorAxis;
    final minor = minorAxis;
    final det = major.cross(minor);
    if (det.abs() < 1e-18) return const Vec2.zero();
    return Vec2(delta.cross(minor) / det, major.cross(delta) / det);
  }

  Vec2 fromUnit(Vec2 unit) => center + majorAxis * unit.x + minorAxis * unit.y;

  /// The ellipse parameter of [world], `atan2` of the unit-space coordinates.
  double paramOf(Vec2 world) {
    final unit = toUnit(world);
    return math.atan2(unit.y, unit.x);
  }

  /// Whether [param] lies on this ellipse or elliptical arc.
  bool containsParam(double param) {
    if (isFullEllipse) return true;
    return angularSweep(startParam, param) <= sweep + 1e-9;
  }

  @override
  EntityKind get kind => EntityKind.ellipse;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final points = Flatten.ellipse(
      center: center,
      major: majorAxis,
      ratio: ratio,
      startParam: startParam,
      endParam: endParam,
      tolerance: context.tolerance,
    );
    sink.polyline(
      context.applyBuffer(points),
      context.styleFor(props),
      closed: isFullEllipse,
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final major = majorAxis;
    final minor = minorAxis;
    if (isFullEllipse) {
      // x(t) = Cx + Mx cos t + mx sin t, and the extrema are
      // ±sqrt(Mx² + mx²). Same for y. Flattening just to measure a box
      // is how a sheet of hatches used to stall Zoom Extents.
      final extX = math.sqrt(major.x * major.x + minor.x * minor.x);
      final extY = math.sqrt(major.y * major.y + minor.y * minor.y);
      return Bounds2(
        center.x - extX,
        center.y - extY,
        center.x + extX,
        center.y + extY,
      );
    }
    var box = Bounds2.fromPoints([startPoint, endPoint]);
    void consider(double param) {
      if (!containsParam(param)) return;
      final point = pointAt(param);
      box = box.expandToInclude(point.x, point.y);
    }

    if (major.x != 0 || minor.x != 0) {
      final t = math.atan2(minor.x, major.x);
      consider(t);
      consider(t + math.pi);
    }
    if (major.y != 0 || minor.y != 0) {
      final t = math.atan2(minor.y, major.y);
      consider(t);
      consider(t + math.pi);
    }
    return box;
  }

  @override
  EllipseEntity withId(int id) => EllipseEntity(
    id: id,
    props: props,
    center: center,
    majorAxis: majorAxis,
    ratio: ratio,
    startParam: startParam,
    endParam: endParam,
  );

  @override
  EllipseEntity withProps(EntityProps props) => EllipseEntity(
    id: id,
    props: props,
    center: center,
    majorAxis: majorAxis,
    ratio: ratio,
    startParam: startParam,
    endParam: endParam,
  );

  @override
  EllipseEntity transformed(Mat3 matrix) => _affineEllipse(this, matrix);

  @override
  List<Vec2> grips() => [
    center,
    center + majorAxis,
    center - majorAxis,
    center + majorAxis.perpendicular * ratio,
    center - majorAxis.perpendicular * ratio,
  ];

  @override
  EllipseEntity withGrip(int index, Vec2 target) => index == 0
      ? EllipseEntity(
          id: id,
          props: props,
          center: target,
          majorAxis: majorAxis,
          ratio: ratio,
          startParam: startParam,
          endParam: endParam,
        )
      : index <= 2
      ? EllipseEntity(
          id: id,
          props: props,
          center: center,
          majorAxis: index == 1 ? target - center : center - target,
          ratio: ratio,
          startParam: startParam,
          endParam: endParam,
        )
      : EllipseEntity(
          id: id,
          props: props,
          center: center,
          majorAxis: majorAxis,
          ratio: majorAxis.length == 0
              ? ratio
              : (target - center).length / majorAxis.length,
          startParam: startParam,
          endParam: endParam,
        );

  /// Grows both axes by [distance]. The true parallel of an ellipse is not
  /// an ellipse; this is the concentric construction drafters expect, and it
  /// is exact when the oval is a circle.
  @override
  CadEntity? offsetBy(double distance, Vec2 towards) {
    final unit = toUnit(towards);
    final sign = unit.lengthSquared >= 1 ? 1.0 : -1.0;
    final majorLen = majorLength + distance * sign;
    final minorLen = majorLength * ratio + distance * sign;
    if (majorLen <= 1e-9 || minorLen <= 1e-9) return null;
    var major = majorAxis;
    if (major.lengthSquared < 1e-20) return null;
    var nextRatio = minorLen / majorLen;
    if (nextRatio > 1) {
      major = major.normalized().perpendicular * minorLen;
      nextRatio = majorLen / minorLen;
    } else {
      major = major.normalized() * majorLen;
    }
    return EllipseEntity(
      id: 0,
      props: props,
      center: center,
      majorAxis: major,
      ratio: nextRatio,
      startParam: startParam,
      endParam: endParam,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, center)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  /// Ramanujan's approximation for a full ellipse; an elliptical arc is
  /// that length scaled by the parameter sweep. Close enough for DIST.
  @override
  double get pathLength {
    final a = majorLength;
    final b = a * ratio;
    if (a <= 0 || b <= 0) return 0;
    final h = (a - b) / (a + b);
    final h2 = h * h;
    final full =
        math.pi * (a + b) * (1 + 3 * h2 / (10 + math.sqrt(4 - 3 * h2)));
    return isFullEllipse ? full : full * sweep / (math.pi * 2);
  }

  @override
  double get signedArea =>
      isFullEllipse ? math.pi * majorLength * majorLength * ratio : 0;

  @override
  Map<String, Object?> geometryToJson() => _$EllipseEntityToJson(this);
}
