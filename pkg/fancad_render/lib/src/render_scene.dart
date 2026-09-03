import 'dart:ui' show Offset;

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

import 'batch.dart';
import 'viewport.dart';

/// Where a recorded scene has to be placed to stand in for another camera.
@immutable
class ScenePlacement {
  const ScenePlacement({required this.scale, required this.offset});

  /// The zoom factor between the camera the scene was built for and the one
  /// being painted. Exactly 1 for a pan.
  final double scale;

  /// Displacement in physical pixels. A whole number of pixels when [scale] is
  /// 1, because every camera is [CadViewport.pixelLocked].
  final Offset offset;

  bool get isTranslation => scale == 1;

  @override
  String toString() => 'ScenePlacement(scale: $scale, offset: $offset)';
}

/// One drawing-order bucket.
///
/// Within a bucket the primitive order is fixed — raster underlays, then
/// fills, then linework, then markers, then text — and buckets are painted in
/// ascending [order]. The unit is a bucket rather than an entity on purpose: a
/// pass per entity would put a draw call back on every single line and undo
/// the point of batching.
///
/// Every entity lands in bucket 0 today, so a scene has one pass and paints in
/// the same fixed order as before. Wiring `$SORTENTS` means handing out bucket
/// numbers; nothing downstream has to change.
@immutable
class RenderPass {
  const RenderPass({
    required this.order,
    this.images = const [],
    this.fillBatches = const [],
    this.lineBatches = const [],
    this.pointBatches = const [],
    this.texts = const [],
  });

  final int order;
  final List<ImageItem> images;
  final List<FillBatch> fillBatches;
  final List<LineBatch> lineBatches;
  final List<PointBatch> pointBatches;
  final List<TextItem> texts;

  int get drawCallCount =>
      images.length +
      fillBatches.length +
      lineBatches.length +
      pointBatches.length +
      texts.length;
}

/// A frame's worth of geometry, reduced to a handful of draw calls.
class RenderScene {
  RenderScene({
    required this.viewport,
    required this.passes,
    required this.entityCount,
    required this.segmentCount,
    required this.culledCount,
    required this.buildTime,
    required this.coverage,
  });

  /// A scene with a single drawing-order bucket, which is what a document
  /// without an explicit draw order produces.
  RenderScene.single({
    required this.viewport,
    List<LineBatch> lineBatches = const [],
    List<PointBatch> pointBatches = const [],
    List<FillBatch> fillBatches = const [],
    List<TextItem> texts = const [],
    List<ImageItem> images = const [],
    this.entityCount = 0,
    this.segmentCount = 0,
    this.culledCount = 0,
    this.buildTime = Duration.zero,
    this.coverage = const Bounds2.empty(),
  }) : passes = [
         RenderPass(
           order: 0,
           images: images,
           fillBatches: fillBatches,
           lineBatches: lineBatches,
           pointBatches: pointBatches,
           texts: texts,
         ),
       ];

  RenderScene.empty(this.viewport)
    : passes = const [],
      entityCount = 0,
      segmentCount = 0,
      culledCount = 0,
      buildTime = Duration.zero,
      coverage = const Bounds2.empty();

  final CadViewport viewport;

  /// The drawing region this scene contains geometry for, which is larger than
  /// the visible area. A pan that stays inside it can reuse the scene by
  /// translating it, which is what keeps panning a large drawing smooth.
  final Bounds2 coverage;

  /// Drawing-order buckets, already sorted.
  final List<RenderPass> passes;

  /// Flat views across every pass, for statistics, hit-test debugging and
  /// tests. The painter walks [passes] instead so the order is preserved.
  List<LineBatch> get lineBatches => [
    for (final pass in passes) ...pass.lineBatches,
  ];
  List<PointBatch> get pointBatches => [
    for (final pass in passes) ...pass.pointBatches,
  ];
  List<FillBatch> get fillBatches => [
    for (final pass in passes) ...pass.fillBatches,
  ];
  List<TextItem> get texts => [for (final pass in passes) ...pass.texts];
  List<ImageItem> get images => [for (final pass in passes) ...pass.images];

  /// Entities that contributed geometry.
  final int entityCount;

  /// Line segments in the scene: the honest measure of frame cost.
  final int segmentCount;

  /// Entities the spatial index returned but that were dropped as off screen.
  final int culledCount;

  final Duration buildTime;

  /// Whether [other] looks at a region this scene holds geometry for, on the
  /// same widget and display.
  ///
  /// Says nothing about zoom: a zoom in flight can still replay this scene,
  /// which is what [placementFor] is for.
  bool covers(CadViewport other) =>
      coverage.isNotEmpty &&
      other.size == viewport.size &&
      other.devicePixelRatio == viewport.devicePixelRatio &&
      coverage.containsBox(other.visibleBounds);

  /// Whether this scene stands in for [other] exactly, by translating it a
  /// whole number of physical pixels.
  bool canReuseFor(CadViewport other) =>
      other.scale == viewport.scale && covers(other);

  /// How this scene has to be placed to stand in for [other].
  ///
  /// Exact for any camera: both mappings are a scale and a translation of the
  /// same world space, so a world point lands where [other] would have put it.
  /// What goes stale under a zoom is curve tessellation and paper line weight,
  /// not position — which is why replaying a zoom is a level-of-detail trade
  /// and not an approximation of where the drawing is.
  ///
  /// A pan gives [ScenePlacement.scale] 1 and a whole-pixel offset, because
  /// both cameras are [CadViewport.pixelLocked].
  ScenePlacement placementFor(CadViewport other) {
    final from = viewport.pixels;
    final to = other.pixels;
    final factor = from.scale == 0 ? 1.0 : to.scale / from.scale;
    return ScenePlacement(
      scale: factor,
      offset: Offset(
        to.originX - from.originX * factor,
        to.originY - from.originY * factor,
      ),
    );
  }

  /// Draw calls this scene will issue.
  int get drawCallCount {
    var total = 0;
    for (final pass in passes) {
      total += pass.drawCallCount;
    }
    return total;
  }

  @override
  String toString() =>
      'RenderScene($entityCount entities, $segmentCount segments, '
      '$drawCallCount draw calls, '
      '${(buildTime.inMicroseconds / 1000).toStringAsFixed(1)}ms)';
}

