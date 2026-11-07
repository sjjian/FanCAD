import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

import 'batch.dart';
import 'block_cache.dart';
import 'device_space.dart';
import 'drawing_font.dart';
import 'palette.dart';
import 'picking.dart';
import 'polyline_simplify.dart';
import 'render_scene.dart';
import 'scene_painter.dart';
import 'tessellation_cache.dart';
import 'text_atlas.dart';
import 'text_cache.dart';
import 'viewport.dart';

/// A retained display list in drawing coordinates.
///
/// Unlike [RenderScene], nothing here is projected to the screen. The camera is
/// applied once per frame by [WorldScenePainter], so a pan or a zoom never has
/// to rebuild the geometry and never runs out of coverage on the way out.
class WorldScene {
  WorldScene({
    required this.viewport,
    required this.origin,
    required this.passes,
    required this.entityCount,
    required this.segmentCount,
    required this.buildTime,
    required this.bounds,
    required this.toleranceBucket,
    required this.extentBucket,
    this.previewDetail = WorldSceneBuilder.previewDetail,
  });

  /// Camera the scene was flattened for. Curves and collapse decisions follow
  /// its tolerance; position does not.
  final CadViewport viewport;

  /// Local origin subtracted from every vertex, so Float32 buffers keep their
  /// precision on drawings whose coordinates are in the hundred-thousands.
  final Vec2 origin;

  final List<WorldPass> passes;
  final int entityCount;
  final int segmentCount;
  final Duration buildTime;
  final Bounds2 bounds;
  final int toleranceBucket;
  final int extentBucket;

  /// The [WorldSceneBuilder.previewDetail] the scene was flattened with.
  /// Comparing it keeps a scene retained across a hot reload from masking a
  /// change to the level-of-detail policy.
  final double previewDetail;

  int get drawCallCount {
    var total = 0;
    for (final pass in passes) {
      total += pass.drawCallCount;
    }
    return total;
  }

  List<WorldLineBatch> get lineBatches => [
    for (final pass in passes) ...pass.lineBatches,
  ];
  List<WorldPointBatch> get pointBatches => [
    for (final pass in passes) ...pass.pointBatches,
  ];
  List<WorldFillBatch> get fillBatches => [
    for (final pass in passes) ...pass.fillBatches,
  ];
  List<WorldTextItem> get texts => [for (final pass in passes) ...pass.texts];
  List<WorldImageItem> get images => [
    for (final pass in passes) ...pass.images,
  ];

  Bounds2 get localBounds => Bounds2(
    bounds.minX - origin.x,
    bounds.minY - origin.y,
    bounds.maxX - origin.x,
    bounds.maxY - origin.y,
  );

  /// A stats record for the status bar; no screen batches are attached.
  RenderScene statsFor(CadViewport camera) => RenderScene(
    viewport: camera,
    passes: const [],
    entityCount: entityCount,
    segmentCount: segmentCount,
    culledCount: 0,
    buildTime: buildTime,
    coverage: bounds,
    drawCalls: drawCallCount,
  );
}

/// One drawing-order bucket of a [WorldScene].
class WorldPass {
  const WorldPass({
    required this.order,
    this.images = const [],
    this.fillBatches = const [],
    this.lineBatches = const [],
    this.pointBatches = const [],
    this.texts = const [],
  });

  final int order;
  final List<WorldImageItem> images;
  final List<WorldFillBatch> fillBatches;
  final List<WorldLineBatch> lineBatches;
  final List<WorldPointBatch> pointBatches;
  final List<WorldTextItem> texts;

  int get drawCallCount =>
      images.length +
      fillBatches.length +
      lineBatches.length +
      pointBatches.length +
      texts.length;
}

@immutable
class WorldLineKey {
  const WorldLineKey({
    required this.color,
    required this.lineWeight,
    required this.lineType,
    required this.lineTypeScale,
    required this.order,
    required this.dashed,
  });

  final ui.Color color;
  final int lineWeight;
  final String lineType;
  final double lineTypeScale;
  final int order;
  final bool dashed;

  @override
  bool operator ==(Object other) =>
      other is WorldLineKey &&
      other.color == color &&
      other.lineWeight == lineWeight &&
      other.lineType == lineType &&
      other.lineTypeScale == lineTypeScale &&
      other.order == order &&
      other.dashed == dashed;

  @override
  int get hashCode =>
      Object.hash(color, lineWeight, lineType, lineTypeScale, order, dashed);
}

/// Line segments in local drawing coordinates, sharing one style.
class WorldLineBatch {
  WorldLineBatch(this.key, this.pattern);

  final WorldLineKey key;

  /// Dash lengths in drawing units, already multiplied by the line-type
  /// scales. Null for a solid stroke.
  final List<double>? pattern;

  final Float32Buffer solid = Float32Buffer();
  final Float32Buffer dashed = Float32Buffer();
  Bounds2 bounds = const Bounds2.empty();
  WorldCells? solidCells;
  WorldCells? dashedCells;

  int get segmentCount => solid.length ~/ 4;

  /// Sorts both variants into a world-space grid before the scene is frozen.
  void indexCells() {
    solidCells = _WorldCellBuilder.build(solid, bounds);
    if (dashed.isNotEmpty) {
      dashedCells = _WorldCellBuilder.build(dashed, bounds);
    }
  }

  /// Adds one polyline of local coordinates.
  void add(Float64List local, {required bool closed}) {
    final count = local.length ~/ 2;
    if (count < 2) return;
    bounds = bounds.union(Bounds2.fromXY(local));
    for (var i = 0; i + 1 < count; i++) {
      final o = i * 2;
      solid.add4(local[o], local[o + 1], local[o + 2], local[o + 3]);
    }
    if (closed && count > 2) {
      solid.add4(
        local[count * 2 - 2],
        local[count * 2 - 1],
        local[0],
        local[1],
      );
    }
    final dash = pattern;
    if (dash != null && dash.isNotEmpty) {
      _addDashed(local, count, dash, closed: closed);
    }
  }

  void _addDashed(
    Float64List local,
    int count,
    List<double> dashes, {
    required bool closed,
  }) {
    var dashIndex = 0;
    var remaining = dashes[0];
    var drawing = true;
    var budget = 100000;

    void walk(double x0, double y0, double x1, double y1) {
      var length = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
      if (length <= 0) return;
      final dirX = (x1 - x0) / length;
      final dirY = (y1 - y0) / length;
      var startX = x0;
      var startY = y0;
      while (length > 1e-9 && budget-- > 0) {
        final step = math.min(remaining, length);
        final endX = startX + dirX * step;
        final endY = startY + dirY * step;
        if (drawing) dashed.add4(startX, startY, endX, endY);
        startX = endX;
        startY = endY;
        length -= step;
        remaining -= step;
        if (remaining <= 1e-9) {
          dashIndex = (dashIndex + 1) % dashes.length;
          remaining = dashes[dashIndex];
          drawing = !drawing;
        }
      }
    }

    for (var i = 0; i + 1 < count && budget > 0; i++) {
      final o = i * 2;
      walk(local[o], local[o + 1], local[o + 2], local[o + 3]);
    }
    if (closed && count > 2 && budget > 0) {
      walk(local[count * 2 - 2], local[count * 2 - 1], local[0], local[1]);
    }
    // A pathological pattern on a long line must not turn one segment into
    // millions. The solid buffer is already there as the fallback.
    if (budget < 0) dashed.clear();
  }
}

/// Spatial grid over one retained line batch.
class WorldCells {
  const WorldCells({
    required this.starts,
    required this.bounds,
    required this.wideBounds,
  });

  /// Entry c through c + 1 is cell c; the last entry starts the wide tail.
  final Int32List starts;
  final List<Bounds2> bounds;
  final Bounds2? wideBounds;

  int get cellCount => bounds.length;
}

/// Cuts one vertex buffer into a world-space grid, in place.
class _WorldCellBuilder {
  static const int side = 16;
  static const int cellCount = side * side;
  static const int minimumSegments = 256;

  static WorldCells? build(Float32Buffer buffer, Bounds2 box) {
    final count = buffer.length ~/ 4;
    if (count < minimumSegments) return null;
    if (!(box.width > 0) || !(box.height > 0)) return null;
    final cellWidth = box.width / side;
    final cellHeight = box.height / side;
    final xy = buffer.writable;
    final bucketOf = Int32List(count);
    final counts = Int32List(cellCount + 1);
    int column(double x) =>
        ((x - box.minX) / cellWidth).floor().clamp(0, side - 1);
    int row(double y) =>
        ((y - box.minY) / cellHeight).floor().clamp(0, side - 1);
    for (var s = 0; s < count; s++) {
      final o = s * 4;
      final x0 = xy[o], y0 = xy[o + 1], x1 = xy[o + 2], y1 = xy[o + 3];
      final cx0 = column(math.min(x0, x1));
      final cx1 = column(math.max(x0, x1));
      final cy0 = row(math.min(y0, y1));
      final cy1 = row(math.max(y0, y1));
      final bucket = cx0 == cx1 && cy0 == cy1 ? cy0 * side + cx0 : cellCount;
      bucketOf[s] = bucket;
      counts[bucket]++;
    }

    final starts = Int32List(cellCount + 1);
    var at = 0;
    for (var c = 0; c <= cellCount; c++) {
      starts[c] = at;
      at += counts[c];
    }

    final sorted = Float32List(count * 4);
    final cursor = Int32List.fromList(starts);
    for (var s = 0; s < count; s++) {
      final to = cursor[bucketOf[s]] * 4;
      final from = s * 4;
      sorted[to] = xy[from];
      sorted[to + 1] = xy[from + 1];
      sorted[to + 2] = xy[from + 2];
      sorted[to + 3] = xy[from + 3];
      cursor[bucketOf[s]]++;
    }
    xy.setRange(0, count * 4, sorted);

    final slack = math.max(cellWidth, cellHeight) * 0.05 + 1e-9;
    final bounds = List<Bounds2>.generate(cellCount, (c) {
      final left = box.minX + (c % side) * cellWidth;
      final bottom = box.minY + (c ~/ side) * cellHeight;
      return Bounds2(
        left - slack,
        bottom - slack,
        left + cellWidth + slack,
        bottom + cellHeight + slack,
      );
    });

    final wideStart = starts[cellCount];
    Bounds2? wide;
    if (wideStart < count) {
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      for (var o = wideStart * 4; o + 3 < count * 4; o += 4) {
        for (var k = 0; k < 4; k += 2) {
          final x = xy[o + k], y = xy[o + k + 1];
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
      wide = Bounds2(minX, minY, maxX, maxY);
    }
    return WorldCells(starts: starts, bounds: bounds, wideBounds: wide);
  }
}

@immutable
class WorldPointKey {
  const WorldPointKey({
    required this.color,
    required this.lineWeight,
    required this.order,
  });

  final ui.Color color;
  final int lineWeight;
  final int order;

  @override
  bool operator ==(Object other) =>
      other is WorldPointKey &&
      other.color == color &&
      other.lineWeight == lineWeight &&
      other.order == order;

  @override
  int get hashCode => Object.hash(color, lineWeight, order);
}

class WorldPointBatch {
  WorldPointBatch(this.key);

  final WorldPointKey key;
  final Float32Buffer points = Float32Buffer();
  Bounds2 bounds = const Bounds2.empty();

  void add(double x, double y) {
    points.add2(x, y);
    bounds = bounds.expandToInclude(x, y);
  }
}

@immutable
class WorldFillKey {
  const WorldFillKey({required this.color, required this.order});

  final ui.Color color;
  final int order;

  @override
  bool operator ==(Object other) =>
      other is WorldFillKey && other.color == color && other.order == order;

  @override
  int get hashCode => Object.hash(color, order);
}

class WorldFillBatch {
  WorldFillBatch(this.key);

  final WorldFillKey key;
  final ui.Path path = ui.Path()..fillType = ui.PathFillType.evenOdd;
  Bounds2 bounds = const Bounds2.empty();
  int ringCount = 0;

  bool get isEmpty => ringCount == 0;

  void addRing(Float64List local) {
    final count = local.length ~/ 2;
    if (count < 3) return;
    bounds = bounds.union(Bounds2.fromXY(local));
    path.moveTo(local[0], local[1]);
    for (var i = 1; i < count; i++) {
      path.lineTo(local[i * 2], local[i * 2 + 1]);
    }
    path.close();
    ringCount++;
  }
}

@immutable
class WorldTextItem {
  const WorldTextItem({
    required this.geometry,
    required this.color,
    required this.fontFamily,
    required this.order,
    required this.bounds,
  });

  final TextGeometry geometry;
  final ui.Color color;
  final String fontFamily;
  final int order;
  final Bounds2 bounds;
}

@immutable
class WorldImageItem {
  const WorldImageItem({required this.geometry, required this.order});

  final ImageGeometry geometry;
  final int order;
}

/// Collects world-space primitives and merges them by render state.
class WorldSink implements GeometrySink {
  WorldSink({
    required this.origin,
    required this.reference,
    required this.palette,
    required this.fonts,
    this.lineTypes = const {},
    this.globalLineTypeScale = 1,
    this.simplifyPixels = 0.15,
  }) : pixels = reference.pixels;

  final Vec2 origin;
  final CadViewport reference;
  final double simplifyPixels;
  late final double _simplifyWorld = reference.pixelsToWorld(simplifyPixels);
  final AciPalette palette;
  final DrawingFontMap fonts;
  final Map<String, List<double>> lineTypes;
  final double globalLineTypeScale;
  final PixelSpace pixels;

  Bounds2? worldClip;
  int drawOrder = 0;

  final Map<WorldLineKey, WorldLineBatch> lineBatches = {};
  final Map<WorldPointKey, WorldPointBatch> pointBatches = {};
  final Map<WorldFillKey, WorldFillBatch> fillBatches = {};
  final List<WorldTextItem> texts = [];
  final List<WorldImageItem> images = [];

  int get segmentCount {
    var total = 0;
    for (final batch in lineBatches.values) {
      total += batch.segmentCount;
    }
    return total;
  }

  void replay(List<CachedPrimitive> primitives) =>
      replayCachedPrimitives(this, primitives);

  ui.Color _colorFor(ResolvedStyle style) {
    final color = palette.colorOf(style.color);
    if (style.transparency <= 0) return color;
    return color.withValues(alpha: 1 - style.transparency / 100);
  }

  List<double>? _patternFor(ResolvedStyle style) {
    final raw = lineTypes[style.lineType];
    if (raw == null || raw.isEmpty) return null;
    final scale = style.lineTypeScale * globalLineTypeScale;
    if (scale <= 0 || !scale.isFinite) return null;
    final pattern = [for (final segment in raw) segment * scale];
    var total = 0.0;
    for (final segment in pattern) {
      total += segment;
    }
    if (total <= 0) return null;
    // Match the interactive painter: a pattern below a few pixels reads as a
    // solid line, and a pattern longer than the screen means the viewer is
    // inside one dash. Both are stored as solid; a settled build at another
    // scale can bring the dashes back.
    final screen = total * pixels.scale;
    if (screen < pixels.fromLogical(6) ||
        screen >
            pixels.fromLogical(reference.size.width + reference.size.height)) {
      return null;
    }
    return pattern;
  }

  WorldLineKey _lineKey(ResolvedStyle style, bool dashed) => WorldLineKey(
    color: _colorFor(style),
    lineWeight: style.lineWeight,
    lineType: style.lineType,
    lineTypeScale: style.lineTypeScale,
    order: drawOrder,
    dashed: dashed,
  );

  Float64List _local(Float64List world) {
    final out = Float64List(world.length);
    final ox = origin.x;
    final oy = origin.y;
    for (var i = 0; i < world.length; i += 2) {
      out[i] = world[i] - ox;
      out[i + 1] = world[i + 1] - oy;
    }
    return out;
  }

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 4) return;
    if (simplifyPixels > 0) {
      xy = simplifyPolyline(xy, _simplifyWorld, closed: closed);
    }
    final clip = worldClip;
    if (clip != null) {
      _polylineClipped(xy, style, closed: closed, clip: clip);
      return;
    }
    final pattern = _patternFor(style);
    final key = _lineKey(style, pattern != null);
    final batch = lineBatches.putIfAbsent(
      key,
      () => WorldLineBatch(key, pattern),
    );
    batch.add(_local(xy), closed: closed);
  }

  void _polylineClipped(
    Float64List xy,
    ResolvedStyle style, {
    required bool closed,
    required Bounds2 clip,
  }) {
    final previous = worldClip;
    worldClip = null;
    void segment(double x0, double y0, double x1, double y1) {
      final cut = _clipSegment(x0, y0, x1, y1, clip);
      if (cut == null) return;
      polyline(Float64List.fromList([cut.$1, cut.$2, cut.$3, cut.$4]), style);
    }

    final count = xy.length ~/ 2;
    for (var i = 0; i + 1 < count; i++) {
      segment(xy[i * 2], xy[i * 2 + 1], xy[(i + 1) * 2], xy[(i + 1) * 2 + 1]);
    }
    if (closed && count > 2) {
      segment(xy[(count - 1) * 2], xy[(count - 1) * 2 + 1], xy[0], xy[1]);
    }
    worldClip = previous;
  }

  static (double, double, double, double)? _clipSegment(
    double x0,
    double y0,
    double x1,
    double y1,
    Bounds2 box,
  ) {
    var c0 = _outCode(x0, y0, box);
    var c1 = _outCode(x1, y1, box);
    while (true) {
      if ((c0 | c1) == 0) return (x0, y0, x1, y1);
      if ((c0 & c1) != 0) return null;
      final code = c0 != 0 ? c0 : c1;
      late final double x;
      late final double y;
      if (code & 8 != 0) {
        x = x0 + (x1 - x0) * (box.maxY - y0) / (y1 - y0);
        y = box.maxY;
      } else if (code & 4 != 0) {
        x = x0 + (x1 - x0) * (box.minY - y0) / (y1 - y0);
        y = box.minY;
      } else if (code & 2 != 0) {
        y = y0 + (y1 - y0) * (box.maxX - x0) / (x1 - x0);
        x = box.maxX;
      } else {
        y = y0 + (y1 - y0) * (box.minX - x0) / (x1 - x0);
        x = box.minX;
      }
      if (code == c0) {
        x0 = x;
        y0 = y;
        c0 = _outCode(x0, y0, box);
      } else {
        x1 = x;
        y1 = y;
        c1 = _outCode(x1, y1, box);
      }
    }
  }

  static int _outCode(double x, double y, Bounds2 box) {
    var code = 0;
    if (x < box.minX) {
      code |= 1;
    } else if (x > box.maxX) {
      code |= 2;
    }
    if (y < box.minY) {
      code |= 4;
    } else if (y > box.maxY) {
      code |= 8;
    }
    return code;
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    if (xy.length < 6) return;
    final clip = worldClip;
    if (clip != null) {
      var inside = false;
      for (var i = 0; i + 1 < xy.length; i += 2) {
        if (clip.containsPoint(xy[i], xy[i + 1])) {
          inside = true;
          break;
        }
      }
      if (!inside) return;
    }
    final key = WorldFillKey(color: _colorFor(style), order: drawOrder);
    final batch = fillBatches.putIfAbsent(key, () => WorldFillBatch(key));
    batch.addRing(_local(_simplifiedRing(xy)));
    for (final hole in holes) {
      if (hole.length >= 6) {
        batch.addRing(_local(_simplifiedRing(hole)));
      }
    }
  }

  Float64List _simplifiedRing(Float64List ring) => simplifyPixels > 0
      ? simplifyPolyline(ring, _simplifyWorld, closed: true)
      : ring;

  @override
  void point(double x, double y, ResolvedStyle style) {
    final clip = worldClip;
    if (clip != null && !clip.containsPoint(x, y)) return;
    final key = WorldPointKey(
      color: _colorFor(style),
      lineWeight: style.lineWeight,
      order: drawOrder,
    );
    final local = _local(Float64List.fromList([x, y]));
    pointBatches
        .putIfAbsent(key, () => WorldPointBatch(key))
        .add(local[0], local[1]);
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    if (geometry.text.isEmpty) return;
    final clip = worldClip;
    if (clip != null &&
        !clip.containsPoint(geometry.origin.x, geometry.origin.y)) {
      return;
    }
    final family = fonts.resolve(
      styleFont: geometry.fontFamily,
      bigFont: geometry.bigFontFamily,
      text: geometry.text,
    );
    texts.add(
      WorldTextItem(
        geometry: geometry,
        color: _colorFor(style),
        fontFamily: family,
        order: drawOrder,
        bounds: geometry.estimatedBounds(),
      ),
    );
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    images.add(WorldImageItem(geometry: geometry, order: drawOrder));
  }
}

/// Builds a [WorldScene] for the whole active layout.
///
/// The scene is flattened at [reference]'s tolerance and collapse size. Its
/// geometry is in drawing coordinates, so the camera never changes what is in
/// the list — only how it is drawn.
class WorldSceneBuilder {
  WorldSceneBuilder({
    required this.palette,
    this.cache,
    this.fonts = const DrawingFontMap(),
    this.shxFonts = const ShxFontTable(),
    this.useBlockCache = true,
    this.simplifyPixels = 0.15,
  });

  final AciPalette palette;
  final TessellationCache? cache;
  final DrawingFontMap fonts;
  final ShxFontTable shxFonts;
  final double simplifyPixels;

  /// Share flattened block definitions between INSERT instances.
  ///
  /// Off is useful for comparison and for a caller that deliberately wants
  /// every instance expanded in place.
  final bool useBlockCache;

  BlockDisplayCache? _blockCache;

  /// Block flattening shared by every insert of the same definition.
  BlockDisplayCache? get blockCache => _blockCache;

  static const double minimumPixelSize = 1.5;

  /// Above this many objects the whole-drawing retained scene starts to cost
  /// more than the camera-baked path. Tiling is the next step; until then the
  /// renderer falls back to the existing cache for very large files.
  static const int maxRetainedEntities = 100000;

  /// Flatten the retained scene this many times finer than the camera asks.
  /// A zoom-in in flight then still has real curves and small details instead
  /// of points, and the exact build only has to correct the level of detail
  /// once the camera settles.
  static const double previewDetail = 4;

  /// A build stays usable while the camera is within this factor of the scale
  /// it was flattened for. Zooming out further is only a performance concern;
  /// zooming in further would expose the coarser curve tessellation.
  static const double maxZoomOut = 0.5;

  static double detailTolerance(CadViewport viewport) =>
      viewport.tolerance / previewDetail;

  static double detailMinExtent(CadViewport viewport) =>
      viewport.pixelsToWorld(minimumPixelSize) / previewDetail;

  static int toleranceBucketFor(CadViewport viewport) =>
      TessellationCache.toleranceBucket(detailTolerance(viewport));

  static int extentBucketFor(CadViewport viewport) =>
      TessellationCache.extentBucket(detailMinExtent(viewport));

  WorldScene? build(
    CadDocument document,
    CadViewport reference, {
    Set<String>? onlyLayers,
    Set<int>? hiddenIds,
    bool plotLayers = false,
  }) {
    final job = begin(
      document,
      reference,
      onlyLayers: onlyLayers,
      hiddenIds: hiddenIds,
      plotLayers: plotLayers,
    );
    if (job == null) return null;
    WorldScene? scene;
    while (scene == null) {
      scene = job.step(const Duration(days: 1));
    }
    return scene;
  }

  /// Starts a build that can be advanced a few milliseconds at a time.
  ///
  /// The renderer uses this to keep a large whole-drawing flatten off the
  /// critical frame. [build] runs the same job to completion for tests and
  /// non-interactive callers.
  WorldSceneBuildJob? begin(
    CadDocument document,
    CadViewport reference, {
    Set<String>? onlyLayers,
    Set<int>? hiddenIds,
    bool plotLayers = false,
  }) {
    if (!reference.isUsable) return null;
    if (document.entityCount > maxRetainedEntities) return null;
    final extents = document.extents;
    if (extents.isEmpty || !extents.isFinite) return null;

    final tolerance = detailTolerance(reference);
    final minExtent = detailMinExtent(reference);
    final sink = WorldSink(
      origin: extents.center,
      reference: reference,
      palette: palette,
      fonts: fonts,
      lineTypes: {
        for (final lineType in document.lineTypes.values)
          if (!lineType.isSolid) lineType.name: lineType.dashArray,
      },
      globalLineTypeScale:
          double.tryParse(document.headerVariables[r'$LTSCALE'] ?? '') ?? 1,
      simplifyPixels: simplifyPixels,
    );
    if (!identical(_blockCache?.document, document) || !useBlockCache) {
      _blockCache = useBlockCache ? BlockDisplayCache(document) : null;
    }
    final blocks = _blockCache;
    final spaces =
        Picker.spacesUnder(
              document,
              extents,
              tolerance: tolerance,
              minExtent: minExtent,
              shxFonts: shxFonts,
              query: null,
              pixelsPerUnit: 0,
            )
            .map(
              (space) => LayoutSpace(
                blockName: space.blockName,
                query: space.query,
                context: blocks == null
                    ? space.context
                    : space.context.withBlocks(blocks),
                paperClip: space.paperClip,
                hiddenLayers: space.hiddenLayers,
              ),
            )
            .toList();
    return WorldSceneBuildJob._(
      builder: this,
      document: document,
      reference: reference,
      sink: sink,
      extents: extents,
      tolerance: tolerance,
      minExtent: minExtent,
      spaces: spaces,
      onlyLayers: onlyLayers,
      hiddenIds: hiddenIds,
      plotLayers: plotLayers,
    );
  }

  static List<WorldPass> _bucket(WorldSink sink) {
    final orders = <int>{
      for (final batch in sink.lineBatches.values) batch.key.order,
      for (final batch in sink.pointBatches.values) batch.key.order,
      for (final batch in sink.fillBatches.values) batch.key.order,
      for (final item in sink.texts) item.order,
      for (final item in sink.images) item.order,
    }.toList()..sort();
    if (orders.isEmpty) return const [];
    return [
      for (final order in orders)
        WorldPass(
          order: order,
          images: [
            for (final item in sink.images)
              if (item.order == order) item,
          ],
          fillBatches: [
            for (final batch in sink.fillBatches.values)
              if (batch.key.order == order && !batch.isEmpty) batch,
          ],
          lineBatches: [
            for (final batch in sink.lineBatches.values)
              if (batch.key.order == order && batch.segmentCount > 0) batch,
          ],
          pointBatches: [
            for (final batch in sink.pointBatches.values)
              if (batch.key.order == order && batch.points.isNotEmpty) batch,
          ],
          texts: [
            for (final item in sink.texts)
              if (item.order == order) item,
          ],
        ),
    ];
  }
}

/// A resumable whole-drawing flatten.
///
/// Each [step] processes entities until its budget runs out. The sink is kept
/// alive between calls, so callers can spread a several-hundred-millisecond
/// build across frames without blocking the camera.
class WorldSceneBuildJob {
  WorldSceneBuildJob._({
    required WorldSceneBuilder builder,
    required this.document,
    required CadViewport reference,
    required WorldSink sink,
    required Bounds2 extents,
    required double tolerance,
    required double minExtent,
    required List<LayoutSpace> spaces,
    required Set<String>? onlyLayers,
    required Set<int>? hiddenIds,
    required bool plotLayers,
  }) : _builder = builder,
       _reference = reference,
       _sink = sink,
       _extents = extents,
       _minExtent = minExtent,
       _bucket = TessellationCache.toleranceBucket(tolerance),
       _spaces = spaces,
       _onlyLayers = onlyLayers,
       _hiddenIds = hiddenIds,
       _plotLayers = plotLayers;

  final WorldSceneBuilder _builder;
  final CadDocument document;
  final CadViewport _reference;
  final WorldSink _sink;
  final Bounds2 _extents;
  final double _minExtent;
  final int _bucket;
  final List<LayoutSpace> _spaces;
  final Set<String>? _onlyLayers;
  final Set<int>? _hiddenIds;
  final bool _plotLayers;

  Duration _cpu = Duration.zero;
  int _spaceIndex = 0;
  bool _spaceStarted = false;
  List<CadEntity> _entities = const [];
  int _entityIndex = 0;
  Bounds2? _previousClip;
  int _drawn = 0;
  bool _framesAdded = false;
  List<WorldLineBatch>? _indexList;
  int _indexAt = 0;
  WorldScene? _result;

  bool get isDone => _result != null;

  CadViewport get reference => _reference;

  /// Advances the build for at most [budget], returning the scene when done.
  WorldScene? step(Duration budget) {
    final result = _result;
    if (result != null) return result;
    final tick = Stopwatch()..start();
    while (_spaceIndex < _spaces.length) {
      final space = _spaces[_spaceIndex];
      if (!_spaceStarted) {
        _previousClip = _sink.worldClip;
        _sink.worldClip = space.paperClip;
        _entities = document.entitiesOf(space.blockName);
        _entityIndex = 0;
        _spaceStarted = true;
      }
      while (_entityIndex < _entities.length) {
        _emit(space, _entities[_entityIndex++]);
        if (budget > Duration.zero && tick.elapsed >= budget) {
          _cpu += tick.elapsed;
          return null;
        }
      }
      _sink.worldClip = _previousClip;
      _spaceIndex++;
      _spaceStarted = false;
    }

    if (!_framesAdded) {
      _framesAdded = true;
      final layout = document.activeLayout;
      if (!document.isEditingBlock &&
          !layout.isModelSpace &&
          layout.viewports.isNotEmpty) {
        for (final window in layout.viewports) {
          _sink.polyline(
            Float64List.fromList([
              window.paperBounds.minX,
              window.paperBounds.minY,
              window.paperBounds.maxX,
              window.paperBounds.minY,
              window.paperBounds.maxX,
              window.paperBounds.maxY,
              window.paperBounds.minX,
              window.paperBounds.maxY,
            ]),
            ResolvedStyle.fallback,
            closed: true,
          );
        }
      }
    }
    _indexList ??= _sink.lineBatches.values.toList();
    final batches = _indexList!;
    while (_indexAt < batches.length) {
      batches[_indexAt++].indexCells();
      if (budget > Duration.zero && tick.elapsed >= budget) {
        _cpu += tick.elapsed;
        return null;
      }
    }
    _cpu += tick.elapsed;
    final passes = WorldSceneBuilder._bucket(_sink);
    _result = WorldScene(
      viewport: _reference,
      origin: _extents.center,
      passes: passes,
      entityCount: _drawn,
      segmentCount: _sink.segmentCount,
      buildTime: _cpu,
      bounds: _extents,
      toleranceBucket: _bucket,
      extentBucket: TessellationCache.extentBucket(_minExtent),
      previewDetail: WorldSceneBuilder.previewDetail,
    );
    return _result;
  }

  void _emit(LayoutSpace space, CadEntity entity) {
    if (!entity.props.visible) return;
    if (_plotLayers) {
      if (_onlyLayers != null && !_onlyLayers.contains(entity.props.layer)) {
        return;
      }
    } else {
      if (!document.isLayerVisible(entity.props.layer)) return;
      if (_onlyLayers != null && !_onlyLayers.contains(entity.props.layer)) {
        return;
      }
    }
    if (_hiddenIds != null && _hiddenIds.contains(entity.id)) return;
    if (space.hidesLayer(entity.props.layer)) return;

    final context = space.context;
    final cache = _builder.cache;
    if (cache != null &&
        entity is! InsertEntity &&
        context.transform.isIdentity &&
        space.paperClip == null) {
      final cached = cache.lookup(
        entity,
        _bucket,
        minExtent: context.minExtent,
      );
      if (cached != null) {
        _sink.replay(cached);
      } else {
        final recorder = RecordingSink();
        entity.emit(context, TeeSink(_sink, recorder));
        cache.remember(entity, _bucket, recorder, minExtent: context.minExtent);
      }
    } else {
      entity.emit(context, _sink);
    }
    _drawn++;
  }
}

class _AtlasPlacement {
  const _AtlasPlacement({
    required this.rect,
    required this.transform,
    required this.color,
  });

  final ui.Rect rect;
  final ui.RSTransform transform;
  final ui.Color color;
}

/// Paints a [WorldScene] under any camera, with no scene rebuild.
class WorldScenePainter {
  WorldScenePainter({
    required ParagraphCache paragraphs,
    ScenePainter? textPainter,
    TextAtlas? textAtlas,
  }) : _textPainter = textPainter ?? ScenePainter(paragraphs: paragraphs),
       _textAtlas =
           textAtlas ??
           TextAtlas(
             paragraphs: paragraphs,
             fallbackFamily:
                 textPainter?.fontFamily ??
                 const DrawingFontMap().latinFallback,
           );

  final ScenePainter _textPainter;
  final TextAtlas _textAtlas;

  final ui.Paint _fillPaint = ui.Paint()
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = true;
  final ui.Paint _linePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.butt
    ..isAntiAlias = true;
  final ui.Paint _pointPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..isAntiAlias = true;
  final List<TextItem> _textItems = [];
  final Map<ui.Image, List<_AtlasPlacement>> _atlasGroups = {};
  final ui.Paint _atlasPaint = ui.Paint()
    ..isAntiAlias = true
    ..filterQuality = ui.FilterQuality.low;

  /// Called when the atlas has more runs to render. The drawing layer should
  /// schedule one more frame; one page per frame keeps the warm-up off the
  /// critical path.
  void Function()? onNeedsPaint;

  /// Segments actually submitted by the last [paint], for diagnostics.
  int lastDrawnSegments = 0;
  int lastLineDrawCalls = 0;
  int _drawnSegments = 0;
  int _lineDrawCalls = 0;

  TextAtlas get textAtlas => _textAtlas;

  void dispose() {
    onNeedsPaint = null;
    _textAtlas.dispose();
  }

  /// Text smaller than this many logical pixels is a box while the camera is
  /// moving. Glyphs below four pixels are barely readable, and a sheet full of
  /// them is most of a zoom frame's cost.
  static const double motionTextPixels = 4;

  void paint(
    ui.Canvas canvas,
    WorldScene scene,
    CadViewport viewport, {
    double textPixels = minimumEmittedTextPixels,
    int maxTextDraws = 500,
  }) {
    if (!viewport.isUsable) return;
    lastDrawnSegments = 0;
    lastLineDrawCalls = 0;
    _drawnSegments = 0;
    _lineDrawCalls = 0;
    final dpr =
        viewport.devicePixelRatio > 0 && viewport.devicePixelRatio.isFinite
        ? viewport.devicePixelRatio
        : 1.0;
    final pixels = viewport.pixels;
    final localVisible = Bounds2(
      viewport.visibleBounds.minX - scene.origin.x,
      viewport.visibleBounds.minY - scene.origin.y,
      viewport.visibleBounds.maxX - scene.origin.x,
      viewport.visibleBounds.maxY - scene.origin.y,
    );

    final fillPaint = _fillPaint;
    final linePaint = _linePaint;
    final pointPaint = _pointPaint;

    canvas.save();
    canvas.scale(1 / dpr);
    canvas.translate(pixels.xOf(scene.origin.x), pixels.yOf(scene.origin.y));
    canvas.scale(pixels.scale, -pixels.scale);

    for (final pass in scene.passes) {
      for (final item in pass.images) {
        _paintImage(canvas, item.geometry, pixels);
      }
      for (final batch in pass.fillBatches) {
        if (!batch.bounds.intersects(localVisible)) continue;
        fillPaint.color = batch.key.color;
        canvas.drawPath(batch.path, fillPaint);
      }
      for (final batch in pass.lineBatches) {
        if (!batch.bounds.intersects(localVisible)) continue;
        final screenWidth = _screenLineWidth(
          batch.key.lineWeight,
          viewport,
          pixels,
        );
        linePaint
          ..color = batch.key.color
          ..strokeWidth = (screenWidth <= 0 ? 1.0 : screenWidth) / pixels.scale;
        final dash = batch.pattern;
        final useDashes =
            dash != null &&
            batch.dashed.isNotEmpty &&
            _dashesVisible(dash, viewport, pixels);
        _paintLineBatch(
          canvas,
          batch,
          localVisible,
          linePaint,
          useDashes: useDashes,
        );
      }
      for (final batch in pass.pointBatches) {
        if (!batch.bounds.intersects(localVisible)) continue;
        final base = _screenLineWidth(batch.key.lineWeight, viewport, pixels);
        final width = (base <= 0 ? 1.0 : base) + pixels.fromLogical(2);
        pointPaint
          ..color = batch.key.color
          ..strokeWidth = width / pixels.scale;
        canvas.drawRawPoints(
          ui.PointMode.points,
          batch.points.view,
          pointPaint,
        );
      }
    }

    canvas.restore();
    lastDrawnSegments = _drawnSegments;
    lastLineDrawCalls = _lineDrawCalls;
    _paintTexts(canvas, scene, viewport, pixels, textPixels, maxTextDraws);
  }

  /// Draws one line batch, using its world-space grid when the camera sees
  /// only a fraction of it.
  ///
  /// At overview zoom the batch is usually wholly visible and goes out in one
  /// call. Zoomed into a detail, only the cells under the viewport are copied
  /// out, so a sheet-sized batch does not make every frame pay for the whole
  /// drawing.
  void _paintLineBatch(
    ui.Canvas canvas,
    WorldLineBatch batch,
    Bounds2 visible,
    ui.Paint paint, {
    required bool useDashes,
  }) {
    final buffer = useDashes ? batch.dashed : batch.solid;
    if (buffer.isEmpty) return;
    final view = buffer.view;
    final cells = useDashes ? batch.dashedCells : batch.solidCells;
    if (cells == null || _mostlyVisible(batch.bounds, visible)) {
      _drawnSegments += view.length ~/ 4;
      _lineDrawCalls++;
      canvas.drawRawPoints(ui.PointMode.lines, view, paint);
      return;
    }
    final starts = cells.starts;
    final bounds = cells.bounds;
    for (var c = 0; c < bounds.length; c++) {
      final start = starts[c];
      final end = starts[c + 1];
      if (start == end || !bounds[c].intersects(visible)) continue;
      _drawnSegments += end - start;
      _lineDrawCalls++;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(view, start * 4, end * 4),
        paint,
      );
    }
    final wideStart = starts[bounds.length];
    final wide = cells.wideBounds;
    if (wideStart < view.length ~/ 4 &&
        wide != null &&
        wide.intersects(visible)) {
      _drawnSegments += view.length ~/ 4 - wideStart;
      _lineDrawCalls++;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(view, wideStart * 4, view.length),
        paint,
      );
    }
  }

  static bool _mostlyVisible(Bounds2 batch, Bounds2 visible) {
    if (visible.containsBox(batch)) return true;
    final area = batch.width * batch.height;
    if (area <= 0) return false;
    final viewArea = visible.width * visible.height;
    return viewArea >= area * 0.6;
  }

  void _paintTexts(
    ui.Canvas canvas,
    WorldScene scene,
    CadViewport viewport,
    PixelSpace pixels,
    double textPixels,
    int maxTextDraws,
  ) {
    final visible = viewport.visibleBounds;
    final items = _textItems..clear();
    final boxes = <ui.Color, ui.Path>{};
    final candidates = <(WorldTextItem, double)>[];
    final threshold = pixels.fromLogical(textPixels);
    void addBox(WorldTextItem item) {
      final color = item.color.withValues(alpha: 0.5);
      boxes
          .putIfAbsent(color, () => ui.Path())
          .addRect(_placeholderRect(item.geometry, viewport));
    }

    for (final pass in scene.passes) {
      for (final item in pass.texts) {
        if (!item.bounds
            .inflated(viewport.pixelsToWorld(2))
            .intersects(visible)) {
          continue;
        }
        final pixelHeight = item.geometry.height * pixels.scale;
        if (pixelHeight < threshold) {
          addBox(item);
          continue;
        }
        candidates.add((item, pixelHeight));
      }
    }
    if (candidates.length > maxTextDraws) {
      // Keep the largest labels as type; the rest become quick-text boxes.
      // This is the same LOD trade-off as the size threshold, but it also
      // bounds a sheet that simply has a very large number of labels.
      candidates.sort((a, b) => b.$2.compareTo(a.$2));
      for (var i = maxTextDraws; i < candidates.length; i++) {
        addBox(candidates[i].$1);
      }
      candidates.length = maxTextDraws;
    }
    final dpr =
        viewport.devicePixelRatio > 0 && viewport.devicePixelRatio.isFinite
        ? viewport.devicePixelRatio
        : 1.0;
    final settled = textPixels <= minimumEmittedTextPixels + 1e-9;
    final watch = Stopwatch()..start();
    final sprites = <(TextItem, TextAtlasSprite?)>[];
    _textAtlas.beginFrame();
    for (final (item, pixelHeight) in candidates) {
      final geometry = item.geometry;
      final text = TextItem(
        text: geometry.text,
        origin: pixels.offsetOf(geometry.origin),
        pixelHeight: pixelHeight,
        rotation: -geometry.rotation,
        color: item.color,
        hAlign: geometry.hAlign.index,
        vAlign: geometry.vAlign.index,
        wrapWidth: geometry.rectangleWidth * pixels.scale,
        isMultiline: geometry.isMultiline,
        widthFactor: geometry.widthFactor,
        obliqueAngle: geometry.obliqueAngle,
        tracking: geometry.tracking,
        fontFamily: item.fontFamily,
        boxAnchor: geometry.anchor == TextAnchor.box,
        backwards: geometry.backwards,
        upsideDown: geometry.upsideDown,
        underline: geometry.underline,
        overline: geometry.overline,
        strike: geometry.strike,
        order: item.order,
      );
      TextAtlasSprite? sprite;
      if (_atlasEligible(text)) {
        final allowCreate =
            settled &&
            watch.elapsedMicroseconds < atlasLayoutBudget.inMicroseconds &&
            _textAtlas.createdThisFrame < atlasNewRunsPerFrame;
        sprite = _textAtlas.tryObtain(
          text,
          fontFamily: text.fontFamily.isEmpty
              ? _textPainter.fontFamily
              : text.fontFamily,
          allowCreate: allowCreate,
        );
      }
      sprites.add((text, sprite));
    }
    if (settled && _textAtlas.hasPendingWork) _textAtlas.buildOnePage();

    _atlasGroups.clear();
    for (final (text, sprite) in sprites) {
      if (sprite != null && sprite.isReady) {
        final placement = _atlasPlacement(text, sprite);
        final image = sprite.image;
        if (placement != null && image != null) {
          _atlasGroups.putIfAbsent(image, () => []).add(placement);
          continue;
        }
      }
      items.add(text);
    }
    if (boxes.isNotEmpty) {
      final paint = ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..isAntiAlias = true;
      for (final entry in boxes.entries) {
        paint.color = entry.key;
        canvas.drawPath(entry.value, paint);
      }
    }
    if (items.isNotEmpty) {
      _textPainter.paint(
        canvas,
        RenderScene.single(viewport: viewport, texts: items),
      );
    }
    _paintAtlas(canvas, dpr);
    if (_textAtlas.hasPendingWork) onNeedsPaint?.call();
  }

  static const int atlasNewRunsPerFrame = 128;
  static const Duration atlasLayoutBudget = Duration(milliseconds: 4);

  /// Features that need the paragraph path: a shear, a reversed run or
  /// underlines are not a uniform sprite transform.
  static bool _atlasEligible(TextItem item) =>
      item.text.isNotEmpty &&
      !item.underline &&
      !item.overline &&
      !item.strike &&
      !item.backwards &&
      !item.upsideDown &&
      item.obliqueAngle.abs() <= 1e-9;

  _AtlasPlacement? _atlasPlacement(TextItem item, TextAtlasSprite sprite) {
    final scale = item.pixelHeight / sprite.band;
    if (!scale.isFinite || scale <= 0) return null;
    final width = (item.wrapWidth > 0
        ? item.wrapWidth
        : sprite.maxIntrinsicWidth * scale);
    final height = sprite.paragraphHeight * scale;
    final baseline = sprite.baseline * scale;
    final dx = switch (item.hAlign) {
      1 || 4 || 5 => -width / 2,
      2 => -width,
      _ => 0.0,
    };
    final dy = item.boxAnchor
        ? switch (item.vAlign) {
            2 => -height / 2,
            0 || 1 => -height,
            _ => 0.0,
          }
        : switch (item.vAlign) {
            3 => 0.0,
            2 => -baseline / 2,
            1 => -height,
            _ => -baseline,
          };
    final padding = sprite.padding * scale;
    final lx = dx - padding;
    final ly = dy - padding;
    final cos = math.cos(item.rotation);
    final sin = math.sin(item.rotation);
    return _AtlasPlacement(
      rect: sprite.rect,
      transform: ui.RSTransform(
        scale * cos,
        scale * sin,
        item.origin.dx + lx * cos - ly * sin,
        item.origin.dy + lx * sin + ly * cos,
      ),
      color: item.color,
    );
  }

  void _paintAtlas(ui.Canvas canvas, double dpr) {
    if (_atlasGroups.isEmpty) return;
    canvas.save();
    canvas.scale(1 / dpr);
    for (final group in _atlasGroups.entries) {
      final placements = group.value;
      if (placements.isEmpty) continue;
      final transforms = <ui.RSTransform>[];
      final rects = <ui.Rect>[];
      final colors = <ui.Color>[];
      for (final placement in placements) {
        transforms.add(placement.transform);
        rects.add(placement.rect);
        colors.add(placement.color);
      }
      canvas.drawAtlas(
        group.key,
        transforms,
        rects,
        colors,
        ui.BlendMode.dstIn,
        null,
        _atlasPaint,
      );
    }
    canvas.restore();
  }

  static ui.Rect _placeholderRect(TextGeometry geometry, CadViewport viewport) {
    final bounds = geometry.estimatedBounds();
    final a = viewport.toScreen(Vec2(bounds.minX, bounds.maxY));
    final b = viewport.toScreen(Vec2(bounds.maxX, bounds.minY));
    final rect = ui.Rect.fromPoints(a, b);
    final minimum = 1.0;
    return ui.Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(
        math.max(rect.left, rect.right),
        math.min(rect.left, rect.right) + minimum,
      ),
      math.max(
        math.max(rect.top, rect.bottom),
        math.min(rect.top, rect.bottom) + minimum,
      ),
    );
  }

  static bool _dashesVisible(
    List<double> pattern,
    CadViewport viewport,
    PixelSpace pixels,
  ) {
    var total = 0.0;
    for (final segment in pattern) {
      total += segment;
    }
    final screen = total * pixels.scale;
    return screen >= pixels.fromLogical(6) &&
        screen <=
            pixels.fromLogical(viewport.size.width + viewport.size.height);
  }

  static double _screenLineWidth(
    int lineWeight,
    CadViewport viewport,
    PixelSpace pixels,
  ) {
    final millimetres = LineWeight.toMillimetres(lineWeight);
    if (millimetres <= 0) return 0;
    final zoom = viewport.scale < 1 ? viewport.scale : 1.0;
    final width = millimetres / 25.4 * 96 * zoom * pixels.dpr;
    return width.isFinite && width >= 1 ? width : 0;
  }

  static void _paintImage(
    ui.Canvas canvas,
    ImageGeometry geometry,
    PixelSpace pixels,
  ) {
    final path = ui.Path()
      ..moveTo(geometry.origin.x, geometry.origin.y)
      ..relativeLineTo(geometry.uVector.x, geometry.uVector.y)
      ..relativeLineTo(geometry.vVector.x, geometry.vVector.y)
      ..relativeLineTo(-geometry.uVector.x, -geometry.uVector.y)
      ..close();
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1 / pixels.scale
        ..color = const ui.Color(0x66FFFFFF),
    );
  }
}
