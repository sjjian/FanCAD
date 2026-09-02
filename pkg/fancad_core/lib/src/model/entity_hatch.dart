part of 'entity.dart';

/// A boundary loop of a hatch, already flattened to straight segments.
@immutable
class HatchLoop {
  const HatchLoop({required this.vertices, this.isOuter = true});

  /// Interleaved `[x, y, ...]`, implicitly closed.
  final Float64List vertices;
  final bool isOuter;

  int get pointCount => vertices.length ~/ 2;

  HatchLoop transformed(Mat3 matrix) =>
      HatchLoop(vertices: _transformBuffer(vertices, matrix), isOuter: isOuter);
}

/// A filled or pattern-hatched region.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class HatchEntity extends CadEntity {
  const HatchEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.loops,
    this.patternName = 'SOLID',
    this.solid = true,
    this.patternAngle = 0,
    this.patternScale = 1,
    this.patternLines = const [],
  });

  static HatchEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => HatchEntity(
    id: id,
    props: props,
    loops: _loopList(json['loops']),
    patternName: json['pattern'] as String? ?? 'SOLID',
    solid: json['solid'] as bool? ?? true,
    patternAngle: (json['patternAngle'] as num?)?.toDouble() ?? 0,
    patternScale: (json['patternScale'] as num?)?.toDouble() ?? 1,
    patternLines: _patternLineList(json['patternLines']),
  );

  @JsonKey(toJson: _hatchLoopsToJson)
  final List<HatchLoop> loops;
  @JsonKey(name: 'pattern')
  final String patternName;
  @JsonKey()
  final bool solid;
  @JsonKey(toJson: omitZero)
  final double patternAngle;
  @JsonKey(toJson: omitOne)
  final double patternScale;

  /// The pattern line families carried by the file itself, already rotated
  /// and scaled by whatever produced the drawing.
  ///
  /// DWG and DXF both store the resolved definition lines of a hatch next to
  /// its pattern name, and that is what AutoCAD draws. When this is
  /// non-empty it wins over looking [patternName] up in the built-in table
  /// and rotating it by [patternAngle], which cannot reproduce a pattern the
  /// file has already resolved differently.
  @JsonKey(toJson: _patternLinesToJson)
  final List<HatchPatternLine> patternLines;

  @override
  EntityKind get kind => EntityKind.hatch;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (loops.isEmpty) return;
    final style = context.styleFor(props);
    final outer = <Float64List>[];
    final inner = <Float64List>[];
    for (final loop in loops) {
      if (loop.pointCount < 2) continue;
      (loop.isOuter ? outer : inner).add(context.applyBuffer(loop.vertices));
    }
    if (outer.isEmpty && inner.isEmpty) return;
    if (solid) {
      final rings = outer.isEmpty ? inner : outer;
      for (final ring in rings) {
        sink.fill(ring, style, holes: outer.isEmpty ? const [] : inner);
      }
    } else {
      final strokes = const HatchGenerator().generate(this);
      if (strokes.isEmpty) {
        for (final ring in [...outer, ...inner]) {
          sink.polyline(ring, style, closed: true);
        }
      } else {
        for (final stroke in strokes) {
          sink.polyline(context.applyBuffer(stroke), style);
        }
      }
    }
  }

  @override
  HatchEntity withId(int id) => HatchEntity(
    id: id,
    props: props,
    loops: loops,
    patternName: patternName,
    solid: solid,
    patternAngle: patternAngle,
    patternScale: patternScale,
    patternLines: patternLines,
  );

  @override
  HatchEntity withProps(EntityProps props) => HatchEntity(
    id: id,
    props: props,
    loops: loops,
    patternName: patternName,
    solid: solid,
    patternAngle: patternAngle,
    patternScale: patternScale,
    patternLines: patternLines,
  );

  HatchEntity copyWith({
    String? patternName,
    bool? solid,
    double? patternAngle,
    double? patternScale,
    List<HatchPatternLine>? patternLines,
  }) => HatchEntity(
    id: id,
    props: props,
    loops: loops,
    patternName: patternName ?? this.patternName,
    solid: solid ?? this.solid,
    patternAngle: patternAngle ?? this.patternAngle,
    patternScale: patternScale ?? this.patternScale,
    patternLines: patternLines ?? this.patternLines,
  );

  @override
  HatchEntity transformed(Mat3 matrix) => HatchEntity(
    id: id,
    props: props,
    loops: [for (final loop in loops) loop.transformed(matrix)],
    patternName: patternName,
    solid: solid,
    patternAngle: patternAngle + matrix.rotation,
    patternScale: patternScale * matrix.meanScale,
    patternLines: [
      for (final line in patternLines) line.transformed(matrix),
    ],
  );

  @override
  List<Vec2> grips() => [
    for (final loop in loops)
      for (var i = 0; i < loop.pointCount; i++)
        Vec2(loop.vertices[i * 2], loop.vertices[i * 2 + 1]),
  ];

  @override
  HatchEntity withGrip(int index, Vec2 target) {
    var remaining = index;
    final updated = <HatchLoop>[];
    var applied = false;
    for (final loop in loops) {
      if (!applied && remaining < loop.pointCount) {
        final out = Float64List.fromList(loop.vertices);
        out[remaining * 2] = target.x;
        out[remaining * 2 + 1] = target.y;
        updated.add(HatchLoop(vertices: out, isOuter: loop.isOuter));
        applied = true;
      } else {
        updated.add(loop);
        remaining -= loop.pointCount;
      }
    }
    if (!applied) return this;
    return HatchEntity(
      id: id,
      props: props,
      loops: updated,
      patternName: patternName,
      solid: solid,
      patternAngle: patternAngle,
      patternScale: patternScale,
      patternLines: patternLines,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) =>
      stretchIndependentGrips(window, delta);

  @override
  double get signedArea {
    var total = 0.0;
    for (final loop in loops) {
      var sum = 0.0;
      final count = loop.pointCount;
      for (var i = 0; i < count; i++) {
        final j = (i + 1) % count;
        sum +=
            loop.vertices[i * 2] * loop.vertices[j * 2 + 1] -
            loop.vertices[j * 2] * loop.vertices[i * 2 + 1];
      }
      total += (sum / 2).abs() * (loop.isOuter ? 1 : -1);
    }
    return total;
  }

  @override
  Map<String, Object?> geometryToJson() => _$HatchEntityToJson(this);
}
