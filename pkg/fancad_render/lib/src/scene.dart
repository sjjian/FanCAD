import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:fancad_core/fancad_core.dart';

import 'batch.dart';
import 'palette.dart';
import 'tessellation_cache.dart';
import 'viewport.dart';

/// A frame's worth of geometry, reduced to a handful of draw calls.
class RenderScene {
  RenderScene({
    required this.viewport,
    required this.lineBatches,
    required this.pointBatches,
    required this.fillBatches,
    required this.texts,
    required this.images,
    required this.entityCount,
    required this.segmentCount,
    required this.culledCount,
    required this.buildTime,
    required this.coverage,
  });

  RenderScene.empty(this.viewport)
    : lineBatches = const [],
      pointBatches = const [],
      fillBatches = const [],
      texts = const [],
      images = const [],
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
  final List<LineBatch> lineBatches;
  final List<PointBatch> pointBatches;
  final List<FillBatch> fillBatches;
  final List<TextItem> texts;
  final List<ImageItem> images;

  /// Entities that contributed geometry.
  final int entityCount;

  /// Line segments in the scene: the honest measure of frame cost.
  final int segmentCount;

  /// Entities the spatial index returned but that were dropped as off screen.
  final int culledCount;

  final Duration buildTime;

  /// Whether this scene can be reused for [other] by translating it.
  bool canReuseFor(CadViewport other) =>
      coverage.isNotEmpty &&
      other.scale == viewport.scale &&
      other.size == viewport.size &&
      coverage.containsBox(other.visibleBounds);

  /// The screen-space translation that adapts this scene to [other].
  Offset translationFor(CadViewport other) => Offset(
    (viewport.center.x - other.center.x) * viewport.scale,
    (other.center.y - viewport.center.y) * viewport.scale,
  );

  /// Draw calls this scene will issue.
  int get drawCallCount =>
      lineBatches.length +
      pointBatches.length +
      fillBatches.length +
      texts.length +
      images.length;

  @override
  String toString() =>
      'RenderScene($entityCount entities, $segmentCount segments, '
      '$drawCallCount draw calls, '
      '${(buildTime.inMicroseconds / 1000).toStringAsFixed(1)}ms)';
}

/// Turns a document and a viewport into a [RenderScene].
///
/// The pipeline is four steps, ordered so the most work is discarded earliest:
/// query the spatial index for the visible region, drop entities too small to
/// see, flatten what remains at a tolerance matched to the current zoom, and
/// merge the results into one batch per colour and line weight.
///
/// The last step is what makes large drawings viable. A drawing with 200,000
/// lines spread over a dozen layers becomes roughly a dozen `drawRawPoints`
/// calls rather than 200,000 `drawLine` calls.
class SceneBuilder {
  SceneBuilder({required this.palette, TessellationCache? cache})
    : cache = cache ?? TessellationCache();

  final AciPalette palette;
  final TessellationCache cache;

  /// Entities whose on-screen bounding box is smaller than this collapse to a
  /// single pixel. At a zoomed-out view of a large drawing this removes most of
  /// the work, and it removes exactly the entities whose shape could not have
  /// been made out anyway.
  static const double minimumPixelSize = 1.5;

  /// Text smaller than this is drawn as a bar instead of glyphs, which is both
  /// faster and closer to what the eye actually resolves.
  static const double minimumTextPixels = 4.5;

  /// How far beyond the visible area geometry is built, as a fraction of the
  /// viewport. A third of a screen is enough that a flick pan stays inside the
  /// existing scene long enough for the replacement to be built.
  static const double overscan = 0.35;

  RenderScene build(
    CadDocument document,
    CadViewport viewport, {
    Set<String>? onlyLayers,
    bool withOverscan = true,
  }) {
    if (!viewport.isUsable) return RenderScene.empty(viewport);

    final stopwatch = Stopwatch()..start();
    final visible = withOverscan
        ? viewport.paddedBounds(overscan)
        : viewport.visibleBounds;
    final tolerance = viewport.tolerance;
    final bucket = TessellationCache.toleranceBucket(tolerance);
    final minimumWorldSize = viewport.pixelsToWorld(minimumPixelSize);

    final sink = BatchingSink(
      viewport: viewport,
      palette: palette,
      lineTypes: {
        for (final lineType in document.lineTypes.values)
          if (!lineType.isSolid) lineType.name: lineType.dashArray,
      },
      globalLineTypeScale:
          double.tryParse(document.headerVariables[r'$LTSCALE'] ?? '') ?? 1,
    );

    final block = document.currentBlockName;
    final context = document.emitContext(
      tolerance: tolerance,
      clip: visible,
    );
    var drawn = 0;
    var culled = 0;

    for (final id in document.indexFor(block).search(visible)) {
      final entity = document.entity(id);
      if (entity == null || !entity.props.visible) continue;
      if (!document.isLayerVisible(entity.props.layer)) continue;
      if (onlyLayers != null && !onlyLayers.contains(entity.props.layer)) {
        continue;
      }

      final bounds = document.boundsOfEntity(entity);
      if (bounds.isNotEmpty && !bounds.intersects(visible)) {
        culled++;
        continue;
      }
      if (bounds.isNotEmpty &&
          !_isPointLike(entity) &&
          bounds.width < minimumWorldSize &&
          bounds.height < minimumWorldSize) {
        // Collapse rather than drop: a field of tiny blocks should still read
        // as a grey mass, not as blank paper.
        sink.point(
          bounds.center.x,
          bounds.center.y,
          document.resolve(entity.props, ResolvedStyle.fallback),
        );
        drawn++;
        continue;
      }

      if (TessellationCache.isWorthCaching(entity)) {
        sink.replay(
          cache.obtain(
            entity,
            bucket,
            (recorder) => entity.emit(context, recorder),
          ),
        );
      } else {
        entity.emit(context, sink);
      }
      drawn++;
    }

    stopwatch.stop();
    return RenderScene(
      viewport: viewport,
      lineBatches: sink.lineBatches.values
          .where((batch) => !batch.isEmpty)
          .toList(),
      pointBatches: sink.pointBatches.values
          .where((batch) => !batch.isEmpty)
          .toList(),
      fillBatches: sink.fillBatches.values
          .where((batch) => !batch.isEmpty)
          .toList(),
      texts: sink.texts,
      images: sink.images,
      entityCount: drawn,
      segmentCount: sink.segmentCount,
      culledCount: culled,
      buildTime: stopwatch.elapsed,
      coverage: visible,
    );
  }

  static bool _isPointLike(CadEntity entity) =>
      entity.kind == EntityKind.point ||
      entity.kind == EntityKind.text ||
      entity.kind == EntityKind.mtext;
}

/// Converts world-space primitives into screen-space draw batches.
///
/// Public because the overlay and the print pipeline reuse it against a
/// different viewport.
class BatchingSink implements GeometrySink {
  BatchingSink({
    required this.viewport,
    required this.palette,
    this.lineTypes = const {},
    this.globalLineTypeScale = 1,
    this.colorOverride,
    this.strokeWidthOverride,
  });

  final CadViewport viewport;
  final AciPalette palette;

  /// Dash patterns in drawing units, by line type name. Solid line types are
  /// simply absent.
  final Map<String, List<double>> lineTypes;
  final double globalLineTypeScale;

  /// Forces every primitive to one colour, used to draw a highlight or a
  /// preview of a pending change.
  final ui.Color? colorOverride;
  final double? strokeWidthOverride;

  final Map<BatchKey, LineBatch> lineBatches = {};
  final Map<BatchKey, PointBatch> pointBatches = {};
  final Map<BatchKey, FillBatch> fillBatches = {};
  final List<TextItem> texts = [];
  final List<ImageItem> images = [];

  int segmentCount = 0;

  /// Reused between primitives so the hot loop does not allocate.
  Float32List _scratch = Float32List(1024);

  bool get isEmpty =>
      lineBatches.isEmpty &&
      pointBatches.isEmpty &&
      fillBatches.isEmpty &&
      texts.isEmpty &&
      images.isEmpty;

  void replay(List<CachedPrimitive> primitives) {
    for (final primitive in primitives) {
      switch (primitive.kind) {
        case PrimitiveKind.polyline:
          polyline(primitive.xy, primitive.style, closed: primitive.closed);
        case PrimitiveKind.fill:
          fill(primitive.xy, primitive.style, holes: primitive.holes);
        case PrimitiveKind.point:
          point(primitive.xy[0], primitive.xy[1], primitive.style);
        case PrimitiveKind.text:
          text(primitive.text!, primitive.style);
        case PrimitiveKind.image:
          image(primitive.image!, primitive.style);
      }
    }
  }

  /// Projects an interleaved world buffer into screen space.
  ///
  /// The returned view is only valid until the next call, which is fine because
  /// every caller copies immediately into a batch.
  Float32List _project(Float64List world) {
    if (_scratch.length < world.length) {
      var capacity = _scratch.length;
      while (capacity < world.length) {
        capacity *= 2;
      }
      _scratch = Float32List(capacity);
    }
    final scale = viewport.scale;
    final offsetX = viewport.size.width / 2 - viewport.center.x * scale;
    final offsetY = viewport.size.height / 2 + viewport.center.y * scale;
    for (var i = 0; i < world.length; i += 2) {
      _scratch[i] = world[i] * scale + offsetX;
      // The Y flip: drawing coordinates go up, screen coordinates go down.
      _scratch[i + 1] = offsetY - world[i + 1] * scale;
    }
    return Float32List.sublistView(_scratch, 0, world.length);
  }

  ui.Color _colorFor(ResolvedStyle style) {
    final override = colorOverride;
    if (override != null) return override;
    final color = palette.colorOf(style.color);
    if (style.transparency <= 0) return color;
    return color.withValues(alpha: 1 - style.transparency / 100);
  }

  /// Line weights are millimetres on paper, so unlike geometry they do not
  /// grow with zoom. Zero means hairline: the thinnest the device can draw.
  double _strokeWidth(ResolvedStyle style) {
    final override = strokeWidthOverride;
    if (override != null) return override;
    final millimetres = LineWeight.toMillimetres(style.lineWeight);
    if (millimetres <= 0) return 0;
    // 96 dpi is the reference other CAD applications use for on-screen line
    // weight display.
    final pixels = millimetres / 25.4 * 96;
    return pixels < 1 ? 0 : pixels;
  }

  BatchKey _keyFor(ResolvedStyle style, {double extraWidth = 0}) =>
      BatchKey(_colorFor(style), _strokeWidth(style) + extraWidth);

  LineBatch _lineBatch(BatchKey key) =>
      lineBatches.putIfAbsent(key, () => LineBatch(key));

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 4) return;
    final projected = _project(xy);
    final batch = _lineBatch(_keyFor(style));
    final before = batch.segmentCount;
    final dashes = _dashPixelsFor(style);
    if (dashes == null) {
      batch.addPolyline(projected, closed: closed);
    } else {
      _addDashed(batch, projected, dashes, closed: closed);
    }
    segmentCount += batch.segmentCount - before;
  }

  /// The dash pattern in screen pixels, or null when the line should be solid.
  ///
  /// Dashes shorter than a few pixels read as a dimmer solid line, so below
  /// that threshold drawing solid is both cheaper and better looking. Patterns
  /// longer than the screen are also pointless: at that zoom the viewer is
  /// inside a single dash.
  List<double>? _dashPixelsFor(ResolvedStyle style) {
    final pattern = lineTypes[style.lineType];
    if (pattern == null || pattern.isEmpty) return null;
    final scale = viewport.scale * style.lineTypeScale * globalLineTypeScale;
    if (scale <= 0 || !scale.isFinite) return null;
    final pixels = [for (final segment in pattern) segment * scale];
    var total = 0.0;
    for (final segment in pixels) {
      total += segment;
    }
    if (total < 6) return null;
    final diagonal = viewport.size.width + viewport.size.height;
    if (total > diagonal) return null;
    return pixels;
  }

  void _addDashed(
    LineBatch batch,
    Float32List screen,
    List<double> dashes, {
    required bool closed,
  }) {
    final count = screen.length ~/ 2;
    if (count < 2) return;
    var dashIndex = 0;
    var remaining = dashes[0];
    var drawing = true;

    void walk(double x0, double y0, double x1, double y1) {
      var length = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
      if (length <= 0) return;
      final dirX = (x1 - x0) / length;
      final dirY = (y1 - y0) / length;
      var startX = x0;
      var startY = y0;
      while (length > 1e-9) {
        final step = math.min(remaining, length);
        final endX = startX + dirX * step;
        final endY = startY + dirY * step;
        if (drawing) batch.vertices.add4(startX, startY, endX, endY);
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

    for (var i = 0; i + 1 < count; i++) {
      walk(
        screen[i * 2],
        screen[i * 2 + 1],
        screen[(i + 1) * 2],
        screen[(i + 1) * 2 + 1],
      );
    }
    if (closed && count > 2) {
      walk(
        screen[(count - 1) * 2],
        screen[(count - 1) * 2 + 1],
        screen[0],
        screen[1],
      );
    }
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    if (xy.length < 6) return;
    final key = _keyFor(style);
    final batch = fillBatches.putIfAbsent(key, () => FillBatch(key));
    batch.addRing(_project(xy));
    for (final hole in holes) {
      if (hole.length >= 6) batch.addRing(_project(hole));
    }
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    // Point markers get a minimum size so they stay visible and clickable.
    final key = _keyFor(style, extraWidth: 2);
    final batch = pointBatches.putIfAbsent(key, () => PointBatch(key));
    final screen = viewport.toScreen(Vec2(x, y));
    batch.vertices.add2(screen.dx, screen.dy);
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    if (geometry.text.isEmpty) return;
    final pixelHeight = geometry.height * viewport.scale;
    final color = _colorFor(style);
    if (pixelHeight < SceneBuilder.minimumTextPixels) {
      // Below a few pixels the glyphs are illegible, but the presence of text
      // is still information. Draw the block it occupies.
      final box = geometry.estimatedBounds();
      if (box.isEmpty) return;
      final key = BatchKey(color.withValues(alpha: 0.5), 0);
      fillBatches.putIfAbsent(key, () => FillBatch(key)).addRing(
        _project(
          Float64List.fromList([
            box.minX, box.minY,
            box.maxX, box.minY,
            box.maxX, box.maxY,
            box.minX, box.maxY,
          ]),
        ),
      );
      return;
    }
    texts.add(
      TextItem(
        text: geometry.text,
        origin: viewport.toScreen(geometry.origin),
        pixelHeight: pixelHeight,
        // Screen Y is inverted, so a counter-clockwise drawing rotation
        // becomes a clockwise screen rotation.
        rotation: -geometry.rotation,
        color: color,
        hAlign: geometry.hAlign.index,
        vAlign: geometry.vAlign.index,
        wrapWidth: geometry.rectangleWidth * viewport.scale,
        isMultiline: geometry.isMultiline,
      ),
    );
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    final origin = viewport.toScreen(geometry.origin);
    images.add(
      ImageItem(
        reference: geometry.reference,
        origin: origin,
        uVector: viewport.toScreen(geometry.origin + geometry.uVector) - origin,
        vVector: viewport.toScreen(geometry.origin + geometry.vVector) - origin,
      ),
    );
  }
}
