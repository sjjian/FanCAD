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
  void emitObjectSnaps(ObjectSnapSink sink) => sink.node(position);

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

  /// Decomposes `matrix · T · R · S` back into an insertion, so a mirror
  /// lands on the sign of the Y scale instead of turning into 180°. Shear
  /// (a non-uniform insert under a skew rotation) has no INSERT form.
  @override
  InsertEntity transformed(Mat3 matrix) {
    if (matrix.isConformal && matrix.determinant > 0) {
      final factor = matrix.meanScale;
      return InsertEntity(
        id: id,
        props: props,
        blockName: blockName,
        position: matrix.transform(position),
        scale: scale * factor,
        rotation: rotation + matrix.rotation,
        columnCount: columnCount,
        rowCount: rowCount,
        columnSpacing: columnSpacing * factor,
        rowSpacing: rowSpacing * factor,
        attributes: attributes,
      );
    }
    final parts = matrix.multiplied(transformFor(0, 0)).insertParts;
    // R(θ + π) · S(−sx, −sy) is the same map. Keep whichever turns less from
    // the old rotation, so a mirror across Y reads as X scale −1, not 180°.
    double turn(double angle) {
      final d = (angle - rotation) % (2 * math.pi);
      return d > math.pi ? d - 2 * math.pi : d;
    }

    final keep = turn(parts.rotation);
    final flip = turn(parts.rotation + math.pi);
    final flipped = flip.abs() < keep.abs() - 1e-12;
    final newScale = flipped ? -parts.scale : parts.scale;
    final newRotation = rotation + (flipped ? flip : keep);
    // Cell offsets live in the rotated, unscaled frame; the new frame
    // stretches them by the same factor as the block axes.
    double stretch(double before, double after) =>
        before.abs() < 1e-12 ? matrix.meanScale : after / before;
    return InsertEntity(
      id: id,
      props: props,
      blockName: blockName,
      position: parts.position,
      scale: newScale,
      rotation: newRotation,
      columnCount: columnCount,
      rowCount: rowCount,
      columnSpacing: columnSpacing * stretch(scale.x, newScale.x),
      rowSpacing: rowSpacing * stretch(scale.y, newScale.y),
      attributes: attributes,
    );
  }

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

  /// A copy of the block's contents at every array cell. An ATTDEF becomes
  /// the ATTRIB this reference shows, carrying its value.
  @override
  List<CadEntity> explode(ExplodeSource drawing) {
    final ids = drawing.entityIdsOf(blockName);
    if (ids == null || ids.isEmpty) return const [];
    return [
      for (var row = 0; row < rowCount; row++)
        for (var column = 0; column < columnCount; column++)
          for (final id in ids)
            if (drawing.entity(id) case final member?)
              (member is AttdefEntity
                      ? member.toAttrib(
                          attributeValue(member.tag, member.defaultValue),
                        )
                      : member)
                  .transformed(transformFor(column, row))
                  .withId(0),
    ];
  }

  @override
  Map<String, Object?> geometryToJson() => {
    ..._$InsertEntityToJson(this),
    if (attributes.isNotEmpty) 'attributes': attributes,
  };
}
