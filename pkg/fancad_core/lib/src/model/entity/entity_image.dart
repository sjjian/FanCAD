part of 'entity.dart';

/// A referenced raster image.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class ImageEntity extends CadEntity {
  const ImageEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.reference,
    required this.origin,
    required this.uVector,
    required this.vVector,
  });

  static ImageEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => ImageEntity(
    id: id,
    props: props,
    reference: json['reference'] as String? ?? '',
    origin: _point(json['origin']),
    uVector: _point(json['u'], fallback: const Vec2(1, 0)),
    vVector: _point(json['v'], fallback: const Vec2(0, 1)),
  );

  @JsonKey()
  final String reference;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(name: 'u', toJson: vec2ToJson)
  final Vec2 uVector;
  @JsonKey(name: 'v', toJson: vec2ToJson)
  final Vec2 vVector;

  @override
  EntityKind get kind => EntityKind.image;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (emitAsPixel(
      context,
      sink,
      Bounds2.fromPoints([
        origin,
        origin + uVector,
        origin + uVector + vVector,
        origin + vVector,
      ]),
    )) {
      return;
    }
    sink.image(
      ImageGeometry(
        reference: reference,
        origin: context.apply(origin),
        uVector: context.transform.transformDirection(uVector),
        vVector: context.transform.transformDirection(vVector),
      ),
      context.styleFor(props),
    );
  }

  @override
  ImageEntity withId(int id) => ImageEntity(
    id: id,
    props: props,
    reference: reference,
    origin: origin,
    uVector: uVector,
    vVector: vVector,
  );

  @override
  ImageEntity withProps(EntityProps props) => ImageEntity(
    id: id,
    props: props,
    reference: reference,
    origin: origin,
    uVector: uVector,
    vVector: vVector,
  );

  @override
  ImageEntity transformed(Mat3 matrix) => ImageEntity(
    id: id,
    props: props,
    reference: reference,
    origin: matrix.transform(origin),
    uVector: matrix.transformDirection(uVector),
    vVector: matrix.transformDirection(vVector),
  );

  @override
  List<Vec2> grips() => [
    origin,
    origin + uVector,
    origin + uVector + vVector,
    origin + vVector,
  ];

  @override
  ImageEntity withGrip(int index, Vec2 target) => index == 0
      ? ImageEntity(
          id: id,
          props: props,
          reference: reference,
          origin: target,
          uVector: uVector,
          vVector: vVector,
        )
      : this;

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, origin)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  Map<String, Object?> geometryToJson() => _$ImageEntityToJson(this);
}
