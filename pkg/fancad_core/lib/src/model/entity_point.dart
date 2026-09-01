part of 'entity.dart';

/// A node point.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class PointEntity extends CadEntity {
  const PointEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
  });

  static PointEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => PointEntity(id: id, props: props, position: _point(json['position']));

  @JsonKey(toJson: vec2ToJson)
  final Vec2 position;

  @override
  EntityKind get kind => EntityKind.point;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (!context.pointDisplay.showsMarker) return;
    final p = context.apply(position);
    sink.point(p.x, p.y, context.styleFor(props));
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(position.x, position.y, position.x, position.y);

  @override
  PointEntity withId(int id) =>
      PointEntity(id: id, props: props, position: position);

  @override
  PointEntity withProps(EntityProps props) =>
      PointEntity(id: id, props: props, position: position);

  @override
  PointEntity transformed(Mat3 matrix) =>
      PointEntity(id: id, props: props, position: matrix.transform(position));

  @override
  List<Vec2> grips() => [position];

  @override
  PointEntity withGrip(int index, Vec2 target) =>
      PointEntity(id: id, props: props, position: target);

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, position)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  Map<String, Object?> geometryToJson() => _$PointEntityToJson(this);
}
