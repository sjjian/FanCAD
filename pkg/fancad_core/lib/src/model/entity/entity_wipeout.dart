part of 'entity.dart';

/// A WIPEOUT mask: a polygon in image coordinates that hides what is behind it.
///
/// The entity keeps the DWG representation rather than a baked drawing-space
/// polygon, so a round trip preserves arbitrary clip paths exactly. The mask
/// spans [origin] + [uVector] * x + [vVector] * y for each clip vertex.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class WipeoutEntity extends CadEntity {
  const WipeoutEntity({
    required super.id,
    super.props = EntityProps.defaults,
    this.origin = const Vec2(0, 0),
    this.uVector = const Vec2(1, 0),
    this.vVector = const Vec2(0, 1),
    required this.clipVertices,
    this.frame = true,
  });

  static WipeoutEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => WipeoutEntity(
    id: id,
    props: props,
    origin: _point(json['origin']),
    uVector: _point(json['u'], fallback: const Vec2(1, 0)),
    vVector: _point(json['v'], fallback: const Vec2(0, 1)),
    clipVertices: _pointBuffer(json['clip']),
    frame: json['frame'] as bool? ?? true,
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(name: 'u', toJson: vec2ToJson)
  final Vec2 uVector;
  @JsonKey(name: 'v', toJson: vec2ToJson)
  final Vec2 vVector;

  /// Interleaved `[x, y, ...]` clip vertices in image coordinates.
  @JsonKey(toJson: pointBufferToJson)
  final Float64List clipVertices;

  /// Whether the mask boundary is drawn.
  @JsonKey()
  final bool frame;

  int get vertexCount => clipVertices.length ~/ 2;

  Vec2 vertexAt(int index) =>
      origin +
      uVector * clipVertices[index * 2] +
      vVector * clipVertices[index * 2 + 1];

  @override
  EntityKind get kind => EntityKind.wipeout;

  Float64List _drawingPoints(Mat3? matrix) {
    final out = Float64List(clipVertices.length);
    for (var i = 0; i < vertexCount; i++) {
      final point = vertexAt(i);
      final transformed = matrix == null ? point : matrix.transform(point);
      out[i * 2] = transformed.x;
      out[i * 2 + 1] = transformed.y;
    }
    return out;
  }

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (vertexCount < 2) return;
    final points = _drawingPoints(context.transform);
    if (emitAsPixel(context, sink, Bounds2.fromXY(points))) return;
    final style = context.styleFor(props);
    sink.fill(points, style);
    if (frame) sink.polyline(points, style, closed: true);
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    if (vertexCount == 0) {
      return Bounds2.fromPoints([
        origin,
        origin + uVector,
        origin + vVector,
        origin + uVector + vVector,
      ]);
    }
    return Bounds2.fromXY(_drawingPoints(null));
  }

  @override
  WipeoutEntity withId(int id) => WipeoutEntity(
    id: id,
    props: props,
    origin: origin,
    uVector: uVector,
    vVector: vVector,
    clipVertices: clipVertices,
    frame: frame,
  );

  @override
  WipeoutEntity withProps(EntityProps props) => WipeoutEntity(
    id: id,
    props: props,
    origin: origin,
    uVector: uVector,
    vVector: vVector,
    clipVertices: clipVertices,
    frame: frame,
  );

  @override
  WipeoutEntity transformed(Mat3 matrix) => WipeoutEntity(
    id: id,
    props: props,
    origin: matrix.transform(origin),
    uVector: matrix.transformDirection(uVector),
    vVector: matrix.transformDirection(vVector),
    clipVertices: clipVertices,
    frame: frame,
  );

  @override
  List<Vec2> grips() => [for (var i = 0; i < vertexCount; i++) vertexAt(i)];

  @override
  WipeoutEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= vertexCount) return this;
    final det = uVector.x * vVector.y - uVector.y * vVector.x;
    if (det.abs() < 1e-20) return this;
    final d = target - origin;
    final u = (d.x * vVector.y - d.y * vVector.x) / det;
    final v = (uVector.x * d.y - uVector.y * d.x) / det;
    final out = Float64List.fromList(clipVertices);
    out[index * 2] = u;
    out[index * 2 + 1] = v;
    return WipeoutEntity(
      id: id,
      props: props,
      origin: origin,
      uVector: uVector,
      vVector: vVector,
      clipVertices: out,
      frame: frame,
    );
  }

  @override
  Map<String, Object?> geometryToJson() => _$WipeoutEntityToJson(this);
}
