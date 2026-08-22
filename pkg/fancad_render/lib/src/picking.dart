import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'viewport.dart';

/// One entity found under the cursor.
class PickHit {
  const PickHit({
    required this.entityId,
    required this.distance,
    required this.point,
  });

  final int entityId;

  /// Distance from the pick point to the entity, in screen pixels.
  final double distance;

  /// The closest point on the entity, in drawing coordinates.
  final Vec2 point;
}

/// Finds entities under a point or inside a window.
///
/// Picking runs against flattened geometry rather than against the analytic
/// definition of each entity. That costs a tessellation, but it means a new
/// entity type becomes pickable the moment it can be drawn, with no separate
/// hit-test implementation to keep consistent — and inconsistency between what
/// is drawn and what is selectable is the kind of bug users never forgive.
class Picker {
  const Picker({this.pickRadiusPixels = 6});

  /// The aperture, in pixels. Six is roughly what AutoCAD uses and what a
  /// mouse can be aimed at reliably.
  final double pickRadiusPixels;

  /// The entity nearest [world], or null when nothing is within the aperture.
  PickHit? pickTopmost(
    CadDocument document,
    CadViewport viewport,
    Vec2 world, {
    bool Function(CadEntity entity)? filter,
  }) {
    final hits = pick(document, viewport, world, filter: filter);
    return hits.isEmpty ? null : hits.first;
  }

  /// Every entity within the aperture of [world], nearest first.
  ///
  /// Returning all of them is what allows cycling through overlapping geometry,
  /// which is essential in a dense drawing.
  List<PickHit> pick(
    CadDocument document,
    CadViewport viewport,
    Vec2 world, {
    bool Function(CadEntity entity)? filter,
  }) {
    final radius = viewport.pixelsToWorld(pickRadiusPixels);
    final aperture = Bounds2(
      world.x - radius,
      world.y - radius,
      world.x + radius,
      world.y + radius,
    );
    final tolerance = viewport.tolerance;
    final hits = <PickHit>[];

    for (final space in spacesUnder(document, aperture, tolerance: tolerance)) {
      for (final id in document.indexFor(space.blockName).search(space.query)) {
        final entity = document.entity(id);
        if (entity == null) continue;
        if (!_isSelectable(document, entity)) continue;
        if (filter != null && !filter(entity)) continue;

        final sink = PolylineSink();
        entity.emit(space.context, sink);
        final closest = _closestOn(sink, world, radius);
        if (closest == null) continue;
        if (space.paperClip != null &&
            !space.paperClip!
                .inflated(radius)
                .containsPoint(closest.point.x, closest.point.y)) {
          continue;
        }
        hits.add(
          PickHit(
            entityId: id,
            distance: closest.distance * viewport.scale,
            point: closest.point,
          ),
        );
      }
    }

    // Nearest first; ties broken by draw order so the entity drawn last, and
    // therefore visually on top, wins.
    hits.sort((a, b) {
      final byDistance = a.distance.compareTo(b.distance);
      if (byDistance != 0) return byDistance;
      final orderA = document.entityIndexOf(a.entityId) ?? 0;
      final orderB = document.entityIndexOf(b.entityId) ?? 0;
      return orderB.compareTo(orderA);
    });
    return hits;
  }

  /// Entities inside or crossing a selection window.
  ///
  /// [crossing] is the AutoCAD distinction: a crossing window selects anything
  /// it touches, an enclosing window only what is wholly inside.
  List<int> pickWindow(
    CadDocument document,
    CadViewport viewport,
    Bounds2 window, {
    required bool crossing,
    bool Function(CadEntity entity)? filter,
  }) {
    final result = <int>[];
    final seen = <int>{};
    final tolerance = viewport.tolerance;

    for (final space in spacesUnder(document, window, tolerance: tolerance)) {
      for (final id in document.indexFor(space.blockName).search(space.query)) {
        if (!seen.add(id)) continue;
        final entity = document.entity(id);
        if (entity == null) continue;
        if (!_isSelectable(document, entity)) continue;
        if (filter != null && !filter(entity)) continue;

        final bounds = document.boundsOfEntity(entity);
        if (bounds.isEmpty) continue;
        final paperBounds = space.context.transform.isIdentity
            ? bounds
            : bounds.transformed(space.context.transform);
        if (!crossing) {
          // Enclosing selection can be decided from the bounding box alone.
          if (window.containsBox(paperBounds)) result.add(id);
          continue;
        }
        if (!window.intersects(paperBounds)) continue;
        // A bounding box overlap is not a real crossing: the window may sit in
        // the empty middle of a large circle. Check the geometry.
        final sink = PolylineSink();
        entity.emit(space.context, sink);
        if (_crosses(sink, window)) result.add(id);
      }
    }
    return result;
  }

  /// Paper-space entities, plus model-space entities seen through a viewport.
  static Iterable<LayoutSpace> spacesUnder(
    CadDocument document,
    Bounds2 paperBox, {
    required double tolerance,
  }) sync* {
    yield LayoutSpace(
      blockName: document.currentBlockName,
      query: paperBox,
      context: document.emitContext(tolerance: tolerance, clip: paperBox),
    );
    final layout = document.activeLayout;
    if (layout.isModelSpace) return;
    for (final viewport in layout.viewports) {
      if (!viewport.isOn) continue;
      if (!viewport.paperBounds.intersects(paperBox)) continue;
      final inverse = viewport.paperToModel();
      if (inverse == null) continue;
      final scale = viewport.scale.abs();
      yield LayoutSpace(
        blockName: document.modelSpaceBlockName,
        query: paperBox.transformed(inverse),
        context: document.emitContext(
          tolerance: scale < 1e-12 ? tolerance : tolerance / scale,
          clip: viewport.modelWindow,
          transform: viewport.modelToPaper(),
        ),
        paperClip: viewport.paperBounds,
      );
    }
  }

  static bool _isSelectable(CadDocument document, CadEntity entity) =>
      entity.props.visible &&
      document.isLayerVisible(entity.props.layer) &&
      document.isLayerEditable(entity.props.layer);

  /// The closest point on the flattened geometry, or null when out of range.
  PolylineHit? _closestOn(PolylineSink sink, Vec2 target, double radius) {
    // A filled region is picked anywhere inside it, not only on its edge.
    for (final fill in sink.fills) {
      if (Intersect.polygonContains(fill, target)) {
        return PolylineHit(target, 0, 0);
      }
    }
    for (final text in sink.texts) {
      if (text.estimatedBounds().containsPoint(target.x, target.y)) {
        return PolylineHit(target, 0, 0);
      }
    }

    var best = radius;
    PolylineHit? bestHit;
    for (var i = 0; i < sink.polylines.length; i++) {
      final result = Intersect.closestPointOnPolyline(
        target,
        sink.polylines[i],
        closed: sink.closedFlags[i],
      );
      if (result != null && result.distance < best) {
        best = result.distance;
        bestHit = result;
      }
    }
    for (final point in sink.points) {
      final distance = point.distanceTo(target);
      if (distance < best) {
        best = distance;
        bestHit = PolylineHit(point, 0, distance);
      }
    }
    return bestHit;
  }

  static bool _crosses(PolylineSink sink, Bounds2 window) {
    for (var i = 0; i < sink.polylines.length; i++) {
      if (Intersect.polylineCrossesRect(
        sink.polylines[i],
        window.minX,
        window.minY,
        window.maxX,
        window.maxY,
        closed: sink.closedFlags[i],
      )) {
        return true;
      }
    }
    for (final point in sink.points) {
      if (window.containsPoint(point.x, point.y)) return true;
    }
    for (final fill in sink.fills) {
      if (Intersect.polygonContains(fill, window.center)) return true;
    }
    for (final text in sink.texts) {
      if (text.estimatedBounds().intersects(window)) return true;
    }
    return false;
  }

  /// The grip of [entity] nearest [world], or -1.
  int pickGrip(
    CadEntity entity,
    CadViewport viewport,
    Vec2 world, {
    double radiusPixels = 8,
  }) {
    final radius = viewport.pixelsToWorld(radiusPixels);
    final grips = entity.grips();
    var best = radius;
    var bestIndex = -1;
    for (var i = 0; i < grips.length; i++) {
      final distance = grips[i].distanceTo(world);
      if (distance < best) {
        best = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /// The grip nearest [world] across several entities.
  ///
  /// Returns the entity id and the grip index, which together are what an edit
  /// needs in order to move it.
  (int entityId, int gripIndex)? pickGripAmong(
    CadDocument document,
    Iterable<int> entityIds,
    CadViewport viewport,
    Vec2 world, {
    double radiusPixels = 8,
  }) {
    final radius = viewport.pixelsToWorld(radiusPixels);
    var best = radius;
    (int, int)? result;
    for (final id in entityIds) {
      final entity = document.entity(id);
      if (entity == null) continue;
      final grips = entity.grips();
      for (var i = 0; i < grips.length; i++) {
        final distance = grips[i].distanceTo(world);
        if (distance < best) {
          best = distance;
          result = (id, i);
        }
      }
    }
    return result;
  }

  /// Flattened geometry of [entityId], for snapping and measurement.
  static PolylineSink flatten(
    CadDocument document,
    int entityId, {
    required double tolerance,
    Bounds2? clip,
  }) {
    final sink = PolylineSink();
    final entity = document.entity(entityId);
    if (entity == null) return sink;
    entity.emit(
      document.emitContext(tolerance: tolerance, clip: clip),
      sink,
    );
    return sink;
  }

  /// The total length of the flattened geometry of an entity, for the status
  /// bar and for the AI's measurement tool.
  static double lengthOf(PolylineSink sink) {
    var total = 0.0;
    for (var i = 0; i < sink.polylines.length; i++) {
      total += _polylineLength(
        sink.polylines[i],
        closed: sink.closedFlags[i],
      );
    }
    return total;
  }

  static double _polylineLength(Float64List xy, {required bool closed}) {
    var total = 0.0;
    final count = xy.length ~/ 2;
    for (var i = 0; i + 1 < count; i++) {
      total += Vec2(
        xy[i * 2],
        xy[i * 2 + 1],
      ).distanceTo(Vec2(xy[(i + 1) * 2], xy[(i + 1) * 2 + 1]));
    }
    if (closed && count > 2) {
      total += Vec2(
        xy[(count - 1) * 2],
        xy[(count - 1) * 2 + 1],
      ).distanceTo(Vec2(xy[0], xy[1]));
    }
    return total;
  }
}

/// One space that can contribute geometry under a paper-space query.
///
/// Model space is just the active block. A paper layout also yields a query
/// per viewport, with a transform that puts model entities onto the sheet.
class LayoutSpace {
  const LayoutSpace({
    required this.blockName,
    required this.query,
    required this.context,
    this.paperClip,
  });

  final String blockName;
  final Bounds2 query;
  final EmitContext context;

  /// When set, a hit must land inside this paper rectangle.
  final Bounds2? paperClip;
}
