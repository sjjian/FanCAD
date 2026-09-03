import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'batch.dart';
import 'batching_sink.dart';
import 'drawing_font.dart';
import 'line_aligner.dart';
import 'palette.dart';
import 'render_scene.dart';
import 'tessellation_cache.dart';
import 'text_cache.dart';
import 'viewport.dart';

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
    this.shxFonts = const ShxFontTable(),
  }) : cache = cache ?? TessellationCache(),
       paragraphs = paragraphs ?? ParagraphCache(),
       fonts = fonts ?? const DrawingFontMap();

  final AciPalette palette;
  final TessellationCache cache;
  final ParagraphCache paragraphs;
  final DrawingFontMap fonts;

  /// Puts thin axis-aligned linework on the pixel grid, as the last step of
  /// every build. Kept on the builder rather than created per build so its
  /// hysteresis carries over from one zoom level to the next.
  final LineAligner aligner = LineAligner();

  /// Parsed SHX faces. Empty keeps the TTF fallback for every STYLE.
  final ShxFontTable shxFonts;

  /// Entities whose on-screen bounding box is smaller than this collapse to a
  /// single pixel. At a zoomed-out view of a large drawing this removes most of
  /// the work, and it removes exactly the entities whose shape could not have
  /// been made out anyway.
  static const double minimumPixelSize = 1.5;

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
      shxFonts: shxFonts,
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
            shxFonts: shxFonts,
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

    final lineBatches = sink.lineBatches.values
        .where((batch) => !batch.isEmpty)
        .toList();
    final pointBatches = sink.pointBatches.values
        .where((batch) => !batch.isEmpty)
        .toList();
    final fillBatches = sink.fillBatches.values
        .where((batch) => !batch.isEmpty)
        .toList();

    // The last step of the build, and the only place alignment happens. The
    // painter must stay free of it: a decision remade every frame changes with
    // the frame, and that is what made close parallels blink under zoom.
    aligner.align(
      lines: lineBatches,
      points: pointBatches,
      pixels: sink.pixels,
    );

    stopwatch.stop();
    return RenderScene(
      viewport: viewport,
      passes: _bucket(
        lineBatches: lineBatches,
        pointBatches: pointBatches,
        fillBatches: fillBatches,
        texts: sink.texts,
        images: sink.images,
      ),
      entityCount: drawn,
      segmentCount: sink.segmentCount,
      culledCount: culled,
      buildTime: stopwatch.elapsed,
      coverage: visible,
    );
  }

  /// Groups the flat batch lists into ascending drawing-order buckets.
  ///
  /// Short-circuits the common case: a document with no explicit order puts
  /// everything in bucket 0, so this is one pass and no grouping work.
  static List<RenderPass> _bucket({
    required List<LineBatch> lineBatches,
    required List<PointBatch> pointBatches,
    required List<FillBatch> fillBatches,
    required List<TextItem> texts,
    required List<ImageItem> images,
  }) {
    var single = true;
    for (final batch in lineBatches) {
      if (batch.key.order != 0) single = false;
    }
    for (final batch in pointBatches) {
      if (batch.key.order != 0) single = false;
    }
    for (final batch in fillBatches) {
      if (batch.key.order != 0) single = false;
    }
    for (final item in texts) {
      if (item.order != 0) single = false;
    }
    for (final item in images) {
      if (item.order != 0) single = false;
    }
    if (single) {
      return [
        RenderPass(
          order: 0,
          images: images,
          fillBatches: fillBatches,
          lineBatches: lineBatches,
          pointBatches: pointBatches,
          texts: texts,
        ),
      ];
    }

    final orders = <int>{
      for (final batch in lineBatches) batch.key.order,
      for (final batch in pointBatches) batch.key.order,
      for (final batch in fillBatches) batch.key.order,
      for (final item in texts) item.order,
      for (final item in images) item.order,
    }.toList()..sort();
    return [
      for (final order in orders)
        RenderPass(
          order: order,
          images: [for (final i in images) if (i.order == order) i],
          fillBatches: [
            for (final b in fillBatches) if (b.key.order == order) b,
          ],
          lineBatches: [
            for (final b in lineBatches) if (b.key.order == order) b,
          ],
          pointBatches: [
            for (final b in pointBatches) if (b.key.order == order) b,
          ],
          texts: [for (final t in texts) if (t.order == order) t],
        ),
    ];
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
    final index = document.indexFor(blockName);
    for (final id in index.search(query)) {
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

      // The index already stored this box while the file was decoded. Asking
      // the entity again would re-tessellate every visible spline just to
      // decide whether it is a pixel or a curve.
      final bounds = index.boundsOf(id) ?? const Bounds2.empty();
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

