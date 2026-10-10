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
final class MLeaderEntity extends CadEntity implements TextLike {
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
    this.attachment = 4,
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
    attachment: (json['attachment'] as num?)?.toInt() ?? 4,
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
  @override
  final String content;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 textPosition;
  @JsonKey(name: 'height', toJson: omitZero)
  final double textHeight;
  @JsonKey(name: 'rotation', toJson: omitZero)
  final double textRotation;
  @JsonKey(name: 'style')
  @override
  final String styleName;

  /// MTEXT attachment (1 = top-left … 9 = bottom-right). MULTILEADER stores
  /// left/center/right as 1/2/3; import maps those onto the middle row (4/5/6)
  /// so the landing sits on the note instead of above it.
  @JsonKey(toJson: _omitMLeaderAttachment)
  final int attachment;

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
    if (emitAsPixel(context, sink, computeBounds())) return;
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
    // The note is MTEXT (inline `\F宋体`, `\P`, …). Drawing it as STYLE
    // Standard / txt.shx drops every CJK glyph once the SHX face is loaded.
    // The landing is the attachment corner, so a hugging right note has to
    // sit left of that point — ordinary MTEXT keeps width-0 on the left.
    _emitMText(
      MTextEntity(
        id: id,
        props: props,
        position: textPosition,
        content: content,
        height: textHeight,
        rotation: textRotation,
        styleName: styleName,
        attachment: attachment,
      ),
      context,
      sink,
      hugToAttachment: true,
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

  MLeaderEntity copyWith({
    int? id,
    EntityProps? props,
    Float64List? vertices,
    List<int>? pathLengths,
    bool? hasArrowHead,
    String? content,
    Vec2? textPosition,
    double? textHeight,
    double? textRotation,
    String? styleName,
    int? attachment,
  }) => MLeaderEntity(
    id: id ?? this.id,
    props: props ?? this.props,
    vertices: vertices ?? this.vertices,
    pathLengths: pathLengths ?? this.pathLengths,
    hasArrowHead: hasArrowHead ?? this.hasArrowHead,
    content: content ?? this.content,
    textPosition: textPosition ?? this.textPosition,
    textHeight: textHeight ?? this.textHeight,
    textRotation: textRotation ?? this.textRotation,
    styleName: styleName ?? this.styleName,
    attachment: attachment ?? this.attachment,
  );

  @override
  MLeaderEntity withId(int id) => copyWith(id: id);

  @override
  MLeaderEntity withProps(EntityProps props) => copyWith(props: props);

  @override
  Vec2 get position => textPosition;

  @override
  double get height => textHeight;

  @override
  double get rotation => textRotation;

  @override
  MLeaderEntity withContent(String content) => copyWith(content: content);

  @override
  MLeaderEntity withHeight(double height) => copyWith(textHeight: height);

  @override
  MLeaderEntity withRotation(double radians) => copyWith(textRotation: radians);

  @override
  MLeaderEntity withStyleName(String styleName) =>
      copyWith(styleName: styleName);

  @override
  double? get widthFactor => null;

  @override
  MLeaderEntity? withWidthFactor(double widthFactor) => null;

  @override
  double? get obliqueAngle => null;

  @override
  MLeaderEntity? withObliqueAngle(double radians) => null;

  @override
  double? get columnWidth => null;

  @override
  MLeaderEntity? withColumnWidth(double width) => null;

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
    textRotation: matrix.transformAngle(textRotation),
    styleName: styleName,
    attachment: attachment,
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
    if (index == vertexCount) return copyWith(textPosition: target);
    if (index < 0 || index >= vertexCount) return this;
    final out = Float64List.fromList(vertices);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return copyWith(vertices: out);
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) =>
      stretchIndependentGrips(window, delta);

  @override
  Map<String, Object?> geometryToJson() => _$MLeaderEntityToJson(this);
}
