part of 'entity.dart';

/// A concrete attribute value, usually produced by exploding an insert.
final class AttribEntity extends CadEntity {
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

  final Vec2 position;
  final String tag;
  final String value;
  final double height;
  final double rotation;
  final String styleName;
  final double widthFactor;
  final double obliqueAngle;
  final TextHAlign hAlign;
  final TextVAlign vAlign;
  final bool invisible;

  AttribEntity withValue(String value) => AttribEntity(
    id: id,
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
  EntityKind get kind => EntityKind.attrib;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (invisible || value.isEmpty) return;
    sink.text(
      composeEmittedText(
        context: context,
        text: expandDxfTextCodes(value),
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
  AttribEntity withId(int id) => AttribEntity(
    id: id,
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
  AttribEntity withProps(EntityProps props) => AttribEntity(
    id: id,
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
  AttribEntity transformed(Mat3 matrix) => AttribEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    tag: tag,
    value: value,
    height: height * matrix.meanScale,
    rotation: rotation + matrix.rotation,
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
  AttribEntity withGrip(int index, Vec2 target) => AttribEntity(
    id: id,
    props: props,
    position: target,
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
