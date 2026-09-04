part of 'entity.dart';

/// A leader line, optionally with an arrow head.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class LeaderEntity extends CadEntity {
  const LeaderEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.vertices,
    this.hasArrowHead = true,
    this.styleName = 'Standard',
  });

  static LeaderEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => LeaderEntity(
    id: id,
    props: props,
    vertices: _pointBuffer(json['vertices']),
    hasArrowHead: json['arrowHead'] as bool? ?? true,
    styleName: json['style'] as String? ?? 'Standard',
  );

  /// Interleaved `[x, y, ...]`.
  @JsonKey(toJson: pointBufferToJson)
  final Float64List vertices;
  @JsonKey(name: 'arrowHead')
  final bool hasArrowHead;
  @JsonKey(name: 'style')
  final String styleName;

  @override
  EntityKind get kind => EntityKind.leader;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (vertices.length < 4) return;
    if (emitAsPixel(context, sink, Bounds2.fromXY(vertices))) return;
    final style = context.styleFor(props);
    final xy = context.applyBuffer(vertices);
    sink.polyline(xy, style);
    if (!hasArrowHead) return;
    final tip = Vec2(xy[0], xy[1]);
    final next = Vec2(xy[2], xy[3]);
    final dir = next - tip;
    final length = dir.length;
    if (length < 1e-9) return;
    final unit = dir / length;
    final scale = context.transform.isIdentity
        ? 1.0
        : context.transform.meanScale;
    final size = math.min(2.5 * scale, length * 0.4);
    if (size < 1e-9) return;
    final left = tip + unit * size + unit.perpendicular * (size * 0.35);
    final right = tip + unit * size - unit.perpendicular * (size * 0.35);
    sink.fill(
      Float64List.fromList([tip.x, tip.y, left.x, left.y, right.x, right.y]),
      style,
    );
  }

  @override
  LeaderEntity withId(int id) => LeaderEntity(
    id: id,
    props: props,
    vertices: vertices,
    hasArrowHead: hasArrowHead,
    styleName: styleName,
  );

  @override
  LeaderEntity withProps(EntityProps props) => LeaderEntity(
    id: id,
    props: props,
    vertices: vertices,
    hasArrowHead: hasArrowHead,
    styleName: styleName,
  );

  @override
  LeaderEntity transformed(Mat3 matrix) => LeaderEntity(
    id: id,
    props: props,
    vertices: _transformBuffer(vertices, matrix),
    hasArrowHead: hasArrowHead,
    styleName: styleName,
  );

  @override
  List<Vec2> grips() => [
    for (var i = 0; i < vertices.length ~/ 2; i++)
      Vec2(vertices[i * 2], vertices[i * 2 + 1]),
  ];

  @override
  LeaderEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= vertices.length ~/ 2) return this;
    final out = Float64List.fromList(vertices);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return LeaderEntity(
      id: id,
      props: props,
      vertices: out,
      hasArrowHead: hasArrowHead,
      styleName: styleName,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) =>
      stretchIndependentGrips(window, delta);

  @override
  Map<String, Object?> geometryToJson() => _$LeaderEntityToJson(this);
}
