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

  bool get isAssociative => sourceIds.isNotEmpty;

  /// Length shown on a linear or aligned dimension.
  ///
  /// Type 0 with a third definition point is DIMLINEAR: the pick that placed
  /// the dimension line chooses horizontal vs vertical, so the text is |Δx|
  /// or |Δy|, not the slanted distance between the origins.
  static double measuredLength(List<Vec2> points, int dimensionType) {
    if (points.length < 2) return 0;
    if ((dimensionType & 0x0F) == 0 && points.length >= 3) {
      final mid = points[0].lerp(points[1], 0.5);
      final horizontal = (points[2] - mid).y.abs() >= (points[2] - mid).x.abs();
      return horizontal
          ? (points[1].x - points[0].x).abs()
          : (points[1].y - points[0].y).abs();
    }
    return points[0].distanceTo(points[1]);
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
    if (overrideText.isEmpty) return value;
    return overrideText.replaceAll('<>', value);
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
          context.descend(const Mat3.identity(), style),
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
      // The cached block geometry is no longer valid once the definition points
      // move, so drop it and let the fallback or a regeneration pass rebuild it.
      blockName: matrix.isIdentity ? blockName : '',
      definitionPoints: points,
      textPosition: matrix.transform(textPosition),
      measurement: nextMeasurement > 1e-12 ? nextMeasurement : measurement,
      overrideText: overrideText,
      styleName: styleName,
      dimensionType: dimensionType,
      sourceIds: sourceIds,
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
