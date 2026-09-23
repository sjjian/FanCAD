part of 'entity.dart';

/// A lightweight polyline with optional per-vertex bulges.
///
/// [vertices] is interleaved `[x, y, bulge, ...]`, matching the LWPOLYLINE
/// layout so that DWG import needs no re-packing.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
final class PolylineEntity extends CadEntity {
  const PolylineEntity({
    required super.id,
    super.props = EntityProps.defaults,
    required this.vertices,
    this.closed = false,
    this.constantWidth = 0,
  });

  static PolylineEntity fromGeometry(
    int id,
    EntityProps props,
    Map<String, Object?> json,
  ) => PolylineEntity(
    id: id,
    props: props,
    vertices: _vertexBuffer(json['vertices']),
    closed: json['closed'] as bool? ?? false,
    constantWidth: (json['width'] as num?)?.toDouble() ?? 0,
  );

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
    if (emitAsPixel(context, sink, context.extentHint ?? computeBounds())) {
      return;
    }
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
          holes: [if (stroke.hole != null) context.applyBuffer(stroke.hole!)],
        );
        return;
      }
    }
    sink.polyline(context.applyBuffer(flat), style, closed: closed);
  }

  @override
  void emitObjectSnaps(ObjectSnapSink sink) {
    final count = vertexCount;
    for (var i = 0; i < count; i++) {
      sink.endpoint(vertexAt(i));
    }
    final segments = closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      final a = vertexAt(i);
      final b = vertexAt((i + 1) % count);
      // A bulged segment is an arc, so its chord midpoint is not on it.
      if (bulgeAt(i) == 0) {
        sink.midpoint(a.lerp(b, 0.5));
        sink.segment(a, b);
      }
    }
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
  List<Vec2> grips() => [for (var i = 0; i < vertexCount; i++) vertexAt(i)];

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
  CadEntity? offsetBy(double distance, Vec2 towards) {
    if (hasBulges) return _offsetBulged(distance, towards);
    final count = vertexCount;
    if (count < 2) return null;
    final points = [for (var i = 0; i < count; i++) vertexAt(i)];
    final segmentCount = closed ? count : count - 1;

    // Decide the side once, from the segment nearest the pick, so the whole
    // polyline offsets coherently instead of segment by segment.
    var bestDistance = double.infinity;
    var sign = 1.0;
    for (var i = 0; i < segmentCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % count];
      final foot = Intersect.closestPointOnSegment(towards, a, b);
      final gap = foot.distanceTo(towards);
      if (gap < bestDistance) {
        bestDistance = gap;
        final normal = (b - a).normalized().perpendicular;
        sign = normal.dot(towards - a) >= 0 ? 1.0 : -1.0;
      }
    }

    // Offset each segment as an infinite line, then intersect consecutive ones
    // to find the new vertices.
    final lines = <(Vec2, Vec2)>[];
    for (var i = 0; i < segmentCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % count];
      final direction = (b - a).normalized();
      if (direction.length == 0) continue;
      final shift = direction.perpendicular * (distance * sign);
      lines.add((a + shift, b + shift));
    }
    if (lines.isEmpty) return null;

    final result = <Vec2>[];
    if (!closed) result.add(lines.first.$1);
    final joints = closed ? lines.length : lines.length - 1;
    for (var i = 0; i < joints; i++) {
      final current = lines[i];
      final next = lines[(i + 1) % lines.length];
      final joint = Intersect.lineLine(
        current.$1,
        current.$2,
        next.$1,
        next.$2,
      );
      // Parallel neighbours (a straight-through vertex) have no intersection;
      // the shared offset endpoint is the right answer there.
      result.add(joint ?? current.$2);
    }
    if (!closed) result.add(lines.last.$2);
    if (result.length < 2) return null;

    return PolylineEntity.fromPoints(
      id: 0,
      props: props,
      points: result,
      closed: closed,
    );
  }

  /// Offsets a polyline by moving each segment and re-intersecting neighbours.
  ///
  /// Miter joins rather than round ones, because the mitered offset of a
  /// rectangle is another rectangle, which is what a user expects to get.
  /// A bulge is offset as a concentric arc so a filleted profile stays
  /// filleted instead of collapsing to chords.
  PolylineEntity? _offsetBulged(double distance, Vec2 towards) {
    final count = vertexCount;
    if (count < 2) return null;
    final segmentCount = closed ? count : count - 1;

    var bestDistance = double.infinity;
    var sign = 1.0;
    for (var i = 0; i < segmentCount; i++) {
      final a = vertexAt(i);
      final b = vertexAt((i + 1) % count);
      final foot = Intersect.closestPointOnSegment(towards, a, b);
      final gap = foot.distanceTo(towards);
      if (gap < bestDistance) {
        bestDistance = gap;
        final normal = (b - a).normalized().perpendicular;
        sign = normal.dot(towards - a) >= 0 ? 1.0 : -1.0;
      }
    }

    final arms = <_OffsetArm>[];
    for (var i = 0; i < segmentCount; i++) {
      final arm = _offsetArm(i, distance, sign);
      if (arm == null) return null;
      arms.add(arm);
    }
    if (arms.isEmpty) return null;

    final points = <Vec2>[];
    if (!closed) points.add(arms.first.start);
    final joints = closed ? arms.length : arms.length - 1;
    for (var i = 0; i < joints; i++) {
      final current = arms[i];
      final next = arms[(i + 1) % arms.length];
      points.add(_offsetArmJoint(current, next) ?? current.end);
    }
    if (!closed) points.add(arms.last.end);
    if (points.length < 2) return null;

    final out = Float64List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      out[i * 3] = points[i].x;
      out[i * 3 + 1] = points[i].y;
      final armIndex = closed ? i : (i < arms.length ? i : -1);
      out[i * 3 + 2] = armIndex < 0
          ? 0
          : arms[armIndex].bulgeBetween(
              points[i],
              points[(i + 1) % points.length],
            );
    }
    return PolylineEntity(
      id: 0,
      props: props,
      vertices: out,
      closed: closed,
      constantWidth: constantWidth,
    );
  }

  _OffsetArm? _offsetArm(int index, double distance, double sign) {
    final start = vertexAt(index);
    final end = vertexAt((index + 1) % vertexCount);
    final direction = end - start;
    if (direction.lengthSquared < 1e-20) return null;
    final bulge = bulgeAt(index);
    if (bulge.abs() < 1e-12) {
      final shift = direction.normalized().perpendicular * (distance * sign);
      return _OffsetArm.line(start + shift, end + shift);
    }
    final def = Flatten.bulgeArc(start, end, bulge);
    if (def == null) return null;
    final chordNormal = direction.normalized().perpendicular;
    final centerIsLeft = chordNormal.dot(def.center - start) > 0;
    final grow = (sign > 0) != centerIsLeft;
    final radius = grow ? def.radius + distance : def.radius - distance;
    if (radius <= 0) return null;
    final startAngle = (start - def.center).angle;
    final endAngle = (end - def.center).angle;
    return _OffsetArm.arc(
      def.center + Vec2.polar(startAngle, radius),
      def.center + Vec2.polar(endAngle, radius),
      def.center,
      radius,
      bulge,
    );
  }

  @override
  CadEntity? stretchBy(Bounds2 window, Vec2 delta) {
    if (delta.lengthSquared < 1e-20) return null;
    var any = false;
    final out = Float64List.fromList(vertices);
    for (var i = 0; i < vertexCount; i++) {
      final x = out[i * 3];
      final y = out[i * 3 + 1];
      if (!window.containsPoint(x, y)) continue;
      any = true;
      out[i * 3] = x + delta.x;
      out[i * 3 + 1] = y + delta.y;
    }
    if (!any) return null;
    return PolylineEntity(
      id: id,
      props: props,
      vertices: out,
      closed: closed,
      constantWidth: constantWidth,
    );
  }

  @override
  CadEntity? reversed() {
    final count = vertexCount;
    if (count < 2) return null;
    final out = Float64List(count * 3);
    for (var i = 0; i < count; i++) {
      final source = count - 1 - i;
      out[i * 3] = vertices[source * 3];
      out[i * 3 + 1] = vertices[source * 3 + 1];
      if (closed) {
        final bulgeFrom = (count - 2 - i) % count;
        out[i * 3 + 2] = -bulgeAt(bulgeFrom);
      } else if (i < count - 1) {
        out[i * 3 + 2] = -bulgeAt(count - 2 - i);
      } else {
        out[i * 3 + 2] = 0;
      }
    }
    return PolylineEntity(
      id: id,
      props: props,
      vertices: out,
      closed: closed,
      constantWidth: constantWidth,
    );
  }

  @override
  double get pathLength {
    var total = 0.0;
    final count = vertexCount;
    final segments = closed ? count : count - 1;
    for (var i = 0; i < segments; i++) {
      total += _bulgeSegmentLength(
        vertexAt(i),
        vertexAt((i + 1) % count),
        bulgeAt(i),
      );
    }
    return total;
  }

  @override
  double get signedArea {
    if (!closed) return 0;
    var sum = 0.0;
    final count = vertexCount;
    for (var i = 0; i < count; i++) {
      final a = vertexAt(i);
      final b = vertexAt((i + 1) % count);
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  @override
  Map<String, Object?> geometryToJson() => _$PolylineEntityToJson(this);
}

double _bulgeSegmentLength(Vec2 from, Vec2 to, double bulge) {
  if (bulge.abs() < 1e-12) return from.distanceTo(to);
  final def = Flatten.bulgeArc(from, to, bulge);
  if (def == null) return from.distanceTo(to);
  return def.radius * (4 * math.atan(bulge)).abs();
}

Vec2? _offsetArmJoint(_OffsetArm current, _OffsetArm next) {
  final hits = current.hits(next);
  if (hits.isEmpty) return null;
  final hint = current.end.lerp(next.start, 0.5);
  var best = hits.first;
  var bestGap = best.distanceSquaredTo(hint);
  for (var i = 1; i < hits.length; i++) {
    final gap = hits[i].distanceSquaredTo(hint);
    if (gap < bestGap) {
      best = hits[i];
      bestGap = gap;
    }
  }
  return best;
}

/// One offset segment of a bulged polyline, either a line or a concentric arc.
class _OffsetArm {
  const _OffsetArm.line(this.start, this.end)
    : center = null,
      radius = 0,
      bulge = 0;

  const _OffsetArm.arc(
    this.start,
    this.end,
    this.center,
    this.radius,
    this.bulge,
  );

  final Vec2 start;
  final Vec2 end;
  final Vec2? center;
  final double radius;
  final double bulge;

  List<Vec2> hits(_OffsetArm other) {
    final ownCenter = center;
    final otherCenter = other.center;
    if (ownCenter == null && otherCenter == null) {
      final hit = Intersect.lineLine(start, end, other.start, other.end);
      return hit == null ? const [] : [hit];
    }
    if (ownCenter != null && otherCenter != null) {
      return Intersect.circleCircle(
        ownCenter,
        radius,
        otherCenter,
        other.radius,
      );
    }
    if (ownCenter != null) {
      return Intersect.lineCircle(other.start, other.end, ownCenter, radius);
    }
    return Intersect.lineCircle(start, end, otherCenter!, other.radius);
  }

  double bulgeBetween(Vec2 from, Vec2 to) {
    final ownCenter = center;
    if (ownCenter == null || bulge.abs() < 1e-12) return 0;
    final a0 = (from - ownCenter).angle;
    final a1 = (to - ownCenter).angle;
    return bulge >= 0
        ? math.tan(angularSweep(a0, a1) / 4)
        : -math.tan(angularSweep(a1, a0) / 4);
  }
}
