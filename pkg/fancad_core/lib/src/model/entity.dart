// ignore_for_file: invalid_annotation_target

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import '../annotation/dimension.dart';
import '../geometry/bounds.dart';
import '../geometry/flatten.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../hatch/generator.dart';
import '../text/mtext_layout.dart';
import 'geometry_sink.dart';
import 'json_converters.dart';
import 'style.dart';

part 'entity.g.dart';

/// The discriminator used on the wire and in query filters.
enum EntityKind {
  line,
  polyline,
  circle,
  arc,
  ellipse,
  spline,
  point,
  text,
  mtext,
  insert,
  hatch,
  dimension,
  leader,
  solid,
  ray,
  xline,
  image,
  attdef,
  attrib,
  unknown;

  static EntityKind parse(String value) => EntityKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => EntityKind.unknown,
  );
}

/// Base class for everything that can live in a block or layout.
///
/// Entities are immutable value objects. Editing produces new instances, which
/// is what makes the undo stack cheap: a patch holds references to the old and
/// new entity rather than a deep copy of the drawing.
@immutable
sealed class CadEntity {
  const CadEntity({required this.id, required this.props});

  /// Stable identity. Values imported from DWG reuse the file handle so that
  /// a save round trip preserves cross-references.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int id;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final EntityProps props;

  EntityKind get kind;

  /// Flattens this entity into [sink] in model coordinates.
  void emit(EmitContext context, GeometrySink sink);

  /// Returns a copy with a different identity.
  CadEntity withId(int id);

  /// Returns a copy with different common attributes.
  CadEntity withProps(EntityProps props);

  /// Returns a geometrically transformed copy.
  CadEntity transformed(Mat3 matrix);

  /// Editable control points shown as grips when the entity is selected.
  List<Vec2> grips();

  /// Moves the grip at [index] to [target]. Returns `this` when the entity
  /// does not support that grip.
  CadEntity withGrip(int index, Vec2 target);

  /// Rewrites stored entity ids after a copy or xref remap.
  ///
  /// [ids] maps the old handle to the new one. Missing keys stay as they
  /// are, so a copied dimension can keep pointing at a source that was not
  /// in the copy set.
  CadEntity remappedIds(Map<int, int> ids) => this;

  /// Type-specific JSON payload, merged into [toJson] by the base class.
  Map<String, Object?> geometryToJson();

  /// Bounds computed without a font engine or block table. Entities that need
  /// context (block references, dimensions) fall back to emitting into a
  /// [BoundsSink].
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final sink = BoundsSink();
    emit(
      EmitContext(tolerance: tolerance, blocks: blocks),
      sink,
    );
    return sink.bounds;
  }

  /// Box used by the spatial index for window and crossing selection.
  ///
  /// Same as [computeBounds] for ordinary geometry. Construction lines
  /// override this so they can be found far from the origin without
  /// stretching Zoom Extents.
  Bounds2 indexBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => computeBounds(blocks: blocks, tolerance: tolerance);

  Map<String, Object?> toJson() => {
    'id': id,
    'type': kind.name,
    ...props.toJson(),
    ...geometryToJson(),
  };

  static CadEntity fromJson(Map<String, Object?> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final props = EntityProps.fromJson(json);
    final kind = EntityKind.parse(json['type'] as String? ?? 'unknown');
    return switch (kind) {
      EntityKind.line => LineEntity(
        id: id,
        props: props,
        start: _point(json['start']),
        end: _point(json['end']),
      ),
      EntityKind.polyline => PolylineEntity(
        id: id,
        props: props,
        vertices: _vertexBuffer(json['vertices']),
        closed: json['closed'] as bool? ?? false,
        constantWidth: (json['width'] as num?)?.toDouble() ?? 0,
      ),
      EntityKind.circle => CircleEntity(
        id: id,
        props: props,
        center: _point(json['center']),
        radius: (json['radius'] as num?)?.toDouble() ?? 0,
      ),
      EntityKind.arc => ArcEntity(
        id: id,
        props: props,
        center: _point(json['center']),
        radius: (json['radius'] as num?)?.toDouble() ?? 0,
        startAngle: (json['startAngle'] as num?)?.toDouble() ?? 0,
        endAngle: (json['endAngle'] as num?)?.toDouble() ?? 0,
      ),
      EntityKind.ellipse => EllipseEntity(
        id: id,
        props: props,
        center: _point(json['center']),
        majorAxis: _point(json['majorAxis']),
        ratio: (json['ratio'] as num?)?.toDouble() ?? 1,
        startParam: (json['startParam'] as num?)?.toDouble() ?? 0,
        endParam: (json['endParam'] as num?)?.toDouble() ?? math.pi * 2,
      ),
      EntityKind.spline => SplineEntity(
        id: id,
        props: props,
        controlPoints: _pointBuffer(json['controlPoints']),
        knots: _doubleList(json['knots']),
        weights: _doubleList(json['weights']),
        degree: (json['degree'] as num?)?.toInt() ?? 3,
        closed: json['closed'] as bool? ?? false,
        fitPoints: _pointBuffer(json['fitPoints']),
      ),
      EntityKind.point => PointEntity(
        id: id,
        props: props,
        position: _point(json['position']),
      ),
      EntityKind.text => TextEntity(
        id: id,
        props: props,
        position: _point(json['position']),
        content: json['text'] as String? ?? '',
        height: (json['height'] as num?)?.toDouble() ?? 2.5,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        styleName: json['style'] as String? ?? 'Standard',
        widthFactor: (json['widthFactor'] as num?)?.toDouble() ?? 1,
        obliqueAngle: (json['oblique'] as num?)?.toDouble() ?? 0,
        hAlign: _enumOf(TextHAlign.values, json['hAlign'], TextHAlign.left),
        vAlign: _enumOf(
          TextVAlign.values,
          json['vAlign'],
          TextVAlign.baseline,
        ),
      ),
      EntityKind.mtext => MTextEntity(
        id: id,
        props: props,
        position: _point(json['position']),
        content: json['text'] as String? ?? '',
        height: (json['height'] as num?)?.toDouble() ?? 2.5,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        styleName: json['style'] as String? ?? 'Standard',
        rectangleWidth: (json['rectangleWidth'] as num?)?.toDouble() ?? 0,
        attachment: (json['attachment'] as num?)?.toInt() ?? 1,
      ),
      EntityKind.insert => InsertEntity(
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
      ),
      EntityKind.attdef => AttdefEntity(
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
        vAlign: _enumOf(
          TextVAlign.values,
          json['vAlign'],
          TextVAlign.baseline,
        ),
        invisible: json['invisible'] as bool? ?? false,
        constant: json['constant'] as bool? ?? false,
        verify: json['verify'] as bool? ?? false,
        preset: json['preset'] as bool? ?? false,
      ),
      EntityKind.attrib => AttribEntity(
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
        vAlign: _enumOf(
          TextVAlign.values,
          json['vAlign'],
          TextVAlign.baseline,
        ),
        invisible: json['invisible'] as bool? ?? false,
      ),
      EntityKind.hatch => HatchEntity(
        id: id,
        props: props,
        loops: _loopList(json['loops']),
        patternName: json['pattern'] as String? ?? 'SOLID',
        solid: json['solid'] as bool? ?? true,
        patternAngle: (json['patternAngle'] as num?)?.toDouble() ?? 0,
        patternScale: (json['patternScale'] as num?)?.toDouble() ?? 1,
      ),
      EntityKind.dimension => DimensionEntity(
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
      ),
      EntityKind.leader => LeaderEntity(
        id: id,
        props: props,
        vertices: _pointBuffer(json['vertices']),
        hasArrowHead: json['arrowHead'] as bool? ?? true,
        styleName: json['style'] as String? ?? 'Standard',
      ),
      EntityKind.solid => SolidEntity(
        id: id,
        props: props,
        corners: _pointList(json['corners']),
      ),
      EntityKind.ray => RayEntity(
        id: id,
        props: props,
        origin: _point(json['origin']),
        direction: _point(json['direction'], fallback: const Vec2(1, 0)),
      ),
      EntityKind.xline => XLineEntity(
        id: id,
        props: props,
        origin: _point(json['origin']),
        direction: _point(json['direction'], fallback: const Vec2(1, 0)),
      ),
      EntityKind.image => ImageEntity(
        id: id,
        props: props,
        reference: json['reference'] as String? ?? '',
        origin: _point(json['origin']),
        uVector: _point(json['u'], fallback: const Vec2(1, 0)),
        vVector: _point(json['v'], fallback: const Vec2(0, 1)),
      ),
      EntityKind.unknown => UnknownEntity(
        id: id,
        props: props,
        originalType: json['originalType'] as String? ?? 'UNKNOWN',
        proxyBounds: Bounds2.fromPoints(_pointList(json['proxyBounds'])),
      ),
    };
  }

  @override
  String toString() => '${kind.name}#$id';
}

// ---------------------------------------------------------------------------
// Linear primitives
// ---------------------------------------------------------------------------

/// A straight segment between two points.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class LineEntity extends CadEntity {
  const LineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.start,
    required this.end,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 start;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 end;

  double get length => start.distanceTo(end);
  double get angle => (end - start).angle;
  Vec2 get midpoint => start.lerp(end, 0.5);

  @override
  EntityKind get kind => EntityKind.line;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final a = context.apply(start);
    final b = context.apply(end);
    sink.polyline(
      Float64List.fromList([a.x, a.y, b.x, b.y]),
      context.styleFor(props),
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2.fromCorners(start, end);

  @override
  LineEntity withId(int id) =>
      LineEntity(id: id, props: props, start: start, end: end);

  @override
  LineEntity withProps(EntityProps props) =>
      LineEntity(id: id, props: props, start: start, end: end);

  @override
  LineEntity transformed(Mat3 matrix) => LineEntity(
    id: id,
    props: props,
    start: matrix.transform(start),
    end: matrix.transform(end),
  );

  @override
  List<Vec2> grips() => [start, midpoint, end];

  @override
  CadEntity withGrip(int index, Vec2 target) => switch (index) {
    0 => LineEntity(id: id, props: props, start: target, end: end),
    1 => transformed(
      Mat3.translation(target.x - midpoint.x, target.y - midpoint.y),
    ),
    2 => LineEntity(id: id, props: props, start: start, end: target),
    _ => this,
  };

  @override
  Map<String, Object?> geometryToJson() => _$LineEntityToJson(this);
}

/// A lightweight polyline with optional per-vertex bulges.
///
/// [vertices] is interleaved `[x, y, bulge, ...]`, matching the LWPOLYLINE
/// layout so that DWG import needs no re-packing.
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
final class PolylineEntity extends CadEntity {
  const PolylineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.vertices,
    this.closed = false,
    this.constantWidth = 0,
  });

  factory PolylineEntity.fromPoints({
    required int id,
    EntityProps props = EntityProps.defaults,
    required List<Vec2> points,
    bool closed = false,
  }) {
    final buffer = Float64List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      buffer[i * 3] = points[i].x;
      buffer[i * 3 + 1] = points[i].y;
      buffer[i * 3 + 2] = 0;
    }
    return PolylineEntity(
      id: id,
      props: props,
      vertices: buffer,
      closed: closed,
    );
  }

  @JsonKey(toJson: vertexBufferToJson)
  final Float64List vertices;
  @JsonKey()
  final bool closed;
  @JsonKey(name: 'width', toJson: omitZero)
  final double constantWidth;

  int get vertexCount => vertices.length ~/ 3;

  Vec2 vertexAt(int index) =>
      Vec2(vertices[index * 3], vertices[index * 3 + 1]);

  double bulgeAt(int index) => vertices[index * 3 + 2];

  bool get hasBulges {
    for (var i = 0; i < vertexCount; i++) {
      if (vertices[i * 3 + 2] != 0) return true;
    }
    return false;
  }

  @override
  EntityKind get kind => EntityKind.polyline;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (vertexCount == 0) return;
    final flat = Flatten.polylineWithBulges(
      vertices: vertices,
      closed: closed,
      tolerance: context.tolerance,
    );
    final style = context.styleFor(props);
    if (constantWidth.abs() > 1e-12) {
      final stroke = Flatten.wideStroke(
        flat,
        constantWidth.abs(),
        closed: closed,
      );
      if (stroke != null) {
        sink.fill(
          context.applyBuffer(stroke.outer),
          style,
          holes: [
            if (stroke.hole != null) context.applyBuffer(stroke.hole!),
          ],
        );
        return;
      }
    }
    sink.polyline(
      context.applyBuffer(flat),
      style,
      closed: closed,
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final Bounds2 box;
    if (!hasBulges) {
      var acc = const Bounds2.empty();
      for (var i = 0; i < vertexCount; i++) {
        acc = acc.expandToInclude(vertices[i * 3], vertices[i * 3 + 1]);
      }
      box = acc;
    } else {
      box = Bounds2.fromXY(
        Flatten.polylineWithBulges(
          vertices: vertices,
          closed: closed,
          tolerance: tolerance,
        ),
      );
    }
    return constantWidth.abs() > 0 ? box.inflated(constantWidth.abs()) : box;
  }

  @override
  PolylineEntity withId(int id) => PolylineEntity(
    id: id,
    props: props,
    vertices: vertices,
    closed: closed,
    constantWidth: constantWidth,
  );

  @override
  PolylineEntity withProps(EntityProps props) => PolylineEntity(
    id: id,
    props: props,
    vertices: vertices,
    closed: closed,
    constantWidth: constantWidth,
  );

  @override
  PolylineEntity transformed(Mat3 matrix) {
    final out = Float64List(vertices.length);
    for (var i = 0; i < vertexCount; i++) {
      final p = matrix.transform(vertexAt(i));
      out[i * 3] = p.x;
      out[i * 3 + 1] = p.y;
      // A bulge is scale invariant but flips sign under a mirror.
      out[i * 3 + 2] = matrix.determinant < 0
          ? -vertices[i * 3 + 2]
          : vertices[i * 3 + 2];
    }
    return PolylineEntity(
      id: id,
      props: props,
      vertices: out,
      closed: closed,
      constantWidth: constantWidth * matrix.meanScale,
    );
  }

  @override
  List<Vec2> grips() => [
    for (var i = 0; i < vertexCount; i++) vertexAt(i),
  ];

  @override
  PolylineEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= vertexCount) return this;
    final out = Float64List.fromList(vertices);
    out[index * 3] = target.x;
    out[index * 3 + 1] = target.y;
    return PolylineEntity(
      id: id,
      props: props,
      vertices: out,
      closed: closed,
      constantWidth: constantWidth,
    );
  }

  @override
  Map<String, Object?> geometryToJson() => _$PolylineEntityToJson(this);
}

/// A full circle.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class CircleEntity extends CadEntity {
  const CircleEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.center,
    required this.radius,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 center;
  @JsonKey()
  final double radius;

  @override
  EntityKind get kind => EntityKind.circle;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (radius <= 0) return;
    final points = Flatten.circle(
      center: center,
      radius: radius,
      tolerance: context.tolerance,
    );
    sink.polyline(
      context.applyBuffer(points),
      context.styleFor(props),
      closed: true,
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(
    center.x - radius,
    center.y - radius,
    center.x + radius,
    center.y + radius,
  );

  @override
  CircleEntity withId(int id) =>
      CircleEntity(id: id, props: props, center: center, radius: radius);

  @override
  CircleEntity withProps(EntityProps props) =>
      CircleEntity(id: id, props: props, center: center, radius: radius);

  @override
  CadEntity transformed(Mat3 matrix) {
    final scaleX = math.sqrt(matrix.a * matrix.a + matrix.b * matrix.b);
    final scaleY = math.sqrt(matrix.c * matrix.c + matrix.d * matrix.d);
    if ((scaleX - scaleY).abs() < 1e-9) {
      return CircleEntity(
        id: id,
        props: props,
        center: matrix.transform(center),
        radius: radius * scaleX,
      );
    }
    // A non-uniform scale turns a circle into an ellipse. Recover principal
    // axes so SCALE Y > X does not produce a ratio greater than 1.
    return _affineEllipse(
      EllipseEntity(
        id: id,
        props: props,
        center: center,
        majorAxis: Vec2(radius, 0),
        ratio: 1,
      ),
      matrix,
    );
  }

  @override
  List<Vec2> grips() => [
    center,
    Vec2(center.x + radius, center.y),
    Vec2(center.x, center.y + radius),
    Vec2(center.x - radius, center.y),
    Vec2(center.x, center.y - radius),
  ];

  @override
  CircleEntity withGrip(int index, Vec2 target) => index == 0
      ? CircleEntity(id: id, props: props, center: target, radius: radius)
      : CircleEntity(
          id: id,
          props: props,
          center: center,
          radius: center.distanceTo(target),
        );

  @override
  Map<String, Object?> geometryToJson() => _$CircleEntityToJson(this);
}

/// A circular arc, swept counter-clockwise from [startAngle] to [endAngle].
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class ArcEntity extends CadEntity {
  const ArcEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 center;
  @JsonKey()
  final double radius;
  @JsonKey()
  final double startAngle;
  @JsonKey()
  final double endAngle;

  double get sweep => angularSweep(startAngle, endAngle);
  Vec2 get startPoint => center + Vec2.polar(startAngle, radius);
  Vec2 get endPoint => center + Vec2.polar(endAngle, radius);
  Vec2 get midPoint => center + Vec2.polar(startAngle + sweep / 2, radius);

  @override
  EntityKind get kind => EntityKind.arc;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (radius <= 0) return;
    final points = Flatten.arc(
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      tolerance: context.tolerance,
    );
    sink.polyline(context.applyBuffer(points), context.styleFor(props));
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    // Exact: the extremes are the endpoints plus whichever axis crossings the
    // sweep actually covers.
    var box = Bounds2.fromPoints([startPoint, endPoint]);
    const quadrants = [0.0, math.pi / 2, math.pi, math.pi * 3 / 2];
    final start = normalizeAngle(startAngle);
    final total = sweep == 0 ? math.pi * 2 : sweep;
    for (final quadrant in quadrants) {
      final delta = angularSweep(start, quadrant);
      if (delta <= total) {
        final p = center + Vec2.polar(quadrant, radius);
        box = box.expandToInclude(p.x, p.y);
      }
    }
    return box;
  }

  @override
  ArcEntity withId(int id) => ArcEntity(
    id: id,
    props: props,
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
  );

  @override
  ArcEntity withProps(EntityProps props) => ArcEntity(
    id: id,
    props: props,
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
  );

  @override
  ArcEntity transformed(Mat3 matrix) {
    final scale = matrix.meanScale;
    final mirrored = matrix.determinant < 0;
    final rotation = matrix.rotation;
    final start = mirrored
        ? math.pi - endAngle + rotation
        : startAngle + rotation;
    final end = mirrored
        ? math.pi - startAngle + rotation
        : endAngle + rotation;
    return ArcEntity(
      id: id,
      props: props,
      center: matrix.transform(center),
      radius: radius * scale,
      startAngle: start,
      endAngle: end,
    );
  }

  @override
  List<Vec2> grips() => [startPoint, midPoint, endPoint, center];

  @override
  ArcEntity withGrip(int index, Vec2 target) => switch (index) {
    0 => ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: (target - center).angle,
      endAngle: endAngle,
    ),
    2 => ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: (target - center).angle,
    ),
    3 => ArcEntity(
      id: id,
      props: props,
      center: target,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
    ),
    _ => ArcEntity(
      id: id,
      props: props,
      center: center,
      radius: center.distanceTo(target),
      startAngle: startAngle,
      endAngle: endAngle,
    ),
  };

  @override
  Map<String, Object?> geometryToJson() => _$ArcEntityToJson(this);
}

/// Rebuilds an ellipse after an affine map from its transformed conjugate
/// diameters. [ratio] stays ≤ 1; an elliptical arc keeps the image of its
/// start, mid and end so the sweep does not flip.
EllipseEntity _affineEllipse(EllipseEntity source, Mat3 matrix) {
  final center = matrix.transform(source.center);
  final axisA = matrix.transformDirection(source.majorAxis);
  final axisB = matrix.transformDirection(source.minorAxis);
  final uu = axisA.dot(axisA);
  final vv = axisB.dot(axisB);
  final uv = axisA.dot(axisB);
  final h = (uu + vv) / 2;
  final g = (uu - vv) / 2;
  final r = math.sqrt(g * g + uv * uv);
  final majorLen = math.sqrt(math.max(0.0, h + r));
  final minorLen = math.sqrt(math.max(0.0, h - r));
  if (majorLen < 1e-20) {
    return EllipseEntity(
      id: source.id,
      props: source.props,
      center: center,
      majorAxis: axisA,
      ratio: source.ratio,
      startParam: source.startParam,
      endParam: source.endParam,
    );
  }
  final alpha = 0.5 * math.atan2(2 * uv, uu - vv);
  var major = Vec2(math.cos(alpha), math.sin(alpha)) * majorLen;
  if (major.dot(axisA) < 0) major = -major;
  final ratio = (minorLen / majorLen).clamp(0.0, 1.0);
  if (source.isFullEllipse) {
    return EllipseEntity(
      id: source.id,
      props: source.props,
      center: center,
      majorAxis: major,
      ratio: ratio,
    );
  }
  final frame = EllipseEntity(
    id: 0,
    center: center,
    majorAxis: major,
    ratio: ratio,
  );
  final start = matrix.transform(source.startPoint);
  final end = matrix.transform(source.endPoint);
  final mid = matrix.transform(
    source.pointAt(source.startParam + source.sweep / 2),
  );
  var startParam = frame.paramOf(start);
  var endParam = frame.paramOf(end);
  final trial = EllipseEntity(
    id: 0,
    center: center,
    majorAxis: major,
    ratio: ratio,
    startParam: startParam,
    endParam: endParam,
  );
  if (!trial.containsParam(trial.paramOf(mid))) {
    final swap = startParam;
    startParam = endParam;
    endParam = swap;
  }
  return EllipseEntity(
    id: source.id,
    props: source.props,
    center: center,
    majorAxis: major,
    ratio: ratio,
    startParam: startParam,
    endParam: endParam,
  );
}

/// An ellipse or elliptical arc. Angles are ellipse parameters, as in DWG.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class EllipseEntity extends CadEntity {
  const EllipseEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.center,
    required this.majorAxis,
    required this.ratio,
    this.startParam = 0,
    this.endParam = math.pi * 2,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 center;

  /// Vector from the centre to the end of the major axis.
  @JsonKey(toJson: vec2ToJson)
  final Vec2 majorAxis;
  @JsonKey()
  final double ratio;
  @JsonKey()
  final double startParam;
  @JsonKey()
  final double endParam;

  /// DWG treats equal parameters as a full ellipse. `endParam` defaults to
  /// `2π`, which [normalizeAngle] wraps to 0, so the comparison has to be
  /// on the circle rather than on the raw numbers.
  bool get isFullEllipse {
    const eps = 1e-9;
    final delta =
        (normalizeAngle(endParam) - normalizeAngle(startParam)).abs();
    return delta < eps || (math.pi * 2 - delta).abs() < eps;
  }

  double get majorLength => majorAxis.length;

  /// The minor-axis vector, perpendicular to [majorAxis] and scaled by [ratio].
  Vec2 get minorAxis => majorAxis.perpendicular * ratio;

  /// Parameter sweep. A full ellipse is `2π`, not the 0 that equal
  /// start/end parameters would otherwise compute.
  double get sweep => isFullEllipse ? math.pi * 2 : angularSweep(startParam, endParam);

  Vec2 get startPoint => pointAt(startParam);
  Vec2 get endPoint => pointAt(endParam);

  /// The point at ellipse parameter [param], matching DWG (not a true angle).
  Vec2 pointAt(double param) =>
      center + majorAxis * math.cos(param) + minorAxis * math.sin(param);

  /// Maps [world] into the unit-circle space of this ellipse.
  ///
  /// The ellipse becomes `u² + v² = 1`, which is how line and circle
  /// intersections stay closed-form instead of falling back to flattening.
  Vec2 toUnit(Vec2 world) {
    final delta = world - center;
    final major = majorAxis;
    final minor = minorAxis;
    final det = major.cross(minor);
    if (det.abs() < 1e-18) return const Vec2.zero();
    return Vec2(delta.cross(minor) / det, major.cross(delta) / det);
  }

  Vec2 fromUnit(Vec2 unit) =>
      center + majorAxis * unit.x + minorAxis * unit.y;

  /// The ellipse parameter of [world], `atan2` of the unit-space coordinates.
  double paramOf(Vec2 world) {
    final unit = toUnit(world);
    return math.atan2(unit.y, unit.x);
  }

  /// Whether [param] lies on this ellipse or elliptical arc.
  bool containsParam(double param) {
    if (isFullEllipse) return true;
    return angularSweep(startParam, param) <= sweep + 1e-9;
  }

  @override
  EntityKind get kind => EntityKind.ellipse;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final points = Flatten.ellipse(
      center: center,
      major: majorAxis,
      ratio: ratio,
      startParam: startParam,
      endParam: endParam,
      tolerance: context.tolerance,
    );
    sink.polyline(
      context.applyBuffer(points),
      context.styleFor(props),
      closed: isFullEllipse,
    );
  }

  @override
  EllipseEntity withId(int id) => EllipseEntity(
    id: id,
    props: props,
    center: center,
    majorAxis: majorAxis,
    ratio: ratio,
    startParam: startParam,
    endParam: endParam,
  );

  @override
  EllipseEntity withProps(EntityProps props) => EllipseEntity(
    id: id,
    props: props,
    center: center,
    majorAxis: majorAxis,
    ratio: ratio,
    startParam: startParam,
    endParam: endParam,
  );

  @override
  EllipseEntity transformed(Mat3 matrix) => _affineEllipse(this, matrix);

  @override
  List<Vec2> grips() => [
    center,
    center + majorAxis,
    center - majorAxis,
    center + majorAxis.perpendicular * ratio,
    center - majorAxis.perpendicular * ratio,
  ];

  @override
  EllipseEntity withGrip(int index, Vec2 target) => index == 0
      ? EllipseEntity(
          id: id,
          props: props,
          center: target,
          majorAxis: majorAxis,
          ratio: ratio,
          startParam: startParam,
          endParam: endParam,
        )
      : index <= 2
      ? EllipseEntity(
          id: id,
          props: props,
          center: center,
          majorAxis: index == 1 ? target - center : center - target,
          ratio: ratio,
          startParam: startParam,
          endParam: endParam,
        )
      : EllipseEntity(
          id: id,
          props: props,
          center: center,
          majorAxis: majorAxis,
          ratio: majorAxis.length == 0
              ? ratio
              : (target - center).length / majorAxis.length,
          startParam: startParam,
          endParam: endParam,
        );

  @override
  Map<String, Object?> geometryToJson() => _$EllipseEntityToJson(this);
}

/// A NURBS curve.
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
final class SplineEntity extends CadEntity {
  const SplineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.controlPoints,
    this.knots = const [],
    this.weights = const [],
    this.degree = 3,
    this.closed = false,
    this.fitPoints,
  });

  /// Interleaved `[x, y, ...]`.
  @JsonKey(toJson: pointBufferToJson)
  final Float64List controlPoints;
  @JsonKey(toJson: doubleListToJsonIfNotEmpty)
  final List<double> knots;
  @JsonKey(toJson: doubleListToJsonIfNotEmpty)
  final List<double> weights;
  @JsonKey()
  final int degree;
  @JsonKey(toJson: omitFalse)
  final bool closed;

  /// Interleaved `[x, y, ...]` fit points, when the spline was defined by
  /// interpolation rather than by control points. Preserved for round-tripping.
  @JsonKey(toJson: optionalPointBufferToJson)
  final Float64List? fitPoints;

  Float64List get fitPointBuffer => fitPoints ?? _emptyBuffer;

  int get controlPointCount => controlPoints.length ~/ 2;

  @override
  EntityKind get kind => EntityKind.spline;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (controlPointCount == 0) return;
    final points = Flatten.bspline(
      controlPoints: controlPoints,
      knots: knots,
      degree: degree,
      weights: weights,
      tolerance: context.tolerance,
      closed: closed,
    );
    sink.polyline(
      context.applyBuffer(points),
      context.styleFor(props),
      closed: closed,
    );
  }

  @override
  SplineEntity withId(int id) => SplineEntity(
    id: id,
    props: props,
    controlPoints: controlPoints,
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    fitPoints: fitPoints,
  );

  @override
  SplineEntity withProps(EntityProps props) => SplineEntity(
    id: id,
    props: props,
    controlPoints: controlPoints,
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    fitPoints: fitPoints,
  );

  @override
  SplineEntity transformed(Mat3 matrix) => SplineEntity(
    id: id,
    props: props,
    controlPoints: _transformBuffer(controlPoints, matrix),
    knots: knots,
    weights: weights,
    degree: degree,
    closed: closed,
    fitPoints: _transformBuffer(fitPointBuffer, matrix),
  );

  @override
  List<Vec2> grips() => [
    for (var i = 0; i < controlPointCount; i++)
      Vec2(controlPoints[i * 2], controlPoints[i * 2 + 1]),
  ];

  @override
  SplineEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= controlPointCount) return this;
    final out = Float64List.fromList(controlPoints);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return SplineEntity(
      id: id,
      props: props,
      controlPoints: out,
      knots: knots,
      weights: weights,
      degree: degree,
      closed: closed,
      fitPoints: fitPoints,
    );
  }

  @override
  Map<String, Object?> geometryToJson() => _$SplineEntityToJson(this);
}

/// A node point.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class PointEntity extends CadEntity {
  const PointEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 position;

  @override
  EntityKind get kind => EntityKind.point;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final p = context.apply(position);
    sink.point(p.x, p.y, context.styleFor(props));
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(position.x, position.y, position.x, position.y);

  @override
  PointEntity withId(int id) =>
      PointEntity(id: id, props: props, position: position);

  @override
  PointEntity withProps(EntityProps props) =>
      PointEntity(id: id, props: props, position: position);

  @override
  PointEntity transformed(Mat3 matrix) =>
      PointEntity(id: id, props: props, position: matrix.transform(position));

  @override
  List<Vec2> grips() => [position];

  @override
  PointEntity withGrip(int index, Vec2 target) =>
      PointEntity(id: id, props: props, position: target);

  @override
  Map<String, Object?> geometryToJson() => _$PointEntityToJson(this);
}

// ---------------------------------------------------------------------------
// Annotation
// ---------------------------------------------------------------------------

/// Single-line text.
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
final class TextEntity extends CadEntity {
  const TextEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.position,
    required this.content,
    this.height = 2.5,
    this.rotation = 0,
    this.styleName = 'Standard',
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.hAlign = TextHAlign.left,
    this.vAlign = TextVAlign.baseline,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 position;
  @JsonKey(name: 'text')
  final String content;
  @JsonKey()
  final double height;
  @JsonKey(toJson: omitZero)
  final double rotation;
  @JsonKey(name: 'style')
  final String styleName;
  @JsonKey(toJson: omitOne)
  final double widthFactor;
  @JsonKey(name: 'oblique', toJson: omitZero)
  final double obliqueAngle;
  @JsonKey(toJson: _omitHAlign)
  final TextHAlign hAlign;
  @JsonKey(toJson: _omitVAlign)
  final TextVAlign vAlign;

  TextGeometry toGeometry(EmitContext context) => TextGeometry(
    text: content,
    origin: context.apply(position),
    height: height * (context.transform.isIdentity
        ? 1
        : context.transform.meanScale),
    rotation: rotation + context.transform.rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  EntityKind get kind => EntityKind.text;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (content.isEmpty) return;
    sink.text(toGeometry(context), context.styleFor(props));
  }

  @override
  TextEntity withId(int id) => TextEntity(
    id: id,
    props: props,
    position: position,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  TextEntity withProps(EntityProps props) => TextEntity(
    id: id,
    props: props,
    position: position,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  TextEntity withContent(String value) => TextEntity(
    id: id,
    props: props,
    position: position,
    content: value,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  TextEntity transformed(Mat3 matrix) => TextEntity(
    id: id,
    props: props,
    position: matrix.transform(position),
    content: content,
    height: height * matrix.meanScale,
    rotation: rotation + matrix.rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  List<Vec2> grips() => [position];

  @override
  TextEntity withGrip(int index, Vec2 target) => TextEntity(
    id: id,
    props: props,
    position: target,
    content: content,
    height: height,
    rotation: rotation,
    styleName: styleName,
    widthFactor: widthFactor,
    obliqueAngle: obliqueAngle,
    hAlign: hAlign,
    vAlign: vAlign,
  );

  @override
  Map<String, Object?> geometryToJson() => _$TextEntityToJson(this);
}

/// Multi-line, formatted text.
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
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
    final scale = context.transform.isIdentity
        ? 1.0
        : context.transform.meanScale;
    final runs = MTextLayout(measureWidth: context.measureWidth).layout(this);
    if (runs.isEmpty) return;
    final style = context.styleFor(props);
    final worldRotation = rotation + context.transform.rotation;
    for (final run in runs) {
      if (run.text.isEmpty) continue;
      final local = run.origin - position;
      final origin = rotation.abs() < 1e-12
          ? run.origin
          : position + local.rotated(rotation);
      sink.text(
        TextGeometry(
          text: run.text,
          origin: context.apply(origin),
          height: run.height * scale,
          rotation: worldRotation,
          styleName: run.font.isEmpty ? styleName : run.font,
          rectangleWidth: 0,
          hAlign: hAlign,
          vAlign: vAlign,
        ),
        style,
      );
    }
  }

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
  Map<String, Object?> geometryToJson() => _$MTextEntityToJson(this);
}

/// A dimension.
///
/// DWG stores the fully rendered dimension geometry in an anonymous `*D`
/// block. Rendering that block is exact and cheap, so it is the primary path;
/// the definition points are kept so the geometry can be regenerated after an
/// edit or when the block is missing.
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
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
      final horizontal =
          (points[2] - mid).y.abs() >= (points[2] - mid).x.abs();
      return horizontal
          ? (points[1].x - points[0].x).abs()
          : (points[1].y - points[0].y).abs();
    }
    return points[0].distanceTo(points[1]);
  }

  /// Degrees shown on an angular dimension.
  ///
  /// Definition points are `[vertex, first, second]`. The sweep is the
  /// counter-clockwise sector from the first arm to the second.
  static double measuredAngle(List<Vec2> points) {
    if (points.length < 3) return 0;
    final vertex = points[0];
    if (points[1].distanceTo(vertex) < 1e-12 ||
        points[2].distanceTo(vertex) < 1e-12) {
      return 0;
    }
    final start = (points[1] - vertex).angle;
    final end = (points[2] - vertex).angle;
    return angularSweep(start, end) * 180 / math.pi;
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
    final style = context.styleFor(props);
    if (hasRenderedBlock && context.canRecurse) {
      final ids = context.blocks.entityIdsOf(blockName);
      if (ids != null && ids.isNotEmpty) {
        context.blocks.emitBlock(
          blockName,
          context.descend(const Mat3.identity(), style),
          sink,
        );
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
    final points = [
      for (final p in definitionPoints) matrix.transform(p),
    ];
    final family = dimensionType & 0x0F;
    // Angles are not lengths: SCALE must not turn 45° into 90°. Linear and
    // aligned values are reread from the new origins. Radial still scales
    // by the mean factor because the chord is a seat, not the radius.
    final nextMeasurement = switch (family) {
      2 => measuredAngle(points),
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
      2 => measuredAngle(points),
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

/// A leader line, optionally with an arrow head.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class LeaderEntity extends CadEntity {
  const LeaderEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.vertices,
    this.hasArrowHead = true,
    this.styleName = 'Standard',
  });

  /// Interleaved `[x, y, ...]`.
  @JsonKey(toJson: pointBufferToJson)
  final Float64List vertices;
  @JsonKey(name: 'arrowHead')
  final bool hasArrowHead;
  @JsonKey(name: 'style')
  final String styleName;

  @override
  EntityKind get kind => EntityKind.leader;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (vertices.length < 4) return;
    final style = context.styleFor(props);
    final xy = context.applyBuffer(vertices);
    sink.polyline(xy, style);
    if (!hasArrowHead) return;
    final tip = Vec2(xy[0], xy[1]);
    final next = Vec2(xy[2], xy[3]);
    final dir = next - tip;
    final length = dir.length;
    if (length < 1e-9) return;
    final unit = dir / length;
    final scale =
        context.transform.isIdentity ? 1.0 : context.transform.meanScale;
    final size = math.min(2.5 * scale, length * 0.4);
    if (size < 1e-9) return;
    final left = tip + unit * size + unit.perpendicular * (size * 0.35);
    final right = tip + unit * size - unit.perpendicular * (size * 0.35);
    sink.fill(
      Float64List.fromList([tip.x, tip.y, left.x, left.y, right.x, right.y]),
      style,
    );
  }

  @override
  LeaderEntity withId(int id) => LeaderEntity(
    id: id,
    props: props,
    vertices: vertices,
    hasArrowHead: hasArrowHead,
    styleName: styleName,
  );

  @override
  LeaderEntity withProps(EntityProps props) => LeaderEntity(
    id: id,
    props: props,
    vertices: vertices,
    hasArrowHead: hasArrowHead,
    styleName: styleName,
  );

  @override
  LeaderEntity transformed(Mat3 matrix) => LeaderEntity(
    id: id,
    props: props,
    vertices: _transformBuffer(vertices, matrix),
    hasArrowHead: hasArrowHead,
    styleName: styleName,
  );

  @override
  List<Vec2> grips() => [
    for (var i = 0; i < vertices.length ~/ 2; i++)
      Vec2(vertices[i * 2], vertices[i * 2 + 1]),
  ];

  @override
  LeaderEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= vertices.length ~/ 2) return this;
    final out = Float64List.fromList(vertices);
    out[index * 2] = target.x;
    out[index * 2 + 1] = target.y;
    return LeaderEntity(
      id: id,
      props: props,
      vertices: out,
      hasArrowHead: hasArrowHead,
      styleName: styleName,
    );
  }

  @override
  Map<String, Object?> geometryToJson() => _$LeaderEntityToJson(this);
}

// ---------------------------------------------------------------------------
// Areas and references
// ---------------------------------------------------------------------------

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
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
final class HatchEntity extends CadEntity {
  const HatchEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.loops,
    this.patternName = 'SOLID',
    this.solid = true,
    this.patternAngle = 0,
    this.patternScale = 1,
  });

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
  );

  HatchEntity copyWith({
    String? patternName,
    bool? solid,
    double? patternAngle,
    double? patternScale,
  }) => HatchEntity(
    id: id,
    props: props,
    loops: loops,
    patternName: patternName ?? this.patternName,
    solid: solid ?? this.solid,
    patternAngle: patternAngle ?? this.patternAngle,
    patternScale: patternScale ?? this.patternScale,
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
    );
  }

  @override
  Map<String, Object?> geometryToJson() => _$HatchEntityToJson(this);
}

/// A block reference, optionally arrayed (MINSERT).
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
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
        final clip = context.clip;
        if (clip != null && blockBounds.isNotEmpty) {
          final worldBounds = blockBounds.transformed(
            context.transform.multiplied(local),
          );
          if (!worldBounds.intersects(clip)) continue;
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
  Map<String, Object?> geometryToJson() => {
    ..._$InsertEntityToJson(this),
    if (attributes.isNotEmpty) 'attributes': attributes,
  };
}

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
    final scale = context.transform.isIdentity
        ? 1.0
        : context.transform.meanScale;
    sink.text(
      TextGeometry(
        text: text,
        origin: context.apply(position),
        height: height * scale,
        rotation: rotation + context.transform.rotation,
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
    final scale = context.transform.isIdentity
        ? 1.0
        : context.transform.meanScale;
    sink.text(
      TextGeometry(
        text: value,
        origin: context.apply(position),
        height: height * scale,
        rotation: rotation + context.transform.rotation,
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

/// A filled triangle or quadrilateral (SOLID / 3DFACE).
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class SolidEntity extends CadEntity {
  const SolidEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.corners,
  });

  @JsonKey(toJson: vec2ListToJson)
  final List<Vec2> corners;

  @override
  EntityKind get kind => EntityKind.solid;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    if (corners.length < 3) return;
    final buffer = Float64List(corners.length * 2);
    for (var i = 0; i < corners.length; i++) {
      final p = context.apply(corners[i]);
      buffer[i * 2] = p.x;
      buffer[i * 2 + 1] = p.y;
    }
    sink.fill(buffer, context.styleFor(props));
  }

  @override
  SolidEntity withId(int id) =>
      SolidEntity(id: id, props: props, corners: corners);

  @override
  SolidEntity withProps(EntityProps props) =>
      SolidEntity(id: id, props: props, corners: corners);

  @override
  SolidEntity transformed(Mat3 matrix) => SolidEntity(
    id: id,
    props: props,
    corners: [for (final corner in corners) matrix.transform(corner)],
  );

  @override
  List<Vec2> grips() => corners;

  @override
  SolidEntity withGrip(int index, Vec2 target) {
    if (index < 0 || index >= corners.length) return this;
    final updated = [...corners];
    updated[index] = target;
    return SolidEntity(id: id, props: props, corners: updated);
  }

  @override
  Map<String, Object?> geometryToJson() => _$SolidEntityToJson(this);
}

/// A semi-infinite construction line.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class RayEntity extends CadEntity {
  const RayEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.origin,
    required this.direction,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 direction;

  /// Construction lines are unbounded, so they are clipped to a large multiple
  /// of the current view extents at emit time.
  static const double _extent = 1e7;

  @override
  EntityKind get kind => EntityKind.ray;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final unit = direction.normalized();
    if (unit.length == 0) return;
    final reach = context.clip?.diagonal ?? _extent;
    final a = context.apply(origin);
    final b = context.apply(origin + unit * math.max(reach * 2, _extent));
    sink.polyline(
      Float64List.fromList([a.x, a.y, b.x, b.y]),
      context.styleFor(props),
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(origin.x, origin.y, origin.x, origin.y);

  @override
  Bounds2 indexBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final unit = direction.normalized();
    if (unit.length == 0) return computeBounds();
    return Bounds2.fromPoints([origin, origin + unit * _extent]);
  }

  @override
  RayEntity withId(int id) =>
      RayEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  RayEntity withProps(EntityProps props) =>
      RayEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  RayEntity transformed(Mat3 matrix) => RayEntity(
    id: id,
    props: props,
    origin: matrix.transform(origin),
    direction: matrix.transformDirection(direction),
  );

  @override
  List<Vec2> grips() => [origin, origin + direction.normalized()];

  @override
  RayEntity withGrip(int index, Vec2 target) => index == 0
      ? RayEntity(
          id: id,
          props: props,
          origin: target,
          direction: direction,
        )
      : RayEntity(
          id: id,
          props: props,
          origin: origin,
          direction: target - origin,
        );

  @override
  Map<String, Object?> geometryToJson() => _$RayEntityToJson(this);
}

/// An infinite construction line.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class XLineEntity extends CadEntity {
  const XLineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.origin,
    required this.direction,
  });

  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 direction;

  static const double _extent = 1e7;

  @override
  EntityKind get kind => EntityKind.xline;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    final unit = direction.normalized();
    if (unit.length == 0) return;
    final reach = math.max((context.clip?.diagonal ?? _extent) * 2, _extent);
    final a = context.apply(origin - unit * reach);
    final b = context.apply(origin + unit * reach);
    sink.polyline(
      Float64List.fromList([a.x, a.y, b.x, b.y]),
      context.styleFor(props),
    );
  }

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => Bounds2(origin.x, origin.y, origin.x, origin.y);

  @override
  Bounds2 indexBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) {
    final unit = direction.normalized();
    if (unit.length == 0) return computeBounds();
    return Bounds2.fromPoints([
      origin - unit * _extent,
      origin + unit * _extent,
    ]);
  }

  @override
  XLineEntity withId(int id) =>
      XLineEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  XLineEntity withProps(EntityProps props) =>
      XLineEntity(id: id, props: props, origin: origin, direction: direction);

  @override
  XLineEntity transformed(Mat3 matrix) => XLineEntity(
    id: id,
    props: props,
    origin: matrix.transform(origin),
    direction: matrix.transformDirection(direction),
  );

  @override
  List<Vec2> grips() => [origin];

  @override
  XLineEntity withGrip(int index, Vec2 target) => index == 0
      ? XLineEntity(
          id: id,
          props: props,
          origin: target,
          direction: direction,
        )
      : XLineEntity(
          id: id,
          props: props,
          origin: origin,
          direction: target - origin,
        );

  @override
  Map<String, Object?> geometryToJson() => _$XLineEntityToJson(this);
}

/// A referenced raster image.
@JsonSerializable(createFactory: false, ignoreUnannotated: true)
final class ImageEntity extends CadEntity {
  const ImageEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.reference,
    required this.origin,
    required this.uVector,
    required this.vVector,
  });

  @JsonKey()
  final String reference;
  @JsonKey(toJson: vec2ToJson)
  final Vec2 origin;
  @JsonKey(name: 'u', toJson: vec2ToJson)
  final Vec2 uVector;
  @JsonKey(name: 'v', toJson: vec2ToJson)
  final Vec2 vVector;

  @override
  EntityKind get kind => EntityKind.image;

  @override
  void emit(EmitContext context, GeometrySink sink) {
    sink.image(
      ImageGeometry(
        reference: reference,
        origin: context.apply(origin),
        uVector: context.transform.transformDirection(uVector),
        vVector: context.transform.transformDirection(vVector),
      ),
      context.styleFor(props),
    );
  }

  @override
  ImageEntity withId(int id) => ImageEntity(
    id: id,
    props: props,
    reference: reference,
    origin: origin,
    uVector: uVector,
    vVector: vVector,
  );

  @override
  ImageEntity withProps(EntityProps props) => ImageEntity(
    id: id,
    props: props,
    reference: reference,
    origin: origin,
    uVector: uVector,
    vVector: vVector,
  );

  @override
  ImageEntity transformed(Mat3 matrix) => ImageEntity(
    id: id,
    props: props,
    reference: reference,
    origin: matrix.transform(origin),
    uVector: matrix.transformDirection(uVector),
    vVector: matrix.transformDirection(vVector),
  );

  @override
  List<Vec2> grips() => [
    origin,
    origin + uVector,
    origin + uVector + vVector,
    origin + vVector,
  ];

  @override
  ImageEntity withGrip(int index, Vec2 target) => index == 0
      ? ImageEntity(
          id: id,
          props: props,
          reference: reference,
          origin: target,
          uVector: uVector,
          vVector: vVector,
        )
      : this;

  @override
  Map<String, Object?> geometryToJson() => _$ImageEntityToJson(this);
}

/// An entity the importer could not translate.
///
/// Keeping these as first-class citizens matters for a professional tool: an
/// unsupported object must still appear in the drawing tree, occupy space, and
/// survive a save rather than silently disappearing.
@JsonSerializable(createFactory: false, includeIfNull: false, ignoreUnannotated: true)
final class UnknownEntity extends CadEntity {
  const UnknownEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.originalType,
    this.proxyBounds = const Bounds2.empty(),
  });

  /// The DWG type name, so the UI can explain what was skipped.
  @JsonKey()
  final String originalType;
  @JsonKey(toJson: proxyBoundsToJson)
  final Bounds2 proxyBounds;

  @override
  EntityKind get kind => EntityKind.unknown;

  @override
  void emit(EmitContext context, GeometrySink sink) {}

  @override
  Bounds2 computeBounds({
    BlockLookup blocks = BlockLookup.empty,
    double tolerance = 1e-3,
  }) => proxyBounds;

  @override
  UnknownEntity withId(int id) => UnknownEntity(
    id: id,
    props: props,
    originalType: originalType,
    proxyBounds: proxyBounds,
  );

  @override
  UnknownEntity withProps(EntityProps props) => UnknownEntity(
    id: id,
    props: props,
    originalType: originalType,
    proxyBounds: proxyBounds,
  );

  @override
  UnknownEntity transformed(Mat3 matrix) => UnknownEntity(
    id: id,
    props: props,
    originalType: originalType,
    proxyBounds: proxyBounds.transformed(matrix),
  );

  @override
  List<Vec2> grips() => const [];

  @override
  UnknownEntity withGrip(int index, Vec2 target) => this;

  @override
  Map<String, Object?> geometryToJson() => _$UnknownEntityToJson(this);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final Float64List _emptyBuffer = Float64List(0);

Float64List _transformBuffer(Float64List xy, Mat3 matrix) {
  final out = Float64List(xy.length);
  for (var i = 0; i < xy.length; i += 2) {
    matrix.transformXYInto(xy[i], xy[i + 1], out, i);
  }
  return out;
}

/// Removes MTEXT inline formatting, keeping the readable content.
String stripMTextFormatting(String raw) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < raw.length) {
    final char = raw[index];
    if (char == '\\' && index + 1 < raw.length) {
      final code = raw[index + 1];
      switch (code) {
        case 'P':
        case 'p':
          buffer.write('\n');
          index += 2;
          continue;
        case '~':
          buffer.write(' ');
          index += 2;
          continue;
        case '\\':
        case '{':
        case '}':
          buffer.write(code);
          index += 2;
          continue;
        default:
          // Formatting directives run until the terminating semicolon.
          final terminator = raw.indexOf(';', index);
          if (terminator == -1) {
            index += 2;
          } else {
            index = terminator + 1;
          }
          continue;
      }
    }
    if (char == '{' || char == '}') {
      index++;
      continue;
    }
    buffer.write(char);
    index++;
  }
  return buffer.toString();
}

Vec2 _point(Object? value, {Vec2 fallback = const Vec2.zero()}) =>
    vec2FromJson(value, fallback: fallback);

List<Vec2> _pointList(Object? value) => vec2ListFromJson(value);

Float64List _pointBuffer(Object? value) => pointBufferFromJson(value);

/// Parses `[[x, y, bulge], ...]` into the interleaved LWPOLYLINE layout.
Float64List _vertexBuffer(Object? value) => vertexBufferFromJson(value);

List<double> _doubleList(Object? value) => doubleListFromJson(value);

List<int> _idList(Object? value) => idListFromJson(value);

List<HatchLoop> _loopList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map<String, Object?>)
        HatchLoop(
          vertices: pointBufferFromJson(item['points']),
          isOuter: item['outer'] as bool? ?? true,
        ),
  ];
}

List<Map<String, Object?>> _hatchLoopsToJson(List<HatchLoop> loops) => [
  for (final loop in loops)
    {
      'outer': loop.isOuter,
      'points': pointBufferToJson(loop.vertices),
    },
];

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: '${entry.value ?? ''}',
  };
}

String? _omitHAlign(TextHAlign value) =>
    enumToJsonIfNot(value, TextHAlign.left);

String? _omitVAlign(TextVAlign value) =>
    enumToJsonIfNot(value, TextVAlign.baseline);

int? _omitAttachment(int value) => value == 1 ? null : value;

T _enumOf<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    enumFromJson(values, raw, fallback);
