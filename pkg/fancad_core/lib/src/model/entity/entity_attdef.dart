part of 'entity.dart';

/// An attribute definition that lives in a block (ATTDEF).
///
/// Title blocks and schedules are blocks whose variable fields are these
/// definitions. Inserting the block copies each tag's current value onto the
/// reference; editing the definition itself still shows the default.
final class AttdefEntity extends CadEntity implements TextLike {
  const AttdefEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
    required this.tag,
    this.prompt = '',
    this.defaultValue = '',
    this.height = 2.5,
    this.rotation = 0,
    this.styleName = 'Standard',
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
    this.invisible = false,
    this.constant = false,
    this.verify = false,
    this.preset = false,
  });

  static AttdefEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => AttdefEntity(
    id: id,
    props: props,
    position: _point(json['position']),
    tag: json['tag'] as String? ?? '',
    prompt: json['prompt'] as String? ?? '',
    defaultValue: json['text'] as String? ?? '',
    height: (json['height'] as num?)?.toDouble() ?? 2.5,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    styleName: json['style'] as String? ?? 'Standard',
    widthFactor: (json['widthFactor'] as num?)?.toDouble() ?? 1,
    obliqueAngle: (json['oblique'] as num?)?.toDouble() ?? 0,
    hAlign: _enumOf(TextHAlign.values, json['hAlign'], TextHAlign.left),
    vAlign: _enumOf(TextVAlign.values, json['vAlign'], TextVAlign.baseline),
    invisible: json['invisible'] as bool? ?? false,
    constant: json['constant'] as bool? ?? false,
    verify: json['verify'] as bool? ?? false,
    preset: json['preset'] as bool? ?? false,
  );

  @override
  final Vec2 position;
  final String tag;
  final String prompt;
  final String defaultValue;
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
  final bool constant;
  final bool verify;
  final bool preset;

  int get flags =>
      (invisible ? 1 : 0) |
      (constant ? 2 : 0) |
      (verify ? 4 : 0) |
      (preset ? 8 : 0);

  bool get asksOnInsert => !constant && !preset;

  String get displayText => defaultValue.isEmpty ? tag : defaultValue;

  AttribEntity toAttrib(String value) => AttribEntity(
    id: 0,
    props: props,
    position: position,
    tag: tag,
    value: value,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
    invisible: invisible,
  );

  @override
  EntityKind get kind => EntityKind.attdef;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final throughInsert = context.attributeValues != null;
    if (throughInsert && invisible) return;
    final text = throughInsert
        ? (context.attributeValues![tag] ?? defaultValue)
        : displayText;
    if (text.isEmpty) return;
    emitStyledText(
      context: context,
      sink: sink,
      style: context.styleFor(props),
      text: expandDxfTextCodes(text),
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

  AttdefEntity copyWith({
    int? id,
    EntityProps? props,
    Vec2? position,
    String? tag,
    String? prompt,
    String? defaultValue,
    double? height,
    double? rotation,
    String? styleName,
    double? widthFactor,
    double? obliqueAngle,
    TextHAlign? hAlign,
    TextVAlign? vAlign,
    bool? invisible,
    bool? constant,
    bool? verify,
    bool? preset,
  }) => AttdefEntity(
    id: id ?? this.id,
    props: props ?? this.props,
    position: position ?? this.position,
    tag: tag ?? this.tag,
    prompt: prompt ?? this.prompt,
    defaultValue: defaultValue ?? this.defaultValue,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    styleName: styleName ?? this.styleName,
    widthFactor: widthFactor ?? this.widthFactor,
    obliqueAngle: obliqueAngle ?? this.obliqueAngle,
    hAlign: hAlign ?? this.hAlign,
    vAlign: vAlign ?? this.vAlign,
    invisible: invisible ?? this.invisible,
    constant: constant ?? this.constant,
    verify: verify ?? this.verify,
    preset: preset ?? this.preset,
  );

  @override
  AttdefEntity withId(int id) => copyWith(id: id);

  @override
  AttdefEntity withProps(EntityProps props) => copyWith(props: props);

  @override
  String get content => defaultValue;

  @override
  AttdefEntity withContent(String content) => copyWith(defaultValue: content);

  @override
  AttdefEntity withHeight(double height) => copyWith(height: height);

  @override
  AttdefEntity withRotation(double radians) => copyWith(rotation: radians);

  @override
  AttdefEntity withStyleName(String styleName) =>
      copyWith(styleName: styleName);

  @override
  AttdefEntity withWidthFactor(double widthFactor) =>
      copyWith(widthFactor: widthFactor);

  @override
  AttdefEntity withObliqueAngle(double radians) =>
      copyWith(obliqueAngle: radians);

  @override
  double? get columnWidth => null;

  @override
  AttdefEntity? withColumnWidth(double width) => null;

  @override
  AttdefEntity transformed(Mat3 matrix) => AttdefEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    tag: tag,
    prompt: prompt,
    defaultValue: defaultValue,
    height: height * matrix.meanScale,
    rotation: matrix.transformAngle(rotation),
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
    invisible: invisible,
    constant: constant,
    verify: verify,
    preset: preset,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  AttdefEntity withGrip(int index, Vec2 target) => copyWith(position: target);

  @override
  Map<String, Object?> geometryToJson() => {
    'position': vec2ToJson(position),
    'tag': tag,
    if (prompt.isNotEmpty) 'prompt': prompt,
    if (defaultValue.isNotEmpty) 'text': defaultValue,
    'height': height,
    if (rotation != 0) 'rotation': rotation,
    if (styleName != 'Standard') 'style': styleName,
    if (widthFactor != 1) 'widthFactor': widthFactor,
    if (obliqueAngle != 0) 'oblique': obliqueAngle,
    if (hAlign != TextHAlign.left) 'hAlign': hAlign.name,
    if (vAlign != TextVAlign.baseline) 'vAlign': vAlign.name,
    if (invisible) 'invisible': true,
    if (constant) 'constant': true,
    if (verify) 'verify': true,
    if (preset) 'preset': true,
  };
}
