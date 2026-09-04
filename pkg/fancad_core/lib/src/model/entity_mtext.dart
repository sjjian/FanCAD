part of 'entity.dart';

/// Multi-line, formatted text.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class MTextEntity extends CadEntity {
  const MTextEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
    required this.content,
    this.height = 2.5,
    this.rotation = 0,
    this.styleName = 'Standard',
    this.rectangleWidth = 0,
    this.attachment = 1,
  });

  static MTextEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => MTextEntity(
    id: id,
    props: props,
    position: _point(json['position']),
    content: json['text'] as String? ?? '',
    height: (json['height'] as num?)?.toDouble() ?? 2.5,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    styleName: json['style'] as String? ?? 'Standard',
    rectangleWidth: (json['rectangleWidth'] as num?)?.toDouble() ?? 0,
    attachment: (json['attachment'] as num?)?.toInt() ?? 1,
  );

  @JsonKey(toJson: vec2ToJson)
  final Vec2 position;

  /// Raw MTEXT content, which may still contain formatting codes such as
  /// `\P` and `{\fArial|b1;...}`.
  @JsonKey(name: 'text')
  final String content;
  @JsonKey()
  final double height;
  @JsonKey(toJson: omitZero)
  final double rotation;
  @JsonKey(name: 'style')
  final String styleName;
  @JsonKey(toJson: omitZero)
  final double rectangleWidth;

  /// AutoCAD attachment point, 1 = top-left through 9 = bottom-right.
  @JsonKey(toJson: _omitAttachment)
  final int attachment;

  /// Strips MTEXT inline formatting down to plain text for layout and search.
  String get plainText => stripMTextFormatting(content);

  TextHAlign get hAlign => switch ((attachment - 1) % 3) {
    0 => TextHAlign.left,
    1 => TextHAlign.center,
    _ => TextHAlign.right,
  };

  TextVAlign get vAlign => switch ((attachment - 1) ~/ 3) {
    0 => TextVAlign.top,
    1 => TextVAlign.middle,
    _ => TextVAlign.bottom,
  };

  @override
  EntityKind get kind => EntityKind.mtext;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (content.isEmpty) return;
    final runs = MTextLayout(measureWidth: context.measureWidth).layout(this);
    if (runs.isEmpty) return;
    final style = context.styleFor(props);
    for (final run in runs) {
      if (run.text.isEmpty && run.barFrom == null) continue;
      final local = run.origin - position;
      final origin = rotation.abs() < 1e-12
          ? run.origin
          : position + local.rotated(rotation);
      final runStyle = run.color == null
          ? style
          : style.copyWith(color: CadColor.indexed(run.color!));
      if (run.text.isNotEmpty) {
        emitStyledText(
          context: context,
          sink: sink,
          style: runStyle,
          text: expandDxfTextCodes(run.text),
          origin: origin,
          height: run.height,
          rotation: rotation,
          styleName: styleName,
          widthFactor: run.widthFactor,
          obliqueAngle: run.obliqueAngle,
          tracking: run.tracking,
          hAlign: run.hAlign ?? hAlign,
          vAlign: vAlign,
          anchor: TextAnchor.box,
          fontOverride: run.font.isEmpty ? null : run.font,
          underline: run.underline,
          overline: run.overline,
          strike: run.strike,
        );
      }
      final from = run.barFrom;
      final to = run.barTo;
      if (from != null && to != null) {
        final a = rotation.abs() < 1e-12
            ? from
            : position + (from - position).rotated(rotation);
        final b = rotation.abs() < 1e-12
            ? to
            : position + (to - position).rotated(rotation);
        sink.polyline(
          context.applyBuffer(Float64List.fromList([a.x, a.y, b.x, b.y])),
          runStyle,
        );
      }
    }
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) => sink.node(position);

  @override
  MTextEntity withId(int id) => MTextEntity(
    id: id,
    props: props,
    position: position,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    rectangleWidth: rectangleWidth,
    attachment: attachment,
  );

  @override
  MTextEntity withProps(EntityProps props) => MTextEntity(
    id: id,
    props: props,
    position: position,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    rectangleWidth: rectangleWidth,
    attachment: attachment,
  );

  MTextEntity withContent(String value) => MTextEntity(
    id: id,
    props: props,
    position: position,
    content: value,
    height: height,
    rotation: rotation,
    styleName: styleName,
    rectangleWidth: rectangleWidth,
    attachment: attachment,
  );

  @override
  MTextEntity transformed(Mat3 matrix) => MTextEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    content: content,
    height: height * matrix.meanScale,
    rotation: rotation + matrix.rotation,
    styleName: styleName,
    rectangleWidth: rectangleWidth * matrix.meanScale,
    attachment: attachment,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  MTextEntity withGrip(int index, Vec2 target) => MTextEntity(
    id: id,
    props: props,
    position: target,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    rectangleWidth: rectangleWidth,
    attachment: attachment,
  );

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, position)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  Map<String, Object?> geometryToJson() => _$MTextEntityToJson(this);
}
