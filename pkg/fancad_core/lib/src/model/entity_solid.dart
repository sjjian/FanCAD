part of 'entity.dart';

/// A filled triangle or quadrilateral (SOLID / 3DFACE).
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class SolidEntity extends CadEntity {
  const SolidEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.corners,
  });

  static SolidEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => SolidEntity(id: id, props: props, corners: _pointList(json['corners']));

  @JsonKey(toJson: vec2ListToJson)
  final List<Vec2> corners;

  @override
  EntityKind get kind => EntityKind.solid;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (corners.length < 3) return;
    final buffer = Float64List(corners.length * 2);
    for (var i = 0; i < corners.length; i++) {
      final p = context.apply(corners[i]);
      buffer[i * 2] = p.x;
      buffer[i * 2 + 1] = p.y;
    }
    sink.fill(buffer, context.styleFor(props));
  }

  @override
  SolidEntity withId(int id) =>
      SolidEntity(id: id, props: props, corners: corners);

  @override
  SolidEntity withProps(EntityProps props) =>
      SolidEntity(id: id, props: props, corners: corners);

  @override
  SolidEntity transformed(Mat3 matrix) => SolidEntity(
    id: id,
    props: props,
    corners: [for (final corner in corners) matrix.transform(corner)],
  );

  @override
  List<Vec2> grips() => corners;

  @override
  SolidEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= corners.length) return this;
    final updated = [...corners];
    updated[index] = target;
    return SolidEntity(id: id, props: props, corners: updated);
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) =>
      stretchIndependentGrips(window, delta);

  @override
  Map<String, Object?> geometryToJson() => _$SolidEntityToJson(this);
}
