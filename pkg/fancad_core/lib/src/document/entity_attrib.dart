part of 'entity.dart';

/// A concrete attribute value, usually produced by exploding an insert.
final class AttribEntity extends CadEntity implements TextLike {
  const AttribEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
    required this.tag,
    required this.value,
    this.height = 2.5,
    this.rotation = 0,
    this.styleName = 'Standard',
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
    this.invisible = false,
  });

  static AttribEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => AttribEntity(
    id: id,
    props: props,
    position: _point(json['position']),
    tag: json['tag'] as String? ?? '',
    value: json['text'] as String? ?? '',
    height: (json['height'] as num?)?.toDouble() ?? 2.5,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    styleName: json['style'] as String? ?? 'Standard',
    widthFactor: (json['widthFactor'] as num?)?.toDouble() ?? 1,
    obliqueAngle: (json['oblique'] as num?)?.toDouble() ?? 0,
    hAlign: _enumOf(TextHAlign.values, json['hAlign'], TextHAlign.left),
    vAlign: _enumOf(TextVAlign.values, json['vAlign'], TextVAlign.baseline),
    invisible: json['invisible'] as bool? ?? false,
  );

  @override
  final Vec2 position;
  final String tag;
  final String value;
  @override
  final double height;
  @override
  final double rotation;
  @override
  final String styleName;
  @override
  final double widthFactor;
  @override
  final double obliqueAngle;
  final TextHAlign hAlign;
  final TextVAlign vAlign;
  final bool invisible;

  AttribEntity copyWith({
    int? id,
    EntityProps? props,
    Vec2? position,
    String? tag,
    String? value,
    double? height,
    double? rotation,
    String? styleName,
    double? widthFactor,
    double? obliqueAngle,
    TextHAlign? hAlign,
    TextVAlign? vAlign,
    bool? invisible,
  }) => AttribEntity(
    id: id ?? this.id,
    props: props ?? this.props,
    position: position ?? this.position,
    tag: tag ?? this.tag,
    value: value ?? this.value,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    styleName: styleName ?? this.styleName,
    widthFactor: widthFactor ?? this.widthFactor,
    obliqueAngle: obliqueAngle ?? this.obliqueAngle,
    hAlign: hAlign ?? this.hAlign,
    vAlign: vAlign ?? this.vAlign,
    invisible: invisible ?? this.invisible,
  );

  AttribEntity withValue(String value) => copyWith(value: value);

  @override
  String get content => value;

  @override
  AttribEntity withContent(String content) => copyWith(value: content);

  @override
  AttribEntity withHeight(double height) => copyWith(height: height);

  @override
  AttribEntity withRotation(double radians) => copyWith(rotation: radians);

  @override
  AttribEntity withStyleName(String styleName) =>
      copyWith(styleName: styleName);

  @override
  AttribEntity withWidthFactor(double widthFactor) =>
      copyWith(widthFactor: widthFactor);

  @override
  AttribEntity withObliqueAngle(double radians) =>
      copyWith(obliqueAngle: radians);

  @override
  double? get columnWidth => null;

  @override
  AttribEntity? withColumnWidth(double width) => null;

  @override
  EntityKind get kind => EntityKind.attrib;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (invisible || value.isEmpty) return;
    emitStyledText(
      context: context,
      sink: sink,
      style: context.styleFor(props),
      text: expandDxfTextCodes(value),
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

  @override
  AttribEntity withId(int id) => copyWith(id: id);

  @override
  AttribEntity withProps(EntityProps props) => copyWith(props: props);

  @override
  AttribEntity transformed(Mat3 matrix) => AttribEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    tag: tag,
    value: value,
    height: height * matrix.meanScale,
    rotation: matrix.transformAngle(rotation),
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
    invisible: invisible,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  AttribEntity withGrip(int index, Vec2 target) => copyWith(position: target);

  @override
  Map<String, Object?> geometryToJson() => {
    'position': vec2ToJson(position),
    'tag': tag,
    if (value.isNotEmpty) 'text': value,
    'height': height,
    if (rotation != 0) 'rotation': rotation,
    if (styleName != 'Standard') 'style': styleName,
    if (widthFactor != 1) 'widthFactor': widthFactor,
    if (obliqueAngle != 0) 'oblique': obliqueAngle,
    if (hAlign != TextHAlign.left) 'hAlign': hAlign.name,
    if (vAlign != TextVAlign.baseline) 'vAlign': vAlign.name,
    if (invisible) 'invisible': true,
  };
}
