part of 'entity.dart';

/// A circular arc, swept counter-clockwise from [startAngle] to [endAngle].
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class ArcEntity extends CadEntity {
  const ArcEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
  });

  static ArcEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => ArcEntity(
    id: id,
    props: props,
    center: _point(json['center']),
    radius: (json['radius'] as num?)?.toDouble() ?? 0,
    startAngle: (json['startAngle'] as num?)?.toDouble() ?? 0,
    endAngle: (json['endAngle'] as num?)?.toDouble() ?? 0,
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 center;
  @JsonKey()
  final double radius;
  @JsonKey()
  final double startAngle;
  @JsonKey()
  final double endAngle;

  double get sweep => angularSweep(startAngle, endAngle);
  Vec2 get startPoint => center + Vec2.polar(startAngle, radius);
  Vec2 get endPoint => center + Vec2.polar(endAngle, radius);
  Vec2 get midPoint => center + Vec2.polar(startAngle + sweep / 2, radius);

  @override
  EntityKind get kind => EntityKind.arc;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (radius <= 0) return;
    if (emitAsPixel(context, sink, computeBounds())) return;
    final points = Flatten.arc(
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      tolerance: context.tolerance,
    );
    sink.polyline(context.applyBuffer(points), context.styleFor(props));
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) {
    sink.center(center);
    sink.endpoint(startPoint);
    sink.endpoint(endPoint);
    sink.midpoint(midPoint);
    const quadrants = [0.0, math.pi / 2, math.pi, math.pi * 3 / 2];
    for (final angle in quadrants) {
      if (angularSweep(startAngle, angle) <= sweep) {
        sink.quadrant(center + Vec2.polar(angle, radius));
      }
    }
    sink.circle(center, radius);
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    // Exact: the extremes are the endpoints plus whichever axis crossings the
    // sweep actually covers.
    var box = Bounds2.fromPoints([startPoint, endPoint]);
    const quadrants = [0.0, math.pi / 2, math.pi, math.pi * 3 / 2];
    final start = normalizeAngle(startAngle);
    final total = sweep == 0 ? math.pi * 2 : sweep;
    for (final quadrant in quadrants) {
      final delta = angularSweep(start, quadrant);
      if (delta <= total) {
        final p = center + Vec2.polar(quadrant, radius);
        box = box.expandToInclude(p.x, p.y);
      }
    }
    return box;
  }

  @override
  ArcEntity withId(int id) => ArcEntity(
    id: id,
    props: props,
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
  );

  @override
  ArcEntity withProps(EntityProps props) => ArcEntity(
    id: id,
    props: props,
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
  );

  @override
  ArcEntity transformed(Mat3 matrix) {
    final scale = matrix.meanScale;
    final mirrored = matrix.determinant < 0;
    final rotation = matrix.rotation;
    final start = mirrored
        ? math.pi - endAngle + rotation
        : startAngle + rotation;
    final end = mirrored
        ? math.pi - startAngle + rotation
        : endAngle + rotation;
    return ArcEntity(
      id: id,
      props: props,
      center: matrix.transform(center),
      radius: radius * scale,
      startAngle: start,
      endAngle: end,
    );
  }

  @override
  List<Vec2> grips() => [startPoint, midPoint, endPoint, center];

  @override
  ArcEntity withGrip(int index, Vec2 target) => switch (index) {
    0 => ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: (target - center).angle,
      endAngle: endAngle,
    ),
    2 => ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: (target - center).angle,
    ),
    3 => ArcEntity(
      id: id,
      props: props,
      center: target,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
    ),
    _ => ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: center.distanceTo(target),
      startAngle: startAngle,
      endAngle: endAngle,
    ),
  };

  @override
  CadEntity? offsetBy(double distance, Vec2 towards) {
    final target = center.distanceTo(towards) > radius
        ? radius + distance
        : radius - distance;
    if (target <= 0) return null;
    return ArcEntity(
      id: 0,
      props: props,
      center: center,
      radius: target,
      startAngle: startAngle,
      endAngle: endAngle,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    if (_inStretchWindow(window, center)) {
      return transformed(Mat3.translation(delta.x, delta.y));
    }
    var result = this;
    var changed = false;
    if (_inStretchWindow(window, startPoint)) {
      result = result.withGrip(0, startPoint + delta);
      changed = true;
    }
    if (_inStretchWindow(window, endPoint)) {
      result = result.withGrip(2, endPoint + delta);
      changed = true;
    }
    return changed ? result : null;
  }

  /// Same curve, opposite start. The model is always counter-clockwise, so
  /// swapping the angles would draw the complementary sweep; a negative
  /// bulge keeps the pixels and flips the traversal, matching JOIN.
  @override
  CadEntity? reversed() {
    if (radius <= 0 || sweep < 1e-12) return null;
    return PolylineEntity(
      id: id,
      props: props,
      vertices: Float64List.fromList([
        endPoint.x,
        endPoint.y,
        -math.tan(sweep / 4),
        startPoint.x,
        startPoint.y,
        0,
      ]),
    );
  }

  @override
  double get pathLength => radius * sweep;

  @override
  Map<String, Object?> geometryToJson() => _$ArcEntityToJson(this);
}
