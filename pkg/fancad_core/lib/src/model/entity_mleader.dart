part of 'entity.dart';

/// A MULTILEADER: one or more arrowed paths plus a single text note.
///
/// AutoCAD's full MLEADER style table is not modelled. This is enough to
/// import a process-drawing callout, grip-edit the vertices and the note,
/// and write it back.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class MLeaderEntity extends CadEntity {
  const MLeaderEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.vertices,
    this.pathLengths = const [],
    this.hasArrowHead = true,
    this.content = '',
    this.textPosition = const Vec2.zero(),
    this.textHeight = 2.5,
    this.textRotation = 0,
    this.styleName = 'Standard',
  });

  static MLeaderEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => MLeaderEntity(
    id: id,
    props: props,
    vertices: _pointBuffer(json['vertices']),
    pathLengths: _idList(json['pathLengths']),
    hasArrowHead: json['arrowHead'] as bool? ?? true,
    content: json['text'] as String? ?? '',
    textPosition: _point(json['textPosition']),
    textHeight: (json['height'] as num?)?.toDouble() ?? 2.5,
    textRotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    styleName: json['style'] as String? ?? 'Standard',
  );

  /// All leader paths concatenated as interleaved `[x, y, ...]`.
  @JsonKey(toJson: pointBufferToJson)
  final Float64List vertices;

  /// Point count per path. Empty means a single path covering [vertices].
  @JsonKey(toJson: idListToJsonIfNotEmpty)
  final List<int> pathLengths;
  @JsonKey(name: 'arrowHead')
  final bool hasArrowHead;
  @JsonKey(name: 'text', toJson: omitEmptyString)
  final String content;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 textPosition;
  @JsonKey(name: 'height', toJson: omitZero)
  final double textHeight;
  @JsonKey(name: 'rotation', toJson: omitZero)
  final double textRotation;
  @JsonKey(name: 'style')
  final String styleName;

  @override
  EntityKind get kind => EntityKind.mleader;

  Iterable<(int start, int count)> _paths() sync* {
    if (pathLengths.isEmpty) {
      yield (0, vertices.length ~/ 2);
      return;
    }
    var start = 0;
    for (final count in pathLengths) {
      yield (start, count);
      start += count;
    }
  }

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final style = context.styleFor(props);
    for (final (start, count) in _paths()) {
      if (count < 2) continue;
      final from = start * 2;
      final to = from + count * 2;
      if (to > vertices.length) break;
      final xy = context.applyBuffer(
        Float64List.sublistView(vertices, from, to),
      );
      sink.polyline(xy, style);
      if (!hasArrowHead) continue;
      _emitArrowHead(context, sink, style, xy);
    }
    if (content.isEmpty || textHeight <= 0) return;
    sink.text(
      composeEmittedText(
        context: context,
        text: stripMTextFormatting(content),
        origin: textPosition,
        height: textHeight,
        rotation: textRotation,
        styleName: styleName,
        vAlign: TextVAlign.middle,
      ),
      style,
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    var box = vertices.length >= 2
        ? Bounds2.fromXY(vertices)
        : const Bounds2.empty();
    if (content.isNotEmpty && textHeight > 0) {
      box = box.expandToInclude(textPosition.x, textPosition.y);
    }
    return box;
  }

  @override
  MLeaderEntity withId(int id) => MLeaderEntity(
    id: id,
    props: props,
    vertices: vertices,
    pathLengths: pathLengths,
    hasArrowHead: hasArrowHead,
    content: content,
    textPosition: textPosition,
    textHeight: textHeight,
    textRotation: textRotation,
    styleName: styleName,
  );

  @override
  MLeaderEntity withProps(EntityProps props) => MLeaderEntity(
    id: id,
    props: props,
    vertices: vertices,
    pathLengths: pathLengths,
    hasArrowHead: hasArrowHead,
    content: content,
    textPosition: textPosition,
    textHeight: textHeight,
    textRotation: textRotation,
    styleName: styleName,
  );

  @override
  MLeaderEntity transformed(Mat3 matrix) => MLeaderEntity(
    id: id,
    props: props,
    vertices: _transformBuffer(vertices, matrix),
    pathLengths: pathLengths,
    hasArrowHead: hasArrowHead,
    content: content,
    textPosition: matrix.transform(textPosition),
    textHeight: textHeight * matrix.meanScale,
    textRotation: textRotation + matrix.rotation,
    styleName: styleName,
  );

  @override
  List<Vec2> grips() => [
    for (var i = 0; i < vertices.length ~/ 2; i++)
      Vec2(vertices[i * 2], vertices[i * 2 + 1]),
    textPosition,
  ];

  @override
  MLeaderEntity withGrip(int index, Vec2 target) {
    final vertexCount = vertices.length ~/ 2;
    if (index == vertexCount) {
      return MLeaderEntity(
        id: id,
        props: props,
        vertices: vertices,
        pathLengths: pathLengths,
        hasArrowHead: hasArrowHead,
        content: content,
        textPosition: target,
        textHeight: textHeight,
        textRotation: textRotation,
        styleName: styleName,
      );
    }
    if (index < 0 || index >= vertexCount) return this;
    final out = Float64List.fromList(vertices);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return MLeaderEntity(
      id: id,
      props: props,
      vertices: out,
      pathLengths: pathLengths,
      hasArrowHead: hasArrowHead,
      content: content,
      textPosition: textPosition,
      textHeight: textHeight,
      textRotation: textRotation,
      styleName: styleName,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) =>
      stretchIndependentGrips(window, delta);

  @override
  Map<String, Object?> geometryToJson() => _$MLeaderEntityToJson(this);
}
