part of 'entity.dart';

/// Single-line text.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class TextEntity extends CadEntity {
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
  final Vec2 position;
  @JsonKey(name: 'text')
  final String content;
  @JsonKey()
  final double height;
  @JsonKey(toJson: omitZero)
  final double rotation;
  @JsonKey(name: 'style')
  final String styleName;
  @JsonKey(toJson: omitOne)
  final double widthFactor;
  @JsonKey(name: 'oblique', toJson: omitZero)
  final double obliqueAngle;
  @JsonKey(toJson: _omitHAlign)
  final TextHAlign hAlign;
  @JsonKey(toJson: _omitVAlign)
  final TextVAlign vAlign;

  TextGeometry toGeometry(EmitContext context) => composeEmittedText(
    context: context,
    text: expandDxfTextCodes(content),
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
      text: expandDxfTextCodes(content),
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
  TextEntity withId(int id) => TextEntity(
    id: id,
    props: props,
    position: position,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  TextEntity withProps(EntityProps props) => TextEntity(
    id: id,
    props: props,
    position: position,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  TextEntity withContent(String value) => TextEntity(
    id: id,
    props: props,
    position: position,
    content: value,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  TextEntity transformed(Mat3 matrix) => TextEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    content: content,
    height: height * matrix.meanScale,
    rotation: rotation + matrix.rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  TextEntity withGrip(int index, Vec2 target) => TextEntity(
    id: id,
    props: props,
    position: target,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

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
