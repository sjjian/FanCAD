import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:fancad_core/fancad_core.dart';

import 'batch.dart';
import 'drawing_font.dart';
import 'palette.dart';
import 'tessellation_cache.dart';
import 'text_cache.dart';
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
  SceneBuilder({
    required this.palette,
    TessellationCache? cache,
    ParagraphCache? paragraphs,
    DrawingFontMap? fonts,
  }) : cache = cache ?? TessellationCache(),
       paragraphs = paragraphs ?? ParagraphCache(),
       fonts = fonts ?? const DrawingFontMap();

  final AciPalette palette;
  final TessellationCache cache;
  final ParagraphCache paragraphs;
  final DrawingFontMap fonts;

  /// Entities whose on-screen bounding box is smaller than this collapse to a
  /// single pixel. At a zoomed-out view of a large drawing this removes most of
  /// the work, and it removes exactly the entities whose shape could not have
  /// been made out anyway.
  static const double minimumPixelSize = 1.5;

  /// Text below a physical pixel is drawn as a bar. CAD drawings use thin
  /// stroke fonts whose labels remain useful at two to four pixels high, so
  /// replacing all sub-4.5 px text hid most annotations at sheet overview
  /// zooms.
  static const double minimumTextPixels = 1;

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
      fonts: fonts,
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
      measureWidth: (text, height) => paragraphs.measureWidth(
        text,
        height: height,
        fontFamily: fonts.resolve(
          styleFont: 'txt',
          bigFont: '',
          text: text,
        ),
      ),
    );
    var drawn = 0;
    var culled = 0;

    final paper = _emitBlock(
      document: document,
      sink: sink,
      blockName: block,
      context: context,
      query: visible,
      onlyLayers: onlyLayers,
      bucket: bucket,
      minimumWorldSize: minimumWorldSize,
    );
    drawn += paper.drawn;
    culled += paper.culled;

    final layout = document.activeLayout;
    if (!layout.isModelSpace) {
      for (final viewportWindow in layout.viewports) {
        if (!viewportWindow.paperBounds.intersects(visible)) continue;
        if (viewportWindow.isOn) {
          final scale = viewportWindow.scale.abs();
          final vpContext = document.emitContext(
            tolerance: scale < 1e-12 ? tolerance : tolerance / scale,
            clip: viewportWindow.modelWindow,
            transform: viewportWindow.modelToPaper(),
            measureWidth: context.measureWidth,
          );
          final model = _emitBlock(
            document: document,
            sink: sink,
            blockName: document.modelSpaceBlockName,
            context: vpContext,
            query: viewportWindow.modelWindow,
            onlyLayers: onlyLayers,
            hiddenLayers: {
              for (final name in viewportWindow.frozenLayers)
                name.toLowerCase(),
            },
            bucket: bucket,
            minimumWorldSize: scale < 1e-12
                ? minimumWorldSize
                : minimumWorldSize / scale,
            worldClip: viewportWindow.paperBounds,
          );
          drawn += model.drawn;
          culled += model.culled;
        }
        _emitViewportFrame(sink, viewportWindow.paperBounds);
      }
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

  ({int drawn, int culled}) _emitBlock({
    required CadDocument document,
    required BatchingSink sink,
    required String blockName,
    required EmitContext context,
    required Bounds2 query,
    required Set<String>? onlyLayers,
    Set<String>? hiddenLayers,
    required int bucket,
    required double minimumWorldSize,
    Bounds2? worldClip,
  }) {
    var drawn = 0;
    var culled = 0;
    final previousClip = sink.worldClip;
    if (worldClip != null) sink.worldClip = worldClip;
    for (final id in document.indexFor(blockName).search(query)) {
      final entity = document.entity(id);
      if (entity == null || !entity.props.visible) continue;
      if (!document.isLayerVisible(entity.props.layer)) continue;
      if (onlyLayers != null && !onlyLayers.contains(entity.props.layer)) {
        continue;
      }
      if (hiddenLayers != null &&
          hiddenLayers.contains(entity.props.layer.toLowerCase())) {
        continue;
      }

      final bounds = document.boundsOfEntity(entity);
      if (bounds.isNotEmpty && !bounds.intersects(query)) {
        culled++;
        continue;
      }
      if (bounds.isNotEmpty &&
          !_isPointLike(entity) &&
          entity.kind != EntityKind.insert &&
          bounds.width < minimumWorldSize &&
          bounds.height < minimumWorldSize) {
        // Collapse rather than drop: a field of tiny blocks should still read
        // as a grey mass, not as blank paper. Inserts are left alone — a
        // collapsed block is a single pixel, but hover re-emits the whole
        // definition as a dashed outline, which is how a title frame can
        // appear only while the cursor is over it.
        final center = context.apply(bounds.center);
        sink.point(
          center.x,
          center.y,
          document.resolve(entity.props, ResolvedStyle.fallback),
        );
        drawn++;
        continue;
      }

      // Cached tessellation is in the entity's own space. A paper viewport
      // applies a transform, so replaying the cache would put model geometry
      // on the sheet at the wrong coordinates.
      if (context.transform.isIdentity &&
          TessellationCache.isWorthCaching(entity)) {
        sink.replay(
          cache.obtain(
            entity,
            bucket,
            (recorder) => entity.emit(context.withoutClip(), recorder),
          ),
        );
      } else {
        entity.emit(context, sink);
      }
      drawn++;
    }
    sink.worldClip = previousClip;
    return (drawn: drawn, culled: culled);
  }

  static void _emitViewportFrame(BatchingSink sink, Bounds2 paper) {
    sink.polyline(
      Float64List.fromList([
        paper.minX,
        paper.minY,
        paper.maxX,
        paper.minY,
        paper.maxX,
        paper.maxY,
        paper.minX,
        paper.maxY,
      ]),
      ResolvedStyle.fallback,
      closed: true,
    );
  }
}

/// Converts world-space primitives into screen-space draw batches.
///
/// Public because the overlay and the print pipeline reuse it against a
/// different viewport.
class BatchingSink implements GeometrySink {
  BatchingSink({
    required this.viewport,
    required this.palette,
    this.fonts = const DrawingFontMap(),
    this.lineTypes = const {},
    this.globalLineTypeScale = 1,
    this.colorOverride,
    this.strokeWidthOverride,
  });

  final CadViewport viewport;
  final AciPalette palette;
  final DrawingFontMap fonts;

  /// Dash patterns in drawing units, by line type name. Solid line types are
  /// simply absent.
  final Map<String, List<double>> lineTypes;
  final double globalLineTypeScale;

  /// Forces every primitive to one colour, used to draw a highlight or a
  /// preview of a pending change.
  final ui.Color? colorOverride;
  final double? strokeWidthOverride;

  /// World-space clip used when drawing a paper-space viewport. Geometry that
  /// leaves the window is cut so it does not spill onto the sheet.
  Bounds2? worldClip;

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
    final clip = worldClip;
    if (clip != null) {
      _polylineClipped(xy, style, closed: closed, clip: clip);
      return;
    }
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
      polyline(
        Float64List.fromList([cut.$1, cut.$2, cut.$3, cut.$4]),
        style,
      );
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

  /// Cohen–Sutherland clip of one segment against [box], or null if rejected.
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
    final key = _keyFor(style);
    final batch = fillBatches.putIfAbsent(key, () => FillBatch(key));
    batch.addRing(_project(xy));
    for (final hole in holes) {
      if (hole.length >= 6) batch.addRing(_project(hole));
    }
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    final clip = worldClip;
    if (clip != null && !clip.containsPoint(x, y)) return;
    // Point markers get a minimum size so they stay visible and clickable.
    final key = _keyFor(style, extraWidth: 2);
    final batch = pointBatches.putIfAbsent(key, () => PointBatch(key));
    final screen = viewport.toScreen(Vec2(x, y));
    batch.vertices.add2(screen.dx, screen.dy);
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    if (geometry.text.isEmpty) return;
    final clip = worldClip;
    if (clip != null &&
        !clip.containsPoint(geometry.origin.x, geometry.origin.y)) {
      return;
    }
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
        widthFactor: geometry.widthFactor,
        obliqueAngle: geometry.obliqueAngle,
        tracking: geometry.tracking,
        fontFamily: fonts.resolve(
          styleFont: geometry.fontFamily,
          bigFont: geometry.bigFontFamily,
          text: geometry.text,
        ),
        boxAnchor: geometry.anchor == TextAnchor.box,
        backwards: geometry.backwards,
        upsideDown: geometry.upsideDown,
        underline: geometry.underline,
        overline: geometry.overline,
        strike: geometry.strike,
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
