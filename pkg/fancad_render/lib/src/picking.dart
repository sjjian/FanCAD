import 'dart:math' as math;
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

/// A grip as it appears on the current layout.
class GripHit {
  const GripHit({
    required this.entityId,
    required this.gripIndex,
    required this.paperPoint,
    this.viewport,
    this.viewportIndex,
  });

  final int entityId;
  final int gripIndex;

  /// Grip location in the coordinates of the current layout.
  final Vec2 paperPoint;

  /// Set when this is a model-space grip seen through a paper window.
  final PaperViewport? viewport;

  /// Set when this grip belongs to a paper viewport frame.
  final int? viewportIndex;

  bool get isViewportFrame => viewportIndex != null;
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

  /// Re-emits [ids] in the coordinates of the current layout tab.
  ///
  /// Model-space entities are replayed through every on paper viewport, so a
  /// selection outline lands on the sheet instead of at the untransformed
  /// model point.
  static void emitInActiveLayout(
    CadDocument document,
    Iterable<int> ids,
    GeometrySink sink, {
    required double tolerance,
    Bounds2? visible,
  }) {
    final layout = document.activeLayout;
    for (final id in ids) {
      final entity = document.entity(id);
      if (entity == null || !entity.props.visible) continue;
      if (!document.isLayerVisible(entity.props.layer)) continue;
      final owner = document.ownerOf(id) ?? document.modelSpaceBlockName;
      final onSheet = layout.isModelSpace || owner == layout.blockName;
      if (onSheet) {
        entity.emit(
          document.emitContext(tolerance: tolerance, clip: visible),
          sink,
        );
        continue;
      }
      if (owner != document.modelSpaceBlockName) continue;
      for (final viewport in layout.viewports) {
        if (!viewport.isOn) continue;
        if (visible != null && !viewport.paperBounds.intersects(visible)) {
          continue;
        }
        final scale = viewport.scale.abs();
        entity.emit(
          document.emitContext(
            tolerance: scale < 1e-12 ? tolerance : tolerance / scale,
            clip: viewport.modelWindow,
            transform: viewport.modelToPaper(),
          ),
          sink,
        );
      }
    }
  }

  /// The paper viewport whose frame is under [world], or null.
  ///
  /// The interior is left to model-space picking so a click inside the
  /// window still selects a line. Only the border is a viewport hit.
  int? pickViewportFrame(
    CadDocument document,
    CadViewport viewport,
    Vec2 world, {
    double radiusPixels = 6,
  }) {
    final layout = document.activeLayout;
    if (layout.isModelSpace) return null;
    final radius = viewport.pixelsToWorld(radiusPixels);
    var best = radius;
    int? found;
    for (var i = 0; i < layout.viewports.length; i++) {
      final window = layout.viewports[i];
      if (!window.isOn) continue;
      final distance = _distanceToRectEdge(world, window.paperBounds);
      if (distance <= best) {
        best = distance;
        found = i;
      }
    }
    return found;
  }

  /// Frame grips of selected paper viewports.
  List<GripHit> displayViewportGrips(
    CadDocument document,
    Iterable<int> viewportIndices,
  ) {
    final layout = document.activeLayout;
    if (layout.isModelSpace) return const [];
    final result = <GripHit>[];
    for (final index in viewportIndices) {
      if (index < 0 || index >= layout.viewports.length) continue;
      final window = layout.viewports[index];
      if (!window.isOn) continue;
      final local = window.grips();
      for (var i = 0; i < local.length; i++) {
        result.add(
          GripHit(
            entityId: -1,
            gripIndex: i,
            paperPoint: local[i],
            viewportIndex: index,
          ),
        );
      }
    }
    return result;
  }

  static double _distanceToRectEdge(Vec2 point, Bounds2 box) {
    final clampedX = point.x.clamp(box.minX, box.maxX);
    final clampedY = point.y.clamp(box.minY, box.maxY);
    final dx = point.x - clampedX;
    final dy = point.y - clampedY;
    if (dx != 0 || dy != 0) {
      return math.sqrt(dx * dx + dy * dy);
    }
    return math.min(
      math.min(point.x - box.minX, box.maxX - point.x),
      math.min(point.y - box.minY, box.maxY - point.y),
    );
  }

  /// Grips of [entityIds] in the coordinates of the current layout.
  ///
  /// Model-space grips are mapped through every on paper viewport that
  /// actually shows them, so a stretch on a layout tab aims at the square
  /// the user can see rather than at the untransformed model point.
  List<GripHit> displayGrips(
    CadDocument document,
    Iterable<int> entityIds,
  ) {
    final result = <GripHit>[];
    final layout = document.activeLayout;
    for (final id in entityIds) {
      final entity = document.entity(id);
      if (entity == null) continue;
      final owner = document.ownerOf(id);
      final local = entity.grips();
      if (local.isEmpty) continue;

      final onActiveSheet =
          layout.isModelSpace || owner == layout.blockName;
      if (onActiveSheet) {
        for (var i = 0; i < local.length; i++) {
          result.add(
            GripHit(
              entityId: id,
              gripIndex: i,
              paperPoint: local[i],
            ),
          );
        }
        continue;
      }
      if (owner != document.modelSpaceBlockName) continue;

      for (final viewport in layout.viewports) {
        if (!viewport.isOn) continue;
        final toPaper = viewport.modelToPaper();
        for (var i = 0; i < local.length; i++) {
          final paper = toPaper.transform(local[i]);
          if (!viewport.paperBounds.containsPoint(paper.x, paper.y)) {
            continue;
          }
          result.add(
            GripHit(
              entityId: id,
              gripIndex: i,
              paperPoint: paper,
              viewport: viewport,
            ),
          );
        }
      }
    }
    return result;
  }

  /// The grip of [entity] nearest [world], or -1.
  int pickGrip(
    CadDocument document,
    CadEntity entity,
    CadViewport viewport,
    Vec2 world, {
    double radiusPixels = 8,
  }) =>
      pickGripAmong(
        document,
        [entity.id],
        viewport,
        world,
        radiusPixels: radiusPixels,
      )?.gripIndex ??
      -1;

  /// The grip nearest [world] across several entities.
  GripHit? pickGripAmong(
    CadDocument document,
    Iterable<int> entityIds,
    CadViewport viewport,
    Vec2 world, {
    double radiusPixels = 8,
    Iterable<int> viewportIndices = const [],
  }) {
    final radius = viewport.pixelsToWorld(radiusPixels);
    var best = radius;
    GripHit? result;
    for (final grip in [
      ...displayGrips(document, entityIds),
      ...displayViewportGrips(document, viewportIndices),
    ]) {
      final distance = grip.paperPoint.distanceTo(world);
      if (distance < best) {
        best = distance;
        result = grip;
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
