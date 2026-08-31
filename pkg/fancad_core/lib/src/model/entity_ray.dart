part of 'entity.dart';

/// A semi-infinite construction line.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class RayEntity extends CadEntity {
  const RayEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.origin,
    required this.direction,
  });

  static RayEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => RayEntity(
    id: id,
    props: props,
    origin: _point(json['origin']),
    direction: _point(json['direction'], fallback: const Vec2(1, 0)),
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 direction;

  /// Construction lines are unbounded, so they are clipped to a large multiple
  /// of the current view extents at emit time.
  static const double _extent = 1e7;

  @override
  EntityKind get kind => EntityKind.ray;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final unit = direction.normalized();
    if (unit.length == 0) return;
    final reach = context.clip?.diagonal ?? _extent;
    final a = context.apply(origin);
    final b = context.apply(origin + unit * math.max(reach * 2, _extent));
    sink.polyline(
      Float64List.fromList([a.x, a.y, b.x, b.y]),
      context.styleFor(props),
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(origin.x, origin.y, origin.x, origin.y);

  @override
  Bounds2 indexBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final unit = direction.normalized();
    if (unit.length == 0) return computeBounds();
    return Bounds2.fromPoints([origin, origin + unit * _extent]);
  }

  @override
  RayEntity withId(int id) =>
      RayEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  RayEntity withProps(EntityProps props) =>
      RayEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  RayEntity transformed(Mat3 matrix) => RayEntity(
    id: id,
    props: props,
    origin: matrix.transform(origin),
    direction: matrix.transformDirection(direction),
  );

  @override
  List<Vec2> grips() => [origin, origin + direction.normalized()];

  @override
  RayEntity withGrip(int index, Vec2 target) => index == 0
      ? RayEntity(id: id, props: props, origin: target, direction: direction)
      : RayEntity(
          id: id,
          props: props,
          origin: origin,
          direction: target - origin,
        );

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, origin)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  Map<String, Object?> geometryToJson() => _$RayEntityToJson(this);
}
