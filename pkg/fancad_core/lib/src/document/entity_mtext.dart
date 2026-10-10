part of 'entity.dart';

/// Multi-line, formatted text.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class MTextEntity extends CadEntity implements TextLike {
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
  @override
  final Vec2 position;

  /// Raw MTEXT content, which may still contain formatting codes such as
  /// `\P` and `{\fArial|b1;...}`.
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
    _emitMText(this, context, sink);
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) => sink.node(position);

  MTextEntity copyWith({
    int? id,
    EntityProps? props,
    Vec2? position,
    String? content,
    double? height,
    double? rotation,
    String? styleName,
    double? rectangleWidth,
    int? attachment,
  }) => MTextEntity(
    id: id ?? this.id,
    props: props ?? this.props,
    position: position ?? this.position,
    content: content ?? this.content,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    styleName: styleName ?? this.styleName,
    rectangleWidth: rectangleWidth ?? this.rectangleWidth,
    attachment: attachment ?? this.attachment,
  );

  @override
  MTextEntity withId(int id) => copyWith(id: id);

  @override
  MTextEntity withProps(EntityProps props) => copyWith(props: props);

  @override
  MTextEntity withContent(String content) => copyWith(content: content);

  @override
  MTextEntity withHeight(double height) => copyWith(height: height);

  @override
  MTextEntity withRotation(double radians) => copyWith(rotation: radians);

  @override
  MTextEntity withStyleName(String styleName) => copyWith(styleName: styleName);

  @override
  double? get widthFactor => null;

  @override
  MTextEntity? withWidthFactor(double widthFactor) => null;

  @override
  double? get obliqueAngle => null;

  @override
  MTextEntity? withObliqueAngle(double radians) => null;

  @override
  double get columnWidth => rectangleWidth;

  @override
  MTextEntity withColumnWidth(double width) => copyWith(rectangleWidth: width);

  @override
  MTextEntity transformed(Mat3 matrix) => MTextEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    content: content,
    height: height * matrix.meanScale,
    rotation: matrix.transformAngle(rotation),
    styleName: styleName,
    rectangleWidth: rectangleWidth * matrix.meanScale,
    attachment: attachment,
  );

  /// Column width used by grips. A zero [rectangleWidth] is unbounded MTEXT;
  /// the estimate matches [TextGeometry.estimatedBounds] so the first drag
  /// writes a real width instead of collapsing the box.
  double get _columnWidth {
    if (rectangleWidth > 0) return rectangleWidth;
    final lines = plainText.split('\n');
    var longest = 0;
    for (final line in lines) {
      if (line.length > longest) longest = line.length;
    }
    return longest * height * 0.62;
  }

  Vec2 get _textAxis => Vec2.polar(rotation, 1);

  @override
  List<Vec2> grips() {
    final width = _columnWidth;
    final axis = _textAxis;
    return switch (hAlign) {
      TextHAlign.center || TextHAlign.middle => [
        position,
        position - axis * (width / 2),
        position + axis * (width / 2),
      ],
      TextHAlign.right => [position, position - axis * width],
      _ => [position, position + axis * width],
    };
  }

  @override
  MTextEntity withGrip(int index, Vec2 target) {
    if (index == 0) return copyWith(position: target);
    if (index != 1 && index != 2) return this;
    if (index == 2 &&
        hAlign != TextHAlign.center &&
        hAlign != TextHAlign.middle) {
      return this;
    }
    final localX = (target - position).dot(_textAxis);
    final width = switch (hAlign) {
      TextHAlign.center || TextHAlign.middle => 2 * localX.abs(),
      TextHAlign.right => -localX,
      _ => localX,
    };
    return copyWith(rectangleWidth: width < 1e-9 ? 1e-9 : width);
  }

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

void _emitMText(
  MTextEntity entity,
  EmitContext context,
  GeometrySink sink, {
  bool hugToAttachment = false,
}) {
  if (entity.content.isEmpty) return;
  final runs = MTextLayout(
    measureWidth: context.measureWidth,
    hugToAttachment: hugToAttachment,
  ).layout(entity);
  if (runs.isEmpty) return;
  final style = context.styleFor(entity.props);
  for (final run in runs) {
    if (run.text.isEmpty && run.barFrom == null) continue;
    final local = run.origin - entity.position;
    final origin = entity.rotation.abs() < 1e-12
        ? run.origin
        : entity.position + local.rotated(entity.rotation);
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
        rotation: entity.rotation,
        styleName: entity.styleName,
        widthFactor: run.widthFactor,
        obliqueAngle: run.obliqueAngle,
        tracking: run.tracking,
        hAlign: run.hAlign ?? TextHAlign.left,
        vAlign: TextVAlign.top,
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
      final a = entity.rotation.abs() < 1e-12
          ? from
          : entity.position + (from - entity.position).rotated(entity.rotation);
      final b = entity.rotation.abs() < 1e-12
          ? to
          : entity.position + (to - entity.position).rotated(entity.rotation);
      sink.polyline(
        context.applyBuffer(Float64List.fromList([a.x, a.y, b.x, b.y])),
        runStyle,
      );
    }
  }
}
