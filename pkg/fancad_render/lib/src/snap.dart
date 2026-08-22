import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

import 'picking.dart';
import 'viewport.dart';

/// The object snap modes a user can turn on, matching AutoCAD's OSMODE bits in
/// spirit if not in numeric value.
enum SnapMode {
  endpoint,
  midpoint,
  center,
  quadrant,
  intersection,
  perpendicular,
  tangent,
  node,
  nearest;

  String get label => switch (this) {
    SnapMode.endpoint => 'Endpoint',
    SnapMode.midpoint => 'Midpoint',
    SnapMode.center => 'Center',
    SnapMode.quadrant => 'Quadrant',
    SnapMode.intersection => 'Intersection',
    SnapMode.perpendicular => 'Perpendicular',
    SnapMode.tangent => 'Tangent',
    SnapMode.node => 'Node',
    SnapMode.nearest => 'Nearest',
  };

  SnapMarkerKind get markerKind => switch (this) {
    SnapMode.endpoint => SnapMarkerKind.endpoint,
    SnapMode.midpoint => SnapMarkerKind.midpoint,
    SnapMode.center => SnapMarkerKind.center,
    SnapMode.quadrant => SnapMarkerKind.quadrant,
    SnapMode.intersection => SnapMarkerKind.intersection,
    SnapMode.perpendicular => SnapMarkerKind.perpendicular,
    SnapMode.tangent => SnapMarkerKind.tangent,
    SnapMode.node => SnapMarkerKind.node,
    SnapMode.nearest => SnapMarkerKind.nearest,
  };

  /// The default set: the four a draughtsman uses constantly, without the ones
  /// that fire so often they get in the way.
  static const Set<SnapMode> defaults = {
    SnapMode.endpoint,
    SnapMode.midpoint,
    SnapMode.center,
    SnapMode.intersection,
  };

  static SnapMode? parse(String name) {
    for (final mode in SnapMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}

/// How a cursor position was resolved into a precise drawing point.
enum SnapOrigin {
  /// Straight from the cursor, unmodified.
  free,

  /// Locked onto geometry by an object snap.
  osnap,

  /// Constrained to an orthogonal or polar direction from the base point.
  tracking,

  /// Both: the polar direction crossed a snapped point.
  trackingAndOsnap,
}

/// The outcome of resolving one cursor position.
@immutable
class SnapResult {
  const SnapResult({
    required this.point,
    required this.origin,
    this.marker,
    this.trackingAngle,
    this.trackingLabel = '',
  });

  const SnapResult.free(this.point)
    : origin = SnapOrigin.free,
      marker = null,
      trackingAngle = null,
      trackingLabel = '';

  /// The point a command should actually use.
  final Vec2 point;
  final SnapOrigin origin;

  /// Set when an object snap fired, so the overlay can draw its glyph.
  final SnapMarker? marker;

  /// Set when a tracking constraint applied, in radians.
  final double? trackingAngle;

  /// A readout such as `12.50 < 45°`.
  final String trackingLabel;

  bool get isSnapped => marker != null;
}

/// Drafting constraints that apply on top of object snapping.
@immutable
class TrackingSettings {
  const TrackingSettings({
    this.ortho = false,
    this.polar = false,
    this.polarIncrement = math.pi / 4,
    this.additionalAngles = const [],
  });

  /// Constrains to horizontal and vertical only.
  final bool ortho;

  /// Constrains to multiples of [polarIncrement].
  final bool polar;
  final double polarIncrement;

  /// Extra angles to track, in radians, for example a 30 degree isometric axis.
  final List<double> additionalAngles;

  bool get isActive => ortho || polar || additionalAngles.isNotEmpty;

  TrackingSettings copyWith({
    bool? ortho,
    bool? polar,
    double? polarIncrement,
    List<double>? additionalAngles,
  }) => TrackingSettings(
    ortho: ortho ?? this.ortho,
    polar: polar ?? this.polar,
    polarIncrement: polarIncrement ?? this.polarIncrement,
    additionalAngles: additionalAngles ?? this.additionalAngles,
  );

  /// Every angle this configuration snaps to, in `[0, 2*pi)`.
  List<double> candidateAngles() {
    final angles = <double>[];
    if (ortho) {
      angles.addAll([0, math.pi / 2, math.pi, math.pi * 3 / 2]);
    }
    if (polar && polarIncrement > 0) {
      final steps = (math.pi * 2 / polarIncrement).round();
      for (var i = 0; i < steps; i++) {
        angles.add(i * polarIncrement);
      }
    }
    for (final angle in additionalAngles) {
      angles.add(normalizeAngle(angle));
      angles.add(normalizeAngle(angle + math.pi));
    }
    return angles;
  }
}

/// Resolves a raw cursor position into the point a command should use.
///
/// This is the single place where "where the mouse is" becomes "where the user
/// means", and it is what separates a drawing tool from a paint program. All
/// three mechanisms live together because they interact: a polar constraint
/// changes which object snaps are reachable, and an object snap should win over
/// a polar angle when the user is clearly aiming at real geometry.
class SnapEngine {
  SnapEngine({
    this.modes = SnapMode.defaults,
    this.tracking = const TrackingSettings(),
    this.enabled = true,
    this.aperturePixels = 12,
    this.trackingApertureDegrees = 3,
  });

  Set<SnapMode> modes;
  TrackingSettings tracking;

  /// Master switch, toggled by F3 the way every CAD user expects.
  bool enabled;

  /// How close, in pixels, the cursor must be for a snap to fire.
  final double aperturePixels;

  /// The angular window within which a tracking angle engages.
  final double trackingApertureDegrees;

  /// Resolves [cursor] against the drawing.
  ///
  /// [basePoint] is the anchor a rubber band is drawn from; tracking only
  /// applies when there is one, because an angle needs two points to exist.
  /// [excludedIds] keeps a tool from snapping to the very entity it is
  /// currently dragging.
  SnapResult resolve(
    CadDocument document,
    CadViewport viewport,
    Vec2 cursor, {
    Vec2? basePoint,
    Set<int> excludedIds = const {},
  }) {
    if (!viewport.isUsable) return SnapResult.free(cursor);

    // 1. Object snap on the raw cursor position. Real geometry under the
    //    crosshair is the strongest signal of intent, so it is tried first and
    //    wins outright.
    if (enabled && modes.isNotEmpty) {
      final snapped = _findObjectSnap(
        document,
        viewport,
        cursor,
        excludedIds: excludedIds,
      );
      if (snapped != null) {
        final constrained = basePoint == null
            ? null
            : _angleFor(basePoint, snapped.point);
        return SnapResult(
          point: snapped.point,
          origin: constrained == null
              ? SnapOrigin.osnap
              : SnapOrigin.trackingAndOsnap,
          marker: snapped,
          trackingAngle: constrained,
          trackingLabel: basePoint == null
              ? ''
              : _readout(basePoint, snapped.point),
        );
      }
    }

    // 2. No geometry under the cursor: fall back to a tracking constraint.
    if (basePoint != null && tracking.isActive) {
      final projected = _project(basePoint, cursor);
      if (projected != null) {
        return SnapResult(
          point: projected.point,
          origin: SnapOrigin.tracking,
          trackingAngle: projected.angle,
          trackingLabel: _readout(basePoint, projected.point),
        );
      }
    }

    return SnapResult(
      point: cursor,
      origin: SnapOrigin.free,
      trackingLabel: basePoint == null ? '' : _readout(basePoint, cursor),
    );
  }

  /// The nearest snap point within the aperture, or null.
  ///
  /// Candidates are gathered from every entity in the aperture box and then
  /// ranked by mode priority before distance: an endpoint two pixels further
  /// away than a nearest-point still wins, because "nearest" is a fallback that
  /// exists on every curve and would otherwise mask everything else.
  SnapMarker? _findObjectSnap(
    CadDocument document,
    CadViewport viewport,
    Vec2 cursor, {
    Set<int> excludedIds = const {},
  }) {
    final radius = viewport.pixelsToWorld(aperturePixels);
    final aperture = Bounds2(
      cursor.x - radius,
      cursor.y - radius,
      cursor.x + radius,
      cursor.y + radius,
    );
    final tolerance = viewport.tolerance;

    final candidates = <_Candidate>[];
    // Flattened geometry per entity, kept so intersections can be computed
    // between the entities that are actually near the cursor.
    final flattened = <int, PolylineSink>{};

    for (final space in Picker.spacesUnder(
      document,
      aperture,
      tolerance: tolerance,
    )) {
      final toPaper = space.context.transform.isIdentity
          ? null
          : space.context.transform;
      final inverse = toPaper?.inverted();
      final localCursor = inverse == null ? cursor : inverse.transform(cursor);
      final localRadius = inverse == null
          ? radius
          : radius / math.max(space.context.transform.meanScale, 1e-12);

      for (final id in document.indexFor(space.blockName).search(space.query)) {
        if (excludedIds.contains(id)) continue;
        final entity = document.entity(id);
        if (entity == null) continue;
        if (!entity.props.visible) continue;
        if (!document.isLayerVisible(entity.props.layer)) continue;

        if (toPaper == null) {
          _collectAnalytic(entity, cursor, radius, candidates);
        } else {
          final local = <_Candidate>[];
          _collectAnalytic(entity, localCursor, localRadius, local);
          for (final candidate in local) {
            final point = toPaper.transform(candidate.point);
            if (space.paperClip != null &&
                !space.paperClip!
                    .inflated(radius)
                    .containsPoint(point.x, point.y)) {
              continue;
            }
            candidates.add(
              _Candidate(
                mode: candidate.mode,
                point: point,
                distance: point.distanceTo(cursor),
                entityId: candidate.entityId,
                direction: candidate.direction == null
                    ? null
                    : toPaper.transformDirection(candidate.direction!),
              ),
            );
          }
        }

        if (modes.contains(SnapMode.nearest) ||
            modes.contains(SnapMode.perpendicular) ||
            modes.contains(SnapMode.intersection)) {
          final sink = PolylineSink();
          entity.emit(space.context, sink);
          flattened[id] = sink;
          _collectFromFlattened(id, sink, cursor, radius, candidates);
        }
        if (candidates.length > 4096) break;
      }
      if (candidates.length > 4096) break;
    }

    if (modes.contains(SnapMode.intersection) && flattened.length > 1) {
      _collectIntersections(flattened, cursor, radius, candidates);
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byPriority = _priority(a.mode).compareTo(_priority(b.mode));
      if (byPriority != 0) return byPriority;
      return a.distance.compareTo(b.distance);
    });
    final best = candidates.first;
    return SnapMarker(
      kind: best.mode.markerKind,
      point: best.point,
      entityId: best.entityId,
      direction: best.direction,
    );
  }

  /// Snap points that come from an entity's analytic definition rather than
  /// from its tessellation, which is what makes a circle centre exact.
  void _collectAnalytic(
    CadEntity entity,
    Vec2 cursor,
    double radius,
    List<_Candidate> out,
  ) {
    void offer(SnapMode mode, Vec2 point, {Vec2? direction}) {
      if (!modes.contains(mode)) return;
      final distance = point.distanceTo(cursor);
      if (distance > radius) return;
      out.add(
        _Candidate(
          mode: mode,
          point: point,
          distance: distance,
          entityId: entity.id,
          direction: direction,
        ),
      );
    }

    switch (entity) {
      case LineEntity(:final start, :final end, :final midpoint):
        offer(SnapMode.endpoint, start);
        offer(SnapMode.endpoint, end);
        offer(SnapMode.midpoint, midpoint);
        _offerPerpendicular(entity.id, start, end, cursor, radius, out);
      case PolylineEntity():
        final count = entity.vertexCount;
        for (var i = 0; i < count; i++) {
          offer(SnapMode.endpoint, entity.vertexAt(i));
        }
        final segments = entity.closed ? count : count - 1;
        for (var i = 0; i < segments; i++) {
          final a = entity.vertexAt(i);
          final b = entity.vertexAt((i + 1) % count);
          // A bulged segment is an arc, so its chord midpoint is not on it.
          if (entity.bulgeAt(i) == 0) {
            offer(SnapMode.midpoint, a.lerp(b, 0.5));
            _offerPerpendicular(entity.id, a, b, cursor, radius, out);
          }
        }
      case CircleEntity(:final center, :final radius):
        offer(SnapMode.center, center);
        for (final angle in _quadrants) {
          offer(SnapMode.quadrant, center + Vec2.polar(angle, radius));
        }
        _offerCircleSnaps(entity.id, center, radius, cursor, out);
      case ArcEntity(
        :final center,
        :final radius,
        :final startPoint,
        :final endPoint,
        :final midPoint,
      ):
        offer(SnapMode.center, center);
        offer(SnapMode.endpoint, startPoint);
        offer(SnapMode.endpoint, endPoint);
        offer(SnapMode.midpoint, midPoint);
        final sweep = entity.sweep;
        for (final angle in _quadrants) {
          if (angularSweep(entity.startAngle, angle) <= sweep) {
            offer(SnapMode.quadrant, center + Vec2.polar(angle, radius));
          }
        }
        _offerCircleSnaps(entity.id, center, radius, cursor, out);
      case EllipseEntity(:final center):
        offer(SnapMode.center, center);
        offer(SnapMode.quadrant, center + entity.majorAxis);
        offer(SnapMode.quadrant, center - entity.majorAxis);
        offer(
          SnapMode.quadrant,
          center + entity.majorAxis.perpendicular * entity.ratio,
        );
        offer(
          SnapMode.quadrant,
          center - entity.majorAxis.perpendicular * entity.ratio,
        );
      case PointEntity(:final position):
        offer(SnapMode.node, position);
      case SplineEntity():
        final count = entity.controlPointCount;
        if (count > 0) {
          offer(
            SnapMode.endpoint,
            Vec2(entity.controlPoints[0], entity.controlPoints[1]),
          );
          offer(
            SnapMode.endpoint,
            Vec2(
              entity.controlPoints[(count - 1) * 2],
              entity.controlPoints[(count - 1) * 2 + 1],
            ),
          );
        }
      case InsertEntity(:final position):
        offer(SnapMode.node, position);
      case TextEntity(:final position):
      case MTextEntity(:final position):
        offer(SnapMode.node, position);
      case SolidEntity(:final corners):
        for (final corner in corners) {
          offer(SnapMode.endpoint, corner);
        }
      case HatchEntity(:final loops):
        for (final loop in loops) {
          for (var i = 0; i < loop.pointCount; i++) {
            offer(
              SnapMode.endpoint,
              Vec2(loop.vertices[i * 2], loop.vertices[i * 2 + 1]),
            );
          }
        }
      case DimensionEntity() ||
          LeaderEntity() ||
          RayEntity() ||
          XLineEntity() ||
          ImageEntity() ||
          UnknownEntity():
        // These have no distinguished points a draughtsman aims at; the
        // nearest-point snap collected from the tessellation covers them.
        break;
    }
  }

  void _offerPerpendicular(
    int entityId,
    Vec2 a,
    Vec2 b,
    Vec2 cursor,
    double radius,
    List<_Candidate> out,
  ) {
    if (!modes.contains(SnapMode.perpendicular)) return;
    final foot = Intersect.closestPointOnSegment(cursor, a, b);
    final distance = foot.distanceTo(cursor);
    if (distance > radius) return;
    out.add(
      _Candidate(
        mode: SnapMode.perpendicular,
        point: foot,
        distance: distance,
        entityId: entityId,
        direction: (b - a).normalized(),
      ),
    );
  }

  /// Perpendicular and tangent points on a circle or arc, which are the two
  /// snaps that need the analytic form rather than the tessellation.
  void _offerCircleSnaps(
    int entityId,
    Vec2 center,
    double radius,
    Vec2 cursor,
    List<_Candidate> out,
  ) {
    final toCursor = cursor - center;
    final distance = toCursor.length;
    if (distance < 1e-12) return;

    if (modes.contains(SnapMode.perpendicular)) {
      final foot = center + toCursor * (radius / distance);
      out.add(
        _Candidate(
          mode: SnapMode.perpendicular,
          point: foot,
          distance: foot.distanceTo(cursor),
          entityId: entityId,
          direction: toCursor.perpendicular.normalized(),
        ),
      );
    }
    if (modes.contains(SnapMode.tangent) && distance > radius) {
      // The tangent points from an external point lie where the circle meets
      // the circle of diameter [center, cursor].
      final offset = math.acos((radius / distance).clamp(-1.0, 1.0));
      final base = toCursor.angle;
      for (final sign in const [1.0, -1.0]) {
        final point = center + Vec2.polar(base + offset * sign, radius);
        out.add(
          _Candidate(
            mode: SnapMode.tangent,
            point: point,
            distance: point.distanceTo(cursor),
            entityId: entityId,
          ),
        );
      }
    }
  }

  void _collectFromFlattened(
    int entityId,
    PolylineSink sink,
    Vec2 cursor,
    double radius,
    List<_Candidate> out,
  ) {
    if (!modes.contains(SnapMode.nearest)) return;
    for (var i = 0; i < sink.polylines.length; i++) {
      final hit = Intersect.closestPointOnPolyline(
        cursor,
        sink.polylines[i],
        closed: sink.closedFlags[i],
      );
      if (hit == null || hit.distance > radius) continue;
      out.add(
        _Candidate(
          mode: SnapMode.nearest,
          point: hit.point,
          distance: hit.distance,
          entityId: entityId,
        ),
      );
    }
  }

  /// Intersections between the tessellated geometry of nearby entities.
  ///
  /// Working on the tessellation rather than analytically is a deliberate
  /// trade: it is one implementation that handles every pair of entity types,
  /// and at the aperture size involved the segments are shorter than a pixel,
  /// so the result is exact to well below what the user can see.
  void _collectIntersections(
    Map<int, PolylineSink> flattened,
    Vec2 cursor,
    double radius,
    List<_Candidate> out,
  ) {
    final ids = flattened.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = flattened[ids[i]]!;
        final b = flattened[ids[j]]!;
        for (var ai = 0; ai < a.polylines.length; ai++) {
          for (var bi = 0; bi < b.polylines.length; bi++) {
            _intersectPolylines(
              a.polylines[ai],
              a.closedFlags[ai],
              b.polylines[bi],
              b.closedFlags[bi],
              cursor,
              radius,
              ids[i],
              out,
            );
          }
        }
      }
    }
  }

  static void _intersectPolylines(
    Float64List first,
    bool firstClosed,
    Float64List second,
    bool secondClosed,
    Vec2 cursor,
    double radius,
    int entityId,
    List<_Candidate> out,
  ) {
    final countA = first.length ~/ 2;
    final countB = second.length ~/ 2;
    if (countA < 2 || countB < 2) return;
    final segmentsA = firstClosed ? countA : countA - 1;
    final segmentsB = secondClosed ? countB : countB - 1;
    for (var i = 0; i < segmentsA; i++) {
      final ai = (i + 1) % countA;
      final a0 = Vec2(first[i * 2], first[i * 2 + 1]);
      final a1 = Vec2(first[ai * 2], first[ai * 2 + 1]);
      // Cheap reject: a segment entirely outside the aperture cannot produce
      // an intersection the user is aiming at.
      if (Intersect.distanceToSegment(cursor, a0, a1) > radius) continue;
      for (var j = 0; j < segmentsB; j++) {
        final bj = (j + 1) % countB;
        final b0 = Vec2(second[j * 2], second[j * 2 + 1]);
        final b1 = Vec2(second[bj * 2], second[bj * 2 + 1]);
        final hit = Intersect.segmentSegment(a0, a1, b0, b1);
        if (hit == null) continue;
        final distance = hit.distanceTo(cursor);
        if (distance > radius) continue;
        out.add(
          _Candidate(
            mode: SnapMode.intersection,
            point: hit,
            distance: distance,
            entityId: entityId,
          ),
        );
      }
    }
  }

  /// Projects [cursor] onto the nearest tracking angle from [basePoint].
  _Projection? _project(Vec2 basePoint, Vec2 cursor) {
    final angles = tracking.candidateAngles();
    if (angles.isEmpty) return null;
    final delta = cursor - basePoint;
    final length = delta.length;
    if (length < 1e-12) return null;
    final cursorAngle = normalizeAngle(delta.angle);
    final window = trackingApertureDegrees * math.pi / 180;

    var bestAngle = angles.first;
    var bestGap = double.infinity;
    for (final angle in angles) {
      final gap = _angularDistance(cursorAngle, angle);
      if (gap < bestGap) {
        bestGap = gap;
        bestAngle = angle;
      }
    }
    // Ortho is a hard constraint rather than a magnet: with ortho on, the
    // cursor is always projected, which is what makes it usable for drawing
    // long runs of orthogonal lines.
    if (!tracking.ortho && bestGap > window) return null;
    // Project along the axis so the pointer's distance from the base is
    // preserved in the tracked direction, not scaled by the angle.
    final projected = length * math.cos(bestGap);
    if (projected <= 0) return null;
    return _Projection(
      point: basePoint + Vec2.polar(bestAngle, projected),
      angle: bestAngle,
    );
  }

  double? _angleFor(Vec2 basePoint, Vec2 point) {
    if (!tracking.isActive) return null;
    final delta = point - basePoint;
    if (delta.length < 1e-12) return null;
    final angle = normalizeAngle(delta.angle);
    for (final candidate in tracking.candidateAngles()) {
      if (_angularDistance(angle, candidate) < 1e-6) return candidate;
    }
    return null;
  }

  static String _readout(Vec2 from, Vec2 to) {
    final delta = to - from;
    final length = delta.length;
    if (length < 1e-9) return '';
    final degrees = normalizeAngle(delta.angle) * 180 / math.pi;
    return '${length.toStringAsFixed(2)} < ${degrees.toStringAsFixed(1)}\u00B0';
  }

  static double _angularDistance(double a, double b) {
    final diff = (normalizeAngle(a) - normalizeAngle(b)).abs();
    return math.min(diff, math.pi * 2 - diff);
  }

  static const List<double> _quadrants = [
    0,
    math.pi / 2,
    math.pi,
    math.pi * 3 / 2,
  ];

  /// Lower sorts first. Distinguished points beat computed ones, and
  /// nearest-point comes last because it always exists.
  static int _priority(SnapMode mode) => switch (mode) {
    SnapMode.endpoint => 0,
    SnapMode.intersection => 1,
    SnapMode.midpoint => 2,
    SnapMode.center => 3,
    SnapMode.node => 4,
    SnapMode.quadrant => 5,
    SnapMode.tangent => 6,
    SnapMode.perpendicular => 7,
    SnapMode.nearest => 8,
  };
}

class _Candidate {
  const _Candidate({
    required this.mode,
    required this.point,
    required this.distance,
    required this.entityId,
    this.direction,
  });

  final SnapMode mode;
  final Vec2 point;
  final double distance;
  final int entityId;
  final Vec2? direction;
}

class _Projection {
  const _Projection({required this.point, required this.angle});

  final Vec2 point;
  final double angle;
}
