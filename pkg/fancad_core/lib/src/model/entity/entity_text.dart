part of 'entity.dart';

/// Single-line text.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class TextEntity extends CadEntity implements TextLike {
  const TextEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
    required this.content,
    this.height = 2.5,
    this.rotation = 0,
    this.styleName = 'Standard',
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
  });

  static TextEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => TextEntity(
    id: id,
    props: props,
    position: _point(json['position']),
    content: json['text'] as String? ?? '',
    height: (json['height'] as num?)?.toDouble() ?? 2.5,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    styleName: json['style'] as String? ?? 'Standard',
    widthFactor: (json['widthFactor'] as num?)?.toDouble() ?? 1,
    obliqueAngle: (json['oblique'] as num?)?.toDouble() ?? 0,
    hAlign: _enumOf(TextHAlign.values, json['hAlign'], TextHAlign.left),
    vAlign: _enumOf(TextVAlign.values, json['vAlign'], TextVAlign.baseline),
  );

  @JsonKey(toJson: vec2ToJson)
  @override
  final Vec2 position;
  @JsonKey(name: 'text')
  @override
  final String content;
  @JsonKey()
  @override
  final double height;
  @JsonKey(toJson: omitZero)
  @override
  final double rotation;
  @JsonKey(name: 'style')
  @override
  final String styleName;
  @JsonKey(toJson: omitOne)
  @override
  final double widthFactor;
  @JsonKey(name: 'oblique', toJson: omitZero)
  @override
  final double obliqueAngle;
  @JsonKey(toJson: _omitHAlign)
  final TextHAlign hAlign;
  @JsonKey(toJson: _omitVAlign)
  final TextVAlign vAlign;

  TextGeometry toGeometry(EmitContext context) => composeEmittedText(
    context: context,
    text: decodeDrawnText(content),
    origin: position,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  EntityKind get kind => EntityKind.text;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (content.isEmpty) return;
    emitStyledText(
      context: context,
      sink: sink,
      style: context.styleFor(props),
      text: decodeDrawnText(content),
      origin: position,
      height: height,
      rotation: rotation,
      styleName: styleName,
      widthFactor: widthFactor,
      obliqueAngle: obliqueAngle,
      hAlign: hAlign,
      vAlign: vAlign,
    );
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) => sink.node(position);

  TextEntity copyWith({
    int? id,
    EntityProps? props,
    Vec2? position,
    String? content,
    double? height,
    double? rotation,
    String? styleName,
    double? widthFactor,
    double? obliqueAngle,
    TextHAlign? hAlign,
    TextVAlign? vAlign,
  }) => TextEntity(
    id: id ?? this.id,
    props: props ?? this.props,
    position: position ?? this.position,
    content: content ?? this.content,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    styleName: styleName ?? this.styleName,
    widthFactor: widthFactor ?? this.widthFactor,
    obliqueAngle: obliqueAngle ?? this.obliqueAngle,
    hAlign: hAlign ?? this.hAlign,
    vAlign: vAlign ?? this.vAlign,
  );

  @override
  TextEntity withId(int id) => copyWith(id: id);

  @override
  TextEntity withProps(EntityProps props) => copyWith(props: props);

  @override
  TextEntity withContent(String content) => copyWith(content: content);

  @override
  TextEntity withHeight(double height) => copyWith(height: height);

  @override
  TextEntity withRotation(double radians) => copyWith(rotation: radians);

  @override
  TextEntity withStyleName(String styleName) => copyWith(styleName: styleName);

  @override
  TextEntity withWidthFactor(double widthFactor) =>
      copyWith(widthFactor: widthFactor);

  @override
  TextEntity withObliqueAngle(double radians) =>
      copyWith(obliqueAngle: radians);

  @override
  double? get columnWidth => null;

  @override
  TextEntity? withColumnWidth(double width) => null;

  @override
  TextEntity transformed(Mat3 matrix) => TextEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    content: content,
    height: height * matrix.meanScale,
    rotation: matrix.transformAngle(rotation),
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  TextEntity withGrip(int index, Vec2 target) =>
      index == 0 ? copyWith(position: target) : this;

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, position)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  Map<String, Object?> geometryToJson() => _$TextEntityToJson(this);
}
