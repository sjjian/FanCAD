part of 'entity.dart';

/// A full circle.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class CircleEntity extends CadEntity implements Curve {
  const CircleEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.center,
    required this.radius,
  });

  static CircleEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => CircleEntity(
    id: id,
    props: props,
    center: _point(json['center']),
    radius: (json['radius'] as num?)?.toDouble() ?? 0,
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 center;
  @JsonKey()
  final double radius;

  @override
  EntityKind get kind => EntityKind.circle;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (radius <= 0) return;
    if (emitAsPixel(
      context,
      sink,
      Bounds2(
        center.x - radius,
        center.y - radius,
        center.x + radius,
        center.y + radius,
      ),
    )) {
      return;
    }
    final points = Flatten.circle(
      center: center,
      radius: radius,
      tolerance: context.tolerance,
    );
    sink.polyline(
      context.applyBuffer(points),
      context.styleFor(props),
      closed: true,
    );
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) {
    sink.center(center);
    sink.quadrant(center + Vec2(radius, 0));
    sink.quadrant(center + Vec2(0, radius));
    sink.quadrant(center + Vec2(-radius, 0));
    sink.quadrant(center + Vec2(0, -radius));
    sink.circle(center, radius);
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(
    center.x - radius,
    center.y - radius,
    center.x + radius,
    center.y + radius,
  );

  @override
  CircleEntity withId(int id) =>
      CircleEntity(id: id, props: props, center: center, radius: radius);

  @override
  CircleEntity withProps(EntityProps props) =>
      CircleEntity(id: id, props: props, center: center, radius: radius);

  @override
  CadEntity transformed(Mat3 matrix) {
    if (matrix.isConformal) {
      return CircleEntity(
        id: id,
        props: props,
        center: matrix.transform(center),
        radius: radius * matrix.meanScale,
      );
    }
    // A non-uniform scale turns a circle into an ellipse. Recover principal
    // axes so SCALE Y > X does not produce a ratio greater than 1.
    return _affineEllipse(
      EllipseEntity(
        id: id,
        props: props,
        center: center,
        majorAxis: Vec2(radius, 0),
        ratio: 1,
      ),
      matrix,
    );
  }

  @override
  List<Vec2> grips() => [
    center,
    Vec2(center.x + radius, center.y),
    Vec2(center.x, center.y + radius),
    Vec2(center.x - radius, center.y),
    Vec2(center.x, center.y - radius),
  ];

  @override
  CircleEntity withGrip(int index, Vec2 target) => index == 0
      ? CircleEntity(id: id, props: props, center: target, radius: radius)
      : CircleEntity(
          id: id,
          props: props,
          center: center,
          radius: center.distanceTo(target),
        );

  @override
  CadEntity? offsetBy(double distance, Vec2 towards) {
    final target = center.distanceTo(towards) > radius
        ? radius + distance
        : radius - distance;
    if (target <= 0) return null;
    return CircleEntity(id: 0, props: props, center: center, radius: target);
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, center)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  double get pathLength => 2 * math.pi * radius;

  @override
  bool get isLoop => true;

  /// Starts at angle zero and runs counter-clockwise.
  @override
  Vec2 along(double t) => center + Vec2.polar(math.pi * 2 * t, radius);

  @override
  double paramNear(Vec2 point) {
    final t = normalizeAngle((point - center).angle) / (math.pi * 2);
    return t >= 1 ? 0 : t;
  }

  @override
  ArcEntity? span(double from, double to) {
    final start = math.pi * 2 * from;
    final end = math.pi * 2 * to;
    final sweep = angularSweep(start, end);
    if (radius <= 0 || sweep < 1e-9 || sweep > math.pi * 2 - 1e-9) {
      return null;
    }
    return ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: start,
      endAngle: end,
    );
  }

  @override
  double maxGrowth({required bool atStart}) => 0;

  @override
  double get signedArea => math.pi * radius * radius;

  @override
  Map<String, Object?> geometryToJson() => _$CircleEntityToJson(this);
}
