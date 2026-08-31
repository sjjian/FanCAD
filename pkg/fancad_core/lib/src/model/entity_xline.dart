part of 'entity.dart';

/// An infinite construction line.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class XLineEntity extends CadEntity {
  const XLineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.origin,
    required this.direction,
  });

  static XLineEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => XLineEntity(
    id: id,
    props: props,
    origin: _point(json['origin']),
    direction: _point(json['direction'], fallback: const Vec2(1, 0)),
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 direction;

  static const double _extent = 1e7;

  @override
  EntityKind get kind => EntityKind.xline;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final unit = direction.normalized();
    if (unit.length == 0) return;
    final reach = math.max((context.clip?.diagonal ?? _extent) * 2, _extent);
    final a = context.apply(origin - unit * reach);
    final b = context.apply(origin + unit * reach);
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
    return Bounds2.fromPoints([
      origin - unit * _extent,
      origin + unit * _extent,
    ]);
  }

  @override
  XLineEntity withId(int id) =>
      XLineEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  XLineEntity withProps(EntityProps props) =>
      XLineEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  XLineEntity transformed(Mat3 matrix) => XLineEntity(
    id: id,
    props: props,
    origin: matrix.transform(origin),
    direction: matrix.transformDirection(direction),
  );

  @override
  List<Vec2> grips() => [origin];

  @override
  XLineEntity withGrip(int index, Vec2 target) => index == 0
      ? XLineEntity(id: id, props: props, origin: target, direction: direction)
      : XLineEntity(
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
  Map<String, Object?> geometryToJson() => _$XLineEntityToJson(this);
}
