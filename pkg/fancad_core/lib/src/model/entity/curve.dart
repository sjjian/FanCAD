part of 'entity.dart';

/// A path from a start to an end that TRIM, EXTEND, LENGTHEN, BREAK and
/// DIVIDE edit by parameter instead of by entity type.
///
/// The parameter runs from 0 at the start to 1 at the end. On a line, an
/// arc, a polyline and a spline it is proportional to length; on an ellipse
/// it follows the ellipse parameter. A loop (circle, full ellipse, closed
/// polyline or spline) wraps: 1 is the start again.
sealed class Curve implements CadEntity {
  /// Whether the path closes on itself, so it has no free ends.
  bool get isLoop;

  /// The point at parameter [t].
  Vec2 along(double t);

  /// The parameter of the point on the curve nearest [point], in `[0, 1]`
  /// (`[0, 1)` on a loop).
  double paramNear(Vec2 point);

  /// The piece from [from] to [to], keeping this entity's id and props.
  ///
  /// On an open curve `from < to`, and either may fall outside `[0, 1]`:
  /// the curve then continues past that end the way it is heading — a
  /// straight end along its line, a round end around its circle — up to
  /// [maxGrowth]. On a loop both lie in `[0, 1]` and the piece runs forward,
  /// across the seam when `to <= from`. Null when the piece is empty or the
  /// curve cannot represent it.
  CadEntity? span(double from, double to);

  /// How far past its start or end, in parameter units, [span] can reach.
  /// Infinite for a straight end, short of closing for a round one, 0 on
  /// a loop.
  double maxGrowth({required bool atStart});
}

const _paramEps = 1e-12;

/// The rest of the circle an arc of [sweep] can grow into before it closes,
/// in units of [sweep]. Kept just inside the `2π - 1e-9` that [Curve.span]
/// refuses, so growing by exactly this much still succeeds.
double _roomBeforeClosing(double sweep) =>
    sweep < 1e-12 ? 0 : math.max(0, math.pi * 2 - 2e-9 - sweep) / sweep;

/// Where [angle] falls along a CCW sweep from [start], as a fraction of
/// [sweep]. Outside the sweep it snaps to whichever end is angularly closer.
double _fractionOfSweep(double start, double sweep, double angle) {
  if (sweep < 1e-12) return 0;
  final along = angularSweep(start, angle);
  if (along <= sweep + 1e-9) return (along / sweep).clamp(0.0, 1.0);
  return along - sweep < math.pi * 2 - along ? 1 : 0;
}

/// One straight or bulged polyline segment, as [Curve] on a polyline
/// walks it by distance.
///
/// A round segment keeps its circle rather than re-deriving it from the
/// chord: a segment grown close to a full turn has a chord too short to
/// recover the centre from.
class _PolySeg {
  factory _PolySeg(Vec2 from, Vec2 to, double bulge) {
    final def = bulge.abs() < 1e-12 ? null : Flatten.bulgeArc(from, to, bulge);
    if (def == null) return _PolySeg._line(from, to);
    return _PolySeg._arc(
      def.center,
      def.radius,
      (from - def.center).angle,
      4 * math.atan(bulge),
    );
  }

  _PolySeg._line(this.from, this.to)
    : center = null,
      radius = 0,
      startAngle = 0,
      sweep = 0,
      length = from.distanceTo(to);

  _PolySeg._arc(Vec2 this.center, this.radius, this.startAngle, this.sweep)
    : from = center + Vec2.polar(startAngle, radius),
      to = center + Vec2.polar(startAngle + sweep, radius),
      length = radius * sweep.abs();

  final Vec2 from;
  final Vec2 to;
  final double length;
  final Vec2? center;
  final double radius;
  final double startAngle;

  /// Signed: positive runs counter-clockwise.
  final double sweep;

  bool get isStraight => center == null;

  double get bulge => isStraight ? 0 : math.tan(sweep / 4);

  /// The point [distance] from [from] along this segment's line or circle;
  /// [distance] may be negative or past [length].
  Vec2 pointAt(double distance) {
    if (length < 1e-12) return from;
    final t = distance / length;
    if (center case final c?) {
      return c + Vec2.polar(startAngle + sweep * t, radius);
    }
    return from + (to - from) * t;
  }

  /// The bulge of the piece from [a] to [b], both distances from [from].
  double bulgeBetween(double a, double b) {
    if (isStraight || length < 1e-12) return 0;
    return math.tan(sweep * (b - a) / length / 4);
  }

  /// This segment continued [before] back past [from] and [after] on past
  /// [to]. Null when a round segment would close its circle.
  _PolySeg? grown({double before = 0, double after = 0}) {
    if (before <= 0 && after <= 0) return this;
    if (length < 1e-12) return null;
    final c = center;
    if (c == null) {
      return _PolySeg._line(pointAt(-before), pointAt(length + after));
    }
    final perLength = sweep / length;
    final newSweep = sweep + perLength * (before + after);
    if (newSweep.abs() >= math.pi * 2 - 1e-9) return null;
    return _PolySeg._arc(c, radius, startAngle - perLength * before, newSweep);
  }

  /// Distance from [from] to the point of this segment nearest [point].
  double distanceNear(Vec2 point) {
    if (length < 1e-12) return 0;
    final c = center;
    if (c == null) {
      final delta = to - from;
      return ((point - from).dot(delta) / delta.lengthSquared).clamp(0.0, 1.0) *
          length;
    }
    final angle = (point - c).angle;
    final fraction = sweep >= 0
        ? _fractionOfSweep(startAngle, sweep, angle)
        : _fractionOfSweep(-startAngle, -sweep, -angle);
    return fraction * length;
  }

  /// Squared distance from [point] to the segment.
  double gapTo(Vec2 point) =>
      pointAt(distanceNear(point)).distanceSquaredTo(point);
}

extension _PolylineCurve on PolylineEntity {
  List<_PolySeg> get _segments {
    final count = vertexCount;
    final segments = closed ? count : count - 1;
    return [
      for (var i = 0; i < segments; i++)
        _PolySeg(vertexAt(i), vertexAt((i + 1) % count), bulgeAt(i)),
    ];
  }

  /// The open polyline that walks [segments] from distance [from] to [to].
  PolylineEntity? _walk(List<_PolySeg> segments, double from, double to) {
    final points = <Vec2>[];
    final bulges = <double>[];
    var start = 0.0;
    for (final segment in segments) {
      final end = start + segment.length;
      if (segment.length < 1e-12 || end <= from + 1e-12) {
        start = end;
        continue;
      }
      if (start >= to - 1e-12) break;
      final a = math.max(from, start) - start;
      final b = math.min(to, end) - start;
      if (points.isEmpty) {
        points.add(segment.pointAt(a));
        bulges.add(0);
      }
      bulges[bulges.length - 1] = segment.bulgeBetween(a, b);
      points.add(segment.pointAt(b));
      bulges.add(0);
      start = end;
    }
    if (points.length < 2) return null;
    final buffer = Float64List(points.length * 3);
    for (var i = 0; i < points.length; i++) {
      buffer[i * 3] = points[i].x;
      buffer[i * 3 + 1] = points[i].y;
      buffer[i * 3 + 2] = bulges[i];
    }
    return PolylineEntity(
      id: id,
      props: props,
      vertices: buffer,
      constantWidth: constantWidth,
    );
  }
}

extension _SplineCurve on SplineEntity {
  static final _centrelines = Expando<PolylineEntity>();

  /// The flattened centreline TRIM and EXTEND have always cut, as a
  /// polyline. A NURBS split is not a NURBS of the same knots.
  PolylineEntity get _asPolyline => _centrelines[this] ??= () {
    final xy = _centreline(1e-3);
    return PolylineEntity.fromPoints(
      id: id,
      props: props,
      points: [
        for (var i = 0; i + 1 < xy.length; i += 2) Vec2(xy[i], xy[i + 1]),
      ],
      closed: closed,
    );
  }();
}
