// ignore_for_file: invalid_annotation_target

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import '../annotation/dimension.dart';
import '../geometry/bounds.dart';
import '../geometry/flatten.dart';
import '../geometry/intersect.dart';
import '../geometry/matrix.dart';
import '../geometry/vector.dart';
import '../hatch/generator.dart';
import '../text/mtext_layout.dart';
import 'geometry_sink.dart';
import 'json_converters.dart';
import 'style.dart';

part 'entity.g.dart';

part 'entity_line.dart';
part 'entity_polyline.dart';
part 'entity_circle.dart';
part 'entity_arc.dart';
part 'entity_ellipse.dart';
part 'entity_spline.dart';
part 'entity_point.dart';
part 'entity_text.dart';
part 'entity_mtext.dart';
part 'entity_dimension.dart';
part 'entity_leader.dart';
part 'entity_mleader.dart';
part 'entity_hatch.dart';
part 'entity_insert.dart';
part 'entity_attdef.dart';
part 'entity_attrib.dart';
part 'entity_solid.dart';
part 'entity_ray.dart';
part 'entity_xline.dart';
part 'entity_image.dart';
part 'entity_unknown.dart';

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
  mleader,
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
    emit(EmitContext(tolerance: tolerance, blocks: blocks), sink);
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

  /// Offsets this entity by [distance] to whichever side [towards] falls on.
  ///
  /// Types that have no parallel curve return null. Offset copies keep id 0
  /// so the command can assign a new handle.
  CadEntity? offsetBy(double distance, Vec2 towards) => null;

  /// Moves the vertices that sit inside [window] by [delta].
  ///
  /// That is the AutoCAD STRETCH contract: a crossing window names the grips
  /// that travel, and everything else stays anchored. The default matches the
  /// old Construct fallback — an object whose whole box is inside the window
  /// translates as a rigid body. Types with independent grips override.
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    return window.containsBox(computeBounds())
        ? transformed(Mat3.translation(delta.x, delta.y))
        : null;
  }

  /// Reverses direction. Lines, polylines and splines stay the same type;
  /// an arc becomes a two-vertex polyline so the curve can run clockwise
  /// without a clockwise flag. Circles and ellipses return null.
  CadEntity? reversed() => null;

  /// Path length for the measurement tools. Zero when the type has no length.
  double get pathLength => 0;

  /// Signed enclosed area. Positive is counter-clockwise. Zero when open.
  double get signedArea => 0;

  /// STRETCH helper: move every grip inside [window] independently.
  CadEntity? stretchIndependentGrips(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    final points = grips();
    var result = this;
    var changed = false;
    for (var i = 0; i < points.length; i++) {
      if (!_inStretchWindow(window, points[i])) continue;
      result = result.withGrip(i, points[i] + delta);
      changed = true;
    }
    return changed ? result : null;
  }

  static CadEntity fromJson(Map<String, Object?> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final props = EntityProps.fromJson(json);
    final kind = EntityKind.parse(json['type'] as String? ?? 'unknown');
    return switch (kind) {
      EntityKind.line => LineEntity.fromGeometry(id, props, json),
      EntityKind.polyline => PolylineEntity.fromGeometry(id, props, json),
      EntityKind.circle => CircleEntity.fromGeometry(id, props, json),
      EntityKind.arc => ArcEntity.fromGeometry(id, props, json),
      EntityKind.ellipse => EllipseEntity.fromGeometry(id, props, json),
      EntityKind.spline => SplineEntity.fromGeometry(id, props, json),
      EntityKind.point => PointEntity.fromGeometry(id, props, json),
      EntityKind.text => TextEntity.fromGeometry(id, props, json),
      EntityKind.mtext => MTextEntity.fromGeometry(id, props, json),
      EntityKind.insert => InsertEntity.fromGeometry(id, props, json),
      EntityKind.attdef => AttdefEntity.fromGeometry(id, props, json),
      EntityKind.attrib => AttribEntity.fromGeometry(id, props, json),
      EntityKind.hatch => HatchEntity.fromGeometry(id, props, json),
      EntityKind.dimension => DimensionEntity.fromGeometry(id, props, json),
      EntityKind.leader => LeaderEntity.fromGeometry(id, props, json),
      EntityKind.mleader => MLeaderEntity.fromGeometry(id, props, json),
      EntityKind.solid => SolidEntity.fromGeometry(id, props, json),
      EntityKind.ray => RayEntity.fromGeometry(id, props, json),
      EntityKind.xline => XLineEntity.fromGeometry(id, props, json),
      EntityKind.image => ImageEntity.fromGeometry(id, props, json),
      EntityKind.unknown => UnknownEntity.fromGeometry(id, props, json),
    };
  }

  @override
  String toString() => '${kind.name}#$id';
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final Float64List _emptyBuffer = Float64List(0);

void _emitArrowHead(
  EmitContext context,
  GeometrySink sink,
  ResolvedStyle style,
  Float64List xy,
) {
  if (xy.length < 4) return;
  final tip = Vec2(xy[0], xy[1]);
  final next = Vec2(xy[2], xy[3]);
  final dir = next - tip;
  final length = dir.length;
  if (length < 1e-9) return;
  final unit = dir / length;
  final scale = context.transform.isIdentity
      ? 1.0
      : context.transform.meanScale;
  final size = math.min(2.5 * scale, length * 0.4);
  if (size < 1e-9) return;
  final left = tip + unit * size + unit.perpendicular * (size * 0.35);
  final right = tip + unit * size - unit.perpendicular * (size * 0.35);
  sink.fill(
    Float64List.fromList([tip.x, tip.y, left.x, left.y, right.x, right.y]),
    style,
  );
}

Float64List _transformBuffer(Float64List xy, Mat3 matrix) {
  final out = Float64List(xy.length);
  for (var i = 0; i < xy.length; i += 2) {
    matrix.transformXYInto(xy[i], xy[i + 1], out, i);
  }
  return out;
}

/// Expands the `%%` control codes TEXT entities still carry after import.
String expandDxfTextCodes(String raw) {
  if (!raw.contains('%%')) return raw;
  final buffer = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    if (raw[i] == '%' && i + 1 < raw.length && raw[i + 1] == '%') {
      if (i + 2 < raw.length) {
        final code = raw[i + 2].toLowerCase();
        switch (code) {
          case 'c':
            buffer.write('Ø');
            i += 3;
            continue;
          case 'd':
            buffer.write('°');
            i += 3;
            continue;
          case 'p':
            buffer.write('±');
            i += 3;
            continue;
          case '%':
            buffer.write('%');
            i += 3;
            continue;
        }
      }
      if (i + 4 < raw.length) {
        final digits = raw.substring(i + 2, i + 5);
        final value = int.tryParse(digits);
        if (value != null) {
          buffer.writeCharCode(value);
          i += 5;
          continue;
        }
      }
    }
    buffer.write(raw[i]);
    i++;
  }
  return buffer.toString();
}

/// Removes MTEXT inline formatting, keeping the readable content.
String stripMTextFormatting(String raw) => decodeMTextPlain(raw);

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
    {'outer': loop.isOuter, 'points': pointBufferToJson(loop.vertices)},
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

bool _inStretchWindow(Bounds2 window, Vec2 point) =>
    window.containsPoint(point.x, point.y);
