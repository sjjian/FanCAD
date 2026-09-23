part of 'entity.dart';

/// An entity the importer could not translate.
///
/// Keeping these as first-class citizens matters for a professional tool: an
/// unsupported object must still appear in the drawing tree, occupy space, and
/// survive a save rather than silently disappearing.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class UnknownEntity extends CadEntity {
  UnknownEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.originalType,
    this.proxyBounds = const Bounds2.empty(),
    Float64List? strokes,
    this.strokeCounts = const [],
  }) : strokes = strokes ?? _emptyBuffer;

  static UnknownEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => UnknownEntity(
    id: id,
    props: props,
    originalType: json['originalType'] as String? ?? 'UNKNOWN',
    proxyBounds: Bounds2.fromPoints(_pointList(json['proxyBounds'])),
    strokes: _pointBuffer(json['strokes']),
    strokeCounts: _idList(json['strokeCounts']),
  );

  /// The DWG type name, so the UI can explain what was skipped.
  @JsonKey()
  final String originalType;
  @JsonKey(toJson: proxyBoundsToJson)
  final Bounds2 proxyBounds;

  /// Display fallback: interleaved `[x, y, ...]` for types we cannot model.
  @JsonKey(toJson: pointBufferToJsonIfNotEmpty)
  final Float64List strokes;

  /// Point count per stroke run. Empty means a single run covering [strokes].
  @JsonKey(toJson: idListToJsonIfNotEmpty)
  final List<int> strokeCounts;

  @override
  EntityKind get kind => EntityKind.unknown;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (emitAsPixel(context, sink, computeBounds())) return;
    if (strokes.length < 4) return;
    final style = context.styleFor(props);
    final counts = strokeCounts.isEmpty
        ? <int>[strokes.length ~/ 2]
        : strokeCounts;
    var offset = 0;
    for (final count in counts) {
      final end = offset + count * 2;
      if (count >= 2 && end <= strokes.length) {
        sink.polyline(
          context.applyBuffer(Float64List.sublistView(strokes, offset, end)),
          style,
        );
      }
      offset = end;
    }
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    if (strokes.length >= 2) return Bounds2.fromXY(strokes);
    return proxyBounds;
  }

  @override
  UnknownEntity withId(int id) => UnknownEntity(
    id: id,
    props: props,
    originalType: originalType,
    proxyBounds: proxyBounds,
    strokes: strokes,
    strokeCounts: strokeCounts,
  );

  @override
  UnknownEntity withProps(EntityProps props) => UnknownEntity(
    id: id,
    props: props,
    originalType: originalType,
    proxyBounds: proxyBounds,
    strokes: strokes,
    strokeCounts: strokeCounts,
  );

  @override
  UnknownEntity transformed(Mat3 matrix) => UnknownEntity(
    id: id,
    props: props,
    originalType: originalType,
    proxyBounds: proxyBounds.transformed(matrix),
    strokes: _transformBuffer(strokes, matrix),
    strokeCounts: strokeCounts,
  );

  @override
  List<Vec2> grips() => const [];

  @override
  UnknownEntity withGrip(int index, Vec2 target) => this;

  @override
  Map<String, Object?> geometryToJson() => _$UnknownEntityToJson(this);
}
