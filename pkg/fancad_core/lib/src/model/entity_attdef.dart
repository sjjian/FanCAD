part of 'entity.dart';

/// An attribute definition that lives in a block (ATTDEF).
///
/// Title blocks and schedules are blocks whose variable fields are these
/// definitions. Inserting the block copies each tag's current value onto the
/// reference; editing the definition itself still shows the default.
final class AttdefEntity extends CadEntity {
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

  final Vec2 position;
  final String tag;
  final String prompt;
  final String defaultValue;
  final double height;
  final double rotation;
  final String styleName;
  final double widthFactor;
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
    sink.text(
      composeEmittedText(
        context: context,
        text: expandDxfTextCodes(text),
        origin: position,
        height: height,
        rotation: rotation,
        styleName: styleName,
        widthFactor: widthFactor,
        obliqueAngle: obliqueAngle,
        hAlign: hAlign,
        vAlign: vAlign,
      ),
      context.styleFor(props),
    );
  }

  @override
  AttdefEntity withId(int id) => AttdefEntity(
    id: id,
    props: props,
    position: position,
    tag: tag,
    prompt: prompt,
    defaultValue: defaultValue,
    height: height,
    rotation: rotation,
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
  AttdefEntity withProps(EntityProps props) => AttdefEntity(
    id: id,
    props: props,
    position: position,
    tag: tag,
    prompt: prompt,
    defaultValue: defaultValue,
    height: height,
    rotation: rotation,
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
  AttdefEntity transformed(Mat3 matrix) => AttdefEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    tag: tag,
    prompt: prompt,
    defaultValue: defaultValue,
    height: height * matrix.meanScale,
    rotation: rotation + matrix.rotation,
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
  AttdefEntity withGrip(int index, Vec2 target) => AttdefEntity(
    id: id,
    props: props,
    position: target,
    tag: tag,
    prompt: prompt,
    defaultValue: defaultValue,
    height: height,
    rotation: rotation,
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
