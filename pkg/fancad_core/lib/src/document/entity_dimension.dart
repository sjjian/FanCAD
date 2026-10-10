part of 'entity.dart';

/// A dimension.
///
/// DWG stores the fully rendered dimension geometry in an anonymous `*D`
/// block. Rendering that block is exact and cheap, so it is the primary path;
/// the definition points are kept so the geometry can be regenerated after an
/// edit or when the block is missing.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class DimensionEntity extends CadEntity {
  const DimensionEntity({
    required super.id,
    super.props = EntityProps.defaults,
    this.blockName = '',
    this.definitionPoints = const [],
    this.textPosition = const Vec2.zero(),
    this.measurement = 0,
    this.overrideText = '',
    this.styleName = 'Standard',
    this.dimensionType = 0,
    this.sourceIds = const [],
    this.blockTranslation = const Vec2.zero(),
    this.blockScale = const Vec2(1, 1),
    this.blockRotation = 0,
  });

  static DimensionEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => DimensionEntity(
    id: id,
    props: props,
    blockName: json['blockName'] as String? ?? '',
    definitionPoints: _pointList(json['definitionPoints']),
    textPosition: _point(json['textPosition']),
    measurement: (json['measurement'] as num?)?.toDouble() ?? 0,
    overrideText: json['text'] as String? ?? '',
    styleName: json['style'] as String? ?? 'Standard',
    dimensionType: (json['dimensionType'] as num?)?.toInt() ?? 0,
    sourceIds: _idList(json['sourceIds']),
    blockTranslation: _point(json['blockTranslation']),
    blockScale: _point(json['blockScale'], fallback: const Vec2(1, 1)),
    blockRotation: (json['blockRotation'] as num?)?.toDouble() ?? 0,
  );

  /// The anonymous block holding the pre-rendered geometry.
  @JsonKey(toJson: omitEmptyString)
  final String blockName;
  @JsonKey(toJson: vec2ListToJson)
  final List<Vec2> definitionPoints;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 textPosition;
  @JsonKey()
  final double measurement;

  /// `''` uses the measured value, `' '` suppresses the text entirely.
  @JsonKey(name: 'text', toJson: omitEmptyString)
  final String overrideText;
  @JsonKey(name: 'style')
  final String styleName;

  /// DXF group code 70, low 4 bits identify the dimension family.
  @JsonKey(toJson: omitZero)
  final int dimensionType;

  /// Entity ids this dimension measures. Empty means a free (non-associative)
  /// placement: two picked points, not a live object.
  @JsonKey(toJson: idListToJsonIfNotEmpty)
  final List<int> sourceIds;

  /// DWG `clone_ins_pt`. Moves the anonymous `*D` block into this dimension's
  /// coordinate system. Zero means the block is already there.
  @JsonKey(toJson: vec2ToJsonIfNotOrigin)
  final Vec2 blockTranslation;

  /// DWG `ins_scale`. A zero component is treated as 1: LibreDWG writes
  /// (0,0,0) when the host stored an identity scale.
  @JsonKey(toJson: scaleToJson)
  final Vec2 blockScale;

  /// DWG `ins_rotation`, radians, applied before [blockTranslation].
  @JsonKey(toJson: omitZero)
  final double blockRotation;

  bool get isAssociative => sourceIds.isNotEmpty;

  /// `T * R * S` that places `*D` geometry onto [definitionPoints].
  Mat3 get blockTransform {
    final sx = blockScale.x == 0 ? 1.0 : blockScale.x;
    final sy = blockScale.y == 0 ? 1.0 : blockScale.y;
    if (blockTranslation == const Vec2.zero() &&
        sx == 1 &&
        sy == 1 &&
        blockRotation == 0) {
      return const Mat3.identity();
    }
    return Mat3.translation(
      blockTranslation.x,
      blockTranslation.y,
    ).multiplied(Mat3.rotation(blockRotation)).multiplied(Mat3.scaling(sx, sy));
  }

  /// Length shown on a linear or aligned dimension.
  ///
  /// Type 0 with a third definition point is DIMLINEAR: the pick that placed
  /// the dimension line chooses the measurement axis, so the text is the
  /// projected length, not the slanted distance between the origins.
  static double measuredLength(List<Vec2> points, int dimensionType) {
    if (points.length < 2) return 0;
    if ((dimensionType & 0x0F) == 0 && points.length >= 3) {
      final line = linearDimLine(points);
      return line == null ? 0 : line.$1.distanceTo(line.$2);
    }
    return points[0].distanceTo(points[1]);
  }

  /// Ends of a DIMLINEAR dimension line through [points] `2`.
  ///
  /// Type 0 stores a pick on the dimension line, not an axis flag. The line
  /// through that pick, perpendicular to the vector from the origin midpoint,
  /// is the dimension line — so a rotation of a horizontal or vertical dim
  /// stays a dim, instead of snapping back to X or Y.
  static (Vec2, Vec2)? linearDimLine(List<Vec2> points) {
    if (points.length < 3) return null;
    final p1 = points[0];
    final p2 = points[1];
    final seat = points[2];
    final mid = p1.lerp(p2, 0.5);
    var axis = (seat - mid).perpendicular;
    if (axis.lengthSquared < 1e-20) {
      axis = p2 - p1;
    }
    if (axis.lengthSquared < 1e-20) return null;
    final unit = axis.normalized();
    final a = seat + unit * (p1 - seat).dot(unit);
    final b = seat + unit * (p2 - seat).dot(unit);
    if (a.distanceTo(b) < 1e-9) return null;
    return (a, b);
  }

  /// Degrees shown on an angular dimension.
  ///
  /// Type 2 stores `[vertex, first, second]`. Type 5 (DXF 3-point) stores
  /// `[first, second, vertex]`. The sweep is the counter-clockwise sector
  /// from the first arm to the second.
  static double measuredAngle(List<Vec2> points, {int dimensionType = 2}) {
    final ordered = angularPoints(points, dimensionType);
    if (ordered.length < 3) return 0;
    final vertex = ordered[0];
    if (ordered[1].distanceTo(vertex) < 1e-12 ||
        ordered[2].distanceTo(vertex) < 1e-12) {
      return 0;
    }
    final start = (ordered[1] - vertex).angle;
    final end = (ordered[2] - vertex).angle;
    return angularSweep(start, end) * 180 / math.pi;
  }

  /// `[vertex, first, second]` regardless of whether [dimensionType] is 2 or 5.
  static List<Vec2> angularPoints(List<Vec2> points, int dimensionType) {
    if ((dimensionType & 0x0F) == 5 && points.length >= 3) {
      return [points[2], points[0], points[1]];
    }
    return points;
  }

  /// Absolute X or Y of the feature point. Bit 64 of [dimensionType] is an
  /// X-ordinate; otherwise it is a Y-ordinate.
  static double measuredOrdinate(List<Vec2> points, int dimensionType) {
    if (points.isEmpty) return 0;
    final feature = points[0];
    return (dimensionType & 64) != 0 ? feature.x.abs() : feature.y.abs();
  }

  bool get hasRenderedBlock => blockName.isNotEmpty;

  /// Measurement text using two decimal places. Regenerated graphics use
  /// [displayTextFor] so a DIMSTYLE can choose a different precision.
  String get displayText => formatMeasurement(2);

  String displayTextFor(DimStyleDef style) =>
      formatMeasurement(style.clampedDecimals);

  String formatMeasurement(int decimalPlaces) {
    final places = decimalPlaces < 0
        ? 0
        : (decimalPlaces > 8 ? 8 : decimalPlaces);
    final value = measurement.toStringAsFixed(places);
    final raw = overrideText.isEmpty
        ? value
        : overrideText.replaceAll('<>', value);
    return decodeDrawnText(raw);
  }

  DimensionEntity copyWith({
    int? id,
    EntityProps? props,
    String? blockName,
    List<Vec2>? definitionPoints,
    Vec2? textPosition,
    double? measurement,
    String? overrideText,
    String? styleName,
    int? dimensionType,
    List<int>? sourceIds,
    Vec2? blockTranslation,
    Vec2? blockScale,
    double? blockRotation,
  }) => DimensionEntity(
    id: id ?? this.id,
    props: props ?? this.props,
    blockName: blockName ?? this.blockName,
    definitionPoints: definitionPoints ?? this.definitionPoints,
    textPosition: textPosition ?? this.textPosition,
    measurement: measurement ?? this.measurement,
    overrideText: overrideText ?? this.overrideText,
    styleName: styleName ?? this.styleName,
    dimensionType: dimensionType ?? this.dimensionType,
    sourceIds: sourceIds ?? this.sourceIds,
    blockTranslation: blockTranslation ?? this.blockTranslation,
    blockScale: blockScale ?? this.blockScale,
    blockRotation: blockRotation ?? this.blockRotation,
  );

  @override
  EntityKind get kind => EntityKind.dimension;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (emitAsPixel(context, sink)) return;
    final style = context.styleFor(props);
    if (hasRenderedBlock && context.canRecurse) {
      final ids = context.blocks.entityIdsOf(blockName);
      if (ids != null && ids.isNotEmpty) {
        // A *D block is supposed to hold the measurement MTEXT. Some DWGs
        // (and an overlapping owner map) leave only the strokes; returning
        // here would keep the red ticks and drop the number.
        final probe = _TextAwareSink(sink);
        context.blocks.emitBlock(
          blockName,
          context.descend(blockTransform, style),
          probe,
        );
        if (!probe.sawText) {
          const DimensionGraphics().emitText(this, context, sink);
        }
        return;
      }
    }
    const DimensionGraphics().emit(this, context, sink);
  }

  @override
  DimensionEntity withId(int id) => DimensionEntity(
    id: id,
    props: props,
    blockName: blockName,
    definitionPoints: definitionPoints,
    textPosition: textPosition,
    measurement: measurement,
    overrideText: overrideText,
    styleName: styleName,
    dimensionType: dimensionType,
    sourceIds: sourceIds,
    blockTranslation: blockTranslation,
    blockScale: blockScale,
    blockRotation: blockRotation,
  );

  @override
  DimensionEntity withProps(EntityProps props) => DimensionEntity(
    id: id,
    props: props,
    blockName: blockName,
    definitionPoints: definitionPoints,
    textPosition: textPosition,
    measurement: measurement,
    overrideText: overrideText,
    styleName: styleName,
    dimensionType: dimensionType,
    sourceIds: sourceIds,
    blockTranslation: blockTranslation,
    blockScale: blockScale,
    blockRotation: blockRotation,
  );

  @override
  DimensionEntity transformed(Mat3 matrix) {
    final points = [for (final p in definitionPoints) matrix.transform(p)];
    final family = dimensionType & 0x0F;
    // Angles are not lengths: SCALE must not turn 45° into 90°. Linear and
    // aligned values are reread from the new origins. Radial still scales
    // by the mean factor because the chord is a seat, not the radius.
    final nextMeasurement = switch (family) {
      2 || 5 => measuredAngle(points, dimensionType: dimensionType),
      6 => measuredOrdinate(points, dimensionType),
      0 || 1 => measuredLength(points, dimensionType),
      _ => measurement * matrix.meanScale,
    };
    return DimensionEntity(
      id: id,
      props: props,
      // The cached *D block is in its own coordinates. [blockTransform]
      // places it. A pure [transformed] call cannot move those entities, so
      // the name is dropped and [DimensionGraphics] rebuilds from the new
      // points. [Transaction.transform] restores the name after it has moved
      // the block contents; the translation then takes only the linear part
      // of [matrix], because the strokes already received the translation.
      blockName: matrix.isIdentity ? blockName : '',
      definitionPoints: points,
      textPosition: matrix.transform(textPosition),
      measurement: nextMeasurement > 1e-12 ? nextMeasurement : measurement,
      overrideText: overrideText,
      styleName: styleName,
      dimensionType: dimensionType,
      sourceIds: sourceIds,
      blockTranslation: matrix.transformDirection(blockTranslation),
      blockScale: blockScale,
      blockRotation: blockRotation,
    );
  }

  @override
  List<Vec2> grips() => [...definitionPoints, textPosition];

  @override
  DimensionEntity withGrip(int index, Vec2 target) {
    if (index == definitionPoints.length) {
      return DimensionEntity(
        id: id,
        props: props,
        blockName: '',
        definitionPoints: definitionPoints,
        textPosition: target,
        measurement: measurement,
        overrideText: overrideText,
        styleName: styleName,
        dimensionType: dimensionType,
        sourceIds: sourceIds,
        blockTranslation: blockTranslation,
        blockScale: blockScale,
        blockRotation: blockRotation,
      );
    }
    if (index < 0 || index >= definitionPoints.length) return this;
    final points = [...definitionPoints];
    points[index] = target;
    final family = dimensionType & 0x0F;
    final nextMeasurement = switch (family) {
      2 || 5 => measuredAngle(points, dimensionType: dimensionType),
      6 => measuredOrdinate(points, dimensionType),
      0 || 1 => measuredLength(points, dimensionType),
      _ => measurement,
    };
    return DimensionEntity(
      id: id,
      props: props,
      blockName: '',
      definitionPoints: points,
      textPosition: textPosition,
      measurement: nextMeasurement > 1e-12 ? nextMeasurement : measurement,
      overrideText: overrideText,
      styleName: styleName,
      dimensionType: dimensionType,
      sourceIds: sourceIds,
      blockTranslation: blockTranslation,
      blockScale: blockScale,
      blockRotation: blockRotation,
    );
  }

  @override
  DimensionEntity remappedIds(Map<int, int> ids) {
    if (sourceIds.isEmpty) return this;
    final next = [for (final id in sourceIds) ids[id] ?? id];
    for (var i = 0; i < next.length; i++) {
      if (next[i] != sourceIds[i]) {
        return copyWith(sourceIds: next);
      }
    }
    return this;
  }

  @override
  Map<String, Object?> geometryToJson() => _$DimensionEntityToJson(this);

  /// The members of its block, or the lines, arrows and text the dimension
  /// style draws when the block is missing.
  @override
  List<CadEntity> explode(ExplodeSource drawing) {
    if (blockName.isNotEmpty) {
      final ids = drawing.entityIdsOf(blockName);
      if (ids != null && ids.isNotEmpty) {
        return [
          for (final id in ids)
            if (drawing.entity(id) case final member?) member.withId(0),
        ];
      }
    }
    return explodeAsDrawn(style: drawing.dimStyle(styleName));
  }

  /// The lines, arrows and text this dimension draws without its block, as
  /// editable entities.
  ///
  /// It matches the fallback renderer, so a dimension that never had an
  /// anonymous block still comes apart into geometry a user can move.
  List<CadEntity> explodeAsDrawn({DimStyleDef? style}) =>
      _explodeDimension(this, style ?? DimStyleDef.standard);
}

List<CadEntity> _explodeDimension(DimensionEntity entity, DimStyleDef dim) {
  final props = entity.props;
  final pieces = <CadEntity>[];
  final points = entity.definitionPoints;
  if (points.length >= 2) {
    switch (entity.dimensionType & 0x0F) {
      case 2:
        pieces.addAll(_explodeAngularDim(entity, props, dim));
      case 3:
        pieces.addAll(_explodeRadialDim(entity, props, dim, diameter: true));
      case 4:
        pieces.addAll(_explodeRadialDim(entity, props, dim, diameter: false));
      default:
        pieces.addAll(_explodeLinearDim(entity, props, dim));
    }
  }
  if (entity.overrideText != ' ') {
    pieces.add(
      TextEntity(
        id: 0,
        props: props,
        position: entity.textPosition,
        content: entity.displayTextFor(dim),
        height: dim.scaledTextHeight,
        styleName: dim.textStyle,
        hAlign: TextHAlign.center,
        vAlign: TextVAlign.middle,
      ),
    );
  }
  return pieces;
}

List<CadEntity> _explodeLinearDim(
  DimensionEntity entity,
  EntityProps props,
  DimStyleDef dim,
) {
  final points = entity.definitionPoints;
  final p1 = points[0];
  final p2 = points[1];
  final dimLine = points.length > 2 ? points[2] : entity.textPosition;
  late final Vec2 a;
  late final Vec2 b;
  late final Vec2 unit;
  if ((entity.dimensionType & 0x0F) == 0 && points.length >= 3) {
    final mid = p1.lerp(p2, 0.5);
    final horizontal = (dimLine - mid).y.abs() >= (dimLine - mid).x.abs();
    a = horizontal ? Vec2(p1.x, dimLine.y) : Vec2(dimLine.x, p1.y);
    b = horizontal ? Vec2(p2.x, dimLine.y) : Vec2(dimLine.x, p2.y);
    if (a.distanceTo(b) < 1e-9) return const [];
    unit = (b - a).normalized();
  } else {
    final direction = p2 - p1;
    if (direction.length < 1e-9) return const [];
    unit = direction.normalized();
    final normal = unit.perpendicular;
    var offset = (dimLine - p1).dot(normal);
    if (offset.abs() < 1e-6) offset = direction.length * 0.15;
    a = p1 + normal * offset;
    b = p2 + normal * offset;
  }
  return [
    ..._extensionLine(p1, a, props, dim),
    ..._extensionLine(p2, b, props, dim),
    LineEntity(id: 0, props: props, start: a, end: b),
    ..._dimArrows(a, unit, props, dim.scaledArrowSize),
    ..._dimArrows(b, -unit, props, dim.scaledArrowSize),
  ];
}

List<CadEntity> _explodeRadialDim(
  DimensionEntity entity,
  EntityProps props,
  DimStyleDef dim, {
  required bool diameter,
}) {
  final center = entity.definitionPoints[0];
  final chord = entity.definitionPoints[1];
  final delta = chord - center;
  if (delta.length < 1e-9) return const [];
  final unit = delta.normalized();
  return [
    LineEntity(id: 0, props: props, start: center, end: chord),
    if (diameter)
      LineEntity(id: 0, props: props, start: center, end: center - delta),
    ..._dimArrows(chord, -unit, props, dim.scaledArrowSize),
  ];
}

List<CadEntity> _explodeAngularDim(
  DimensionEntity entity,
  EntityProps props,
  DimStyleDef dim,
) {
  final points = entity.definitionPoints;
  if (points.length < 3) return _explodeLinearDim(entity, props, dim);
  final vertex = points[0];
  final a = points[1];
  final b = points[2];
  final radius = vertex.distanceTo(entity.textPosition);
  final start = (a - vertex).angle;
  final end = (b - vertex).angle;
  return [
    LineEntity(id: 0, props: props, start: vertex, end: a),
    LineEntity(id: 0, props: props, start: vertex, end: b),
    if (radius > 1e-9)
      ArcEntity(
        id: 0,
        props: props,
        center: vertex,
        radius: radius,
        startAngle: start,
        endAngle: start + angularSweep(start, end),
      ),
  ];
}

List<CadEntity> _extensionLine(
  Vec2 origin,
  Vec2 dimEnd,
  EntityProps props,
  DimStyleDef dim,
) {
  final span = dimEnd - origin;
  final length = span.length;
  if (length < 1e-9) return const [];
  final unit = span / length;
  final exo = dim.scaledExtensionOffset;
  final start = exo >= length ? dimEnd : origin + unit * exo;
  final end = dimEnd + unit * dim.scaledExtensionExtend;
  if (start.distanceTo(end) < 1e-9) return const [];
  return [LineEntity(id: 0, props: props, start: start, end: end)];
}

List<CadEntity> _dimArrows(
  Vec2 tip,
  Vec2 direction,
  EntityProps props,
  double size,
) {
  if (direction.length < 1e-9 || size <= 1e-9) return const [];
  final unit = direction.normalized();
  return [
    SolidEntity(
      id: 0,
      props: props,
      corners: [
        tip,
        tip - unit * size + unit.perpendicular * (size * 0.35),
        tip - unit * size - unit.perpendicular * (size * 0.35),
      ],
    ),
  ];
}

/// Forwards primitives and notes whether a non-empty text run arrived.
class _TextAwareSink implements GeometrySink {
  _TextAwareSink(this._inner);

  final GeometrySink _inner;
  bool sawText = false;

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) =>
      _inner.polyline(xy, style, closed: closed);

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) => _inner.fill(xy, style, holes: holes);

  @override
  void point(double x, double y, ResolvedStyle style) =>
      _inner.point(x, y, style);

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    if (geometry.text.trim().isNotEmpty) sawText = true;
    _inner.text(geometry, style);
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) =>
      _inner.image(geometry, style);
}
