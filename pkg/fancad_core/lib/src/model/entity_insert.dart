part of 'entity.dart';

/// A block reference, optionally arrayed (MINSERT).
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class InsertEntity extends CadEntity {
  const InsertEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.blockName,
    required this.position,
    this.scale = const Vec2(1, 1),
    this.rotation = 0,
    this.columnCount = 1,
    this.rowCount = 1,
    this.columnSpacing = 0,
    this.rowSpacing = 0,
    this.attributes = const {},
  });

  static InsertEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => InsertEntity(
    id: id,
    props: props,
    blockName: json['blockName'] as String? ?? '',
    position: _point(json['position']),
    scale: _point(json['scale'], fallback: const Vec2(1, 1)),
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    columnCount: (json['columnCount'] as num?)?.toInt() ?? 1,
    rowCount: (json['rowCount'] as num?)?.toInt() ?? 1,
    columnSpacing: (json['columnSpacing'] as num?)?.toDouble() ?? 0,
    rowSpacing: (json['rowSpacing'] as num?)?.toDouble() ?? 0,
    attributes: _stringMap(json['attributes']),
  );

  @JsonKey()
  final String blockName;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 position;
  @JsonKey(toJson: scaleToJson)
  final Vec2 scale;
  @JsonKey(toJson: omitZero)
  final double rotation;
  @JsonKey(toJson: omitOne)
  final int columnCount;
  @JsonKey(toJson: omitOne)
  final int rowCount;
  @JsonKey(toJson: omitZero)
  final double columnSpacing;
  @JsonKey(toJson: omitZero)
  final double rowSpacing;

  /// Tag → value for ATTDEFs in [blockName]. Missing tags use the definition
  /// default, so an empty map is a freshly inserted title block.
  final Map<String, String> attributes;

  bool get isArray => columnCount > 1 || rowCount > 1;

  String attributeValue(String tag, [String fallback = '']) =>
      attributes[tag] ?? fallback;

  /// The local-to-parent transform of a single array cell.
  Mat3 transformFor(int column, int row) {
    final offset = Vec2(
      columnSpacing * column,
      rowSpacing * row,
    ).rotated(rotation);
    return Mat3.translation(position.x + offset.x, position.y + offset.y)
        .multiplied(Mat3.rotation(rotation))
        .multiplied(Mat3.scaling(scale.x, scale.y));
  }

  @override
  EntityKind get kind => EntityKind.insert;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (blockName.isEmpty || !context.canRecurse) return;
    final style = context.styleFor(props);
    final blockBounds = context.blocks.boundsOf(blockName);
    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final local = transformFor(column, row);
        if (blockBounds.isNotEmpty) {
          final worldBounds = blockBounds.transformed(
            context.transform.multiplied(local),
          );
          final clip = context.clip;
          if (clip != null && !worldBounds.intersects(clip)) continue;
          if (context.isSubPixelWorld(worldBounds)) {
            sink.point(worldBounds.center.x, worldBounds.center.y, style);
            continue;
          }
        }
        context.blocks.emitBlock(
          blockName,
          context.descend(local, style).withAttributeValues(attributes),
          sink,
        );
      }
    }
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final blockBounds = blocks.boundsOf(blockName);
    if (blockBounds.isEmpty) {
      return Bounds2(position.x, position.y, position.x, position.y);
    }
    var box = const Bounds2.empty();
    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        box = box.union(blockBounds.transformed(transformFor(column, row)));
      }
    }
    return box;
  }

  @override
  InsertEntity withId(int id) => InsertEntity(
    id: id,
    props: props,
    blockName: blockName,
    position: position,
    scale: scale,
    rotation: rotation,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
    attributes: attributes,
  );

  @override
  InsertEntity withProps(EntityProps props) => InsertEntity(
    id: id,
    props: props,
    blockName: blockName,
    position: position,
    scale: scale,
    rotation: rotation,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
    attributes: attributes,
  );

  InsertEntity withAttributes(Map<String, String> attributes) => InsertEntity(
    id: id,
    props: props,
    blockName: blockName,
    position: position,
    scale: scale,
    rotation: rotation,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
    attributes: attributes,
  );

  @override
  InsertEntity transformed(Mat3 matrix) => InsertEntity(
    id: id,
    props: props,
    blockName: blockName,
    position: matrix.transform(position),
    scale: Vec2(
      scale.x * math.sqrt(matrix.a * matrix.a + matrix.b * matrix.b),
      scale.y * math.sqrt(matrix.c * matrix.c + matrix.d * matrix.d),
    ),
    rotation: rotation + matrix.rotation,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing * matrix.meanScale,
    rowSpacing: rowSpacing * matrix.meanScale,
    attributes: attributes,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  InsertEntity withGrip(int index, Vec2 target) => InsertEntity(
    id: id,
    props: props,
    blockName: blockName,
    position: target,
    scale: scale,
    rotation: rotation,
    columnCount: columnCount,
    rowCount: rowCount,
    columnSpacing: columnSpacing,
    rowSpacing: rowSpacing,
    attributes: attributes,
  );

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return _inStretchWindow(window, position)
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  @override
  Map<String, Object?> geometryToJson() => {
    ..._$InsertEntityToJson(this),
    if (attributes.isNotEmpty) 'attributes': attributes,
  };
}
