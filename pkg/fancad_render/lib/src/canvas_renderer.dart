import 'dart:async';
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

import 'diagnostics.dart';
import 'drawing_cache.dart';
import 'drawing_font.dart';
import 'palette.dart';
import 'picking.dart';
import 'render_scene.dart';
import 'scene_builder.dart';
import 'scene_painter.dart';
import 'tessellation_cache.dart';
import 'text_cache.dart';
import 'viewport.dart';
import 'world_scene.dart';

/// What the canvas should show: content, camera and which layers, nothing
/// about how the picture gets there.
///
/// This is deliberately a terminal value rather than a stream of changes. A
/// wheel notch, a trackpad pinch, a `ZOOM` command and a resize all end up as
/// the same thing here — a camera — so the renderer never learns that a
/// "gesture" exists. Whether the camera is still moving, and how much work to
/// spend on it, is decided inside [CanvasRenderer].
@immutable
class RenderTarget {
  const RenderTarget({
    required this.document,
    required this.viewport,
    this.onlyLayers,
    this.hiddenIds = const [],
    this.plotLayers = false,
  });

  final CadDocument document;

  /// The camera the drawing should be seen through.
  final CadViewport viewport;

  /// When set, only these layers are drawn. Layer visibility on the drawing is
  /// left as it is. Used by layer isolation.
  final Set<String>? onlyLayers;

  /// Entities an isolate/hide command has taken out of the picture.
  final List<int> hiddenIds;

  /// Export preview: [onlyLayers] replaces layer visibility, and the host
  /// paints a white sheet with the grid off.
  final bool plotLayers;
}

/// Draws one canvas: scene building, tessellation, recording and the decision
/// of which of them a frame needs.
///
/// Callers hand it a [RenderTarget] and get pixels. The three render paths —
/// replay a pan, replay a zoom under a scale, rebuild and realign — are an
/// implementation detail, as are the caches behind them. That keeps the
/// policy in one place: [CadCanvas] no longer carries a quality flag, a settle
/// timer or a "gesture is in flight" bit.
class CanvasRenderer {
  CanvasRenderer({
    TessellationCache? tessellation,
    ParagraphCache? paragraphs,
    this.retainWorld = true,
  }) : tessellation = tessellation ?? TessellationCache(),
       paragraphs = paragraphs ?? ParagraphCache();

  /// Whether camera moves may use the retained world scene.
  ///
  /// Off keeps the camera-baked cache path only, which is useful while
  /// comparing the two renderers and for callers that need the old contract.
  final bool retainWorld;

  /// How long a camera change counts as still moving.
  ///
  /// Shared with the camera's own resize settle, so a splitter drag that
  /// re-locks the camera at that moment does not force a second wait: the
  /// renderer refuses to call a camera that is still off the pixel grid final.
  static const Duration settleDelay = cameraSettleDelay;

  /// Geometry shared with hit testing and the overlay, so they replay what the
  /// drawing already flattened instead of tessellating it again.
  final TessellationCache tessellation;
  final ParagraphCache paragraphs;

  DrawingFontMap _fonts = const DrawingFontMap();
  ShxFontTable _shxFonts = const ShxFontTable();

  final DrawingCache _cache = DrawingCache();

  SceneBuilder? _builder;
  ScenePainter? _painter;
  Picker? _picker;
  WorldSceneBuilder? _worldBuilder;
  WorldScenePainter? _worldPainter;
  bool _atlasStepScheduled = false;
  WorldScene? _worldScene;
  int _worldVersion = -1;
  Set<String>? _worldLayers;
  bool _worldPlotLayers = false;
  List<int> _worldHiddenIds = const [];
  Timer? _worldRefreshTimer;
  bool _worldRefreshPending = false;
  bool _worldBuildDue = false;
  bool _worldBuiltOnce = false;
  WorldSceneBuildJob? _worldJob;
  bool _worldStepScheduled = false;

  /// Wait this long after the last edit or zoom before rebuilding the retained
  /// scene. An edit stays responsive, and a zoom keeps the old (still complete)
  /// display list until the camera has actually stopped.
  static const Duration worldRefreshDelay = Duration(milliseconds: 300);

  /// How much of a retained-scene build one frame may spend. The rest of the
  /// frame still paints the previous scene, so a large flatten cannot freeze
  /// the camera.
  static const Duration worldStepBudget = Duration(milliseconds: 8);

  /// A snapshot of the retained scene and cache state for diagnostics.
  RenderDiagnostics get diagnostics {
    final scene = _worldScene;
    final painter = _worldPainter;
    final blocks = _worldBuilder?.blockCache;
    final atlas = painter?.textAtlas;
    return RenderDiagnostics(
      retained: scene != null,
      sceneBuildTime: scene?.buildTime ?? Duration.zero,
      entityCount: scene?.entityCount ?? 0,
      segmentCount: scene?.segmentCount ?? 0,
      drawnSegments: painter?.lastDrawnSegments ?? 0,
      lineDrawCalls: painter?.lastLineDrawCalls ?? 0,
      blockCacheHits: blocks?.hits ?? 0,
      blockCacheMisses: blocks?.misses ?? 0,
      blockCacheEntries: blocks?.length ?? 0,
      blockCacheWeight: blocks?.weight ?? 0,
      textAtlasPages: atlas?.pageCount ?? 0,
      textAtlasRuns: atlas?.length ?? 0,
    );
  }

  /// Called when the settle timer ended a gesture and another frame would now
  /// build the exact picture. A notification, not a policy: the host only has
  /// to schedule a frame.
  void Function()? onNeedsPaint;

  /// Called after every rebuild, for the status bar's frame statistics.
  void Function(RenderScene scene)? onSceneBuilt;

  /// The last camera handed in, used to spot a zoom or a resize.
  CadViewport? _seen;

  /// True between a zoom/resize and the settle timer firing.
  bool _moving = false;

  Timer? _settle;

  /// The recording a zoom-out just outgrew, kept for a short fade so the
  /// geometry outside its coverage does not pop into view.
  RenderScene? _fadeScene;
  ui.Picture? _fadePicture;
  int _fadeStep = 0;
  Timer? _fadeTimer;

  /// About 130 ms at 60 Hz: long enough to read as a fade, short enough that
  /// the exact scene takes over before it looks like a different drawing.
  static const int fadeSteps = 8;
  static const Duration fadeTick = Duration(milliseconds: 16);

  /// Palette, fonts and SHX faces the picture is built with.
  ///
  /// Bound by the canvas rather than passed to the constructor because the
  /// renderer outlives it: theme and font changes recreate the builders, but
  /// the tessellation it shares with hit testing survives.
  void bindAppearance({
    required AciPalette palette,
    DrawingFontMap? fonts,
    ShxFontTable shxFonts = const ShxFontTable(),
  }) {
    _fonts = fonts ?? const DrawingFontMap();
    _shxFonts = shxFonts;
    _builder = SceneBuilder(
      palette: palette,
      cache: tessellation,
      paragraphs: paragraphs,
      fonts: _fonts,
      shxFonts: shxFonts,
    );
    _painter = ScenePainter(paragraphs: paragraphs);
    _worldBuilder = WorldSceneBuilder(
      palette: palette,
      cache: tessellation,
      fonts: _fonts,
      shxFonts: shxFonts,
    );
    _worldPainter?.onNeedsPaint = null;
    _worldPainter?.dispose();
    _worldPainter = WorldScenePainter(
      paragraphs: paragraphs,
      textPainter: _painter,
    )..onNeedsPaint = _scheduleAtlasStep;
    _worldScene = null;
    _worldVersion = -1;
    _worldRefreshPending = false;
    _worldBuildDue = false;
    _worldBuiltOnce = false;
    _worldJob = null;
    _worldRefreshTimer?.cancel();
    _worldRefreshTimer = null;
    _picker = null;
  }

  /// Hit testing over the same flattened geometry the canvas drew, so what is
  /// selectable is what is on screen.
  Picker get picker =>
      _picker ??= Picker(cache: tessellation, shxFonts: _shxFonts);

  /// The scene the last exact build produced, for hosts that report stats.
  DrawingCache get cache => _cache;

  /// Draws [target]. Safe to call every frame: an unchanged camera replays the
  /// recording instead of rebuilding.
  void render(ui.Canvas canvas, RenderTarget target) {
    final previous = _seen;
    _track(target.viewport);
    final moving = _moving;
    // Panning has exact replay and does not change the level of detail. Keep a
    // pending retained-scene build off the drag; it will run on the next
    // settled frame after the pan.
    final panning =
        previous != null &&
        previous.scale == target.viewport.scale &&
        previous.size == target.viewport.size &&
        previous.center != target.viewport.center;
    // Keep the retained world scene ready for the next gesture. A camera that
    // is already moving paints the scene it has; rebuilding here would put the
    // expensive flattening back on the gesture path.
    if (!moving && !panning) {
      _ensureWorld(target);
      _advanceWorld(target);
    }
    final world = _worldScene;
    // Past the detail the retained list was flattened for, its sub-pixel
    // geometry is already a point marker. Painting it under a much larger
    // camera is what turns a block of curve work into a field of dots. Serve
    // that frame from the camera-baked path instead, which culls to the
    // visible window and therefore rebuilds only what the deep zoom shows.
    if (world != null && !_worldDetailExceeded(world, target.viewport)) {
      // The retained list is the display, not a preview. Switching back to a
      // freshly aligned exact scene when a zoom stopped was the remaining
      // hitch and the sub-pixel shift at the end of the gesture.
      _worldPainter!.paint(
        canvas,
        world,
        target.viewport,
        textPixels: moving || panning
            ? WorldScenePainter.motionTextPixels
            : minimumEmittedTextPixels,
      );
      return;
    }
    final placement = _cache.placementFor(
      target.viewport,
      target.document.version,
      interactive: _moving,
    );
    if (_fadeScene != null) {
      // The fade follows the camera: a wheel that is still moving keeps the
      // revealed strip fading in rather than cutting the fade short.
      if (_cache.documentVersion == target.document.version &&
          placement != null) {
        _paintFade(canvas, target, placement);
        return;
      }
      _endFade();
    }
    if (placement != null) {
      _cache.replay(canvas, placement, target.viewport, _painter!);
      return;
    }

    final builder = _builder;
    final painter = _painter;
    if (builder == null || painter == null) {
      throw StateError('CanvasRenderer.bindAppearance was never called');
    }
    // A rebuild that reaches past the old coverage is a zoom-out (or a long
    // pan): the old recording has no geometry for the new border. Keep it for
    // one short fade so that strip appears smoothly instead of flashing in.
    final previousScene = _cache.scene;
    final previousPicture = _cache.picture;
    final previousVersion = _cache.documentVersion;
    final scene = builder.build(
      target.document,
      target.viewport,
      onlyLayers: target.onlyLayers,
      plotLayers: target.plotLayers,
      hiddenIds: target.hiddenIds.isEmpty ? null : target.hiddenIds.toSet(),
    );
    final recorded = painter.record(scene);
    final fade =
        previousScene != null &&
        previousPicture != null &&
        previousVersion == target.document.version &&
        !previousScene.covers(target.viewport);
    _cache.store(scene, recorded, target.document.version, keepPrevious: fade);
    if (fade) {
      _startFade(previousScene, previousPicture);
      _paintFade(canvas, target, scene.placementFor(target.viewport));
    } else {
      canvas.drawPicture(recorded);
    }
    onSceneBuilt?.call(scene);
  }

  /// How far past the detail a retained list stores before the camera-baked
  /// path takes over.
  ///
  /// [WorldSceneBuilder.previewDetail] is the point where real geometry ends
  /// and build-time point markers begin; waiting a little past it keeps a
  /// modest zoom from paying for an exact rebuild, while a marker is still
  /// under about three logical pixels. Beyond this, a collapsed curve would be
  /// a visible dot, which is exactly the artifact the exact path avoids.
  static const double _cameraBakedZoom = WorldSceneBuilder.previewDetail * 2;

  /// Whether a camera has zoomed past the detail the retained list stores.
  ///
  /// The list is flattened [WorldSceneBuilder.previewDetail] times finer than
  /// the camera it was built for, so a zoom-in up to that factor still has
  /// real curves and real small geometry. Past it, what the build collapsed to
  /// a point is no longer what the camera should show.
  static bool _worldDetailExceeded(WorldScene world, CadViewport viewport) =>
      viewport.scale > world.viewport.scale * _cameraBakedZoom;

  /// Far enough in that a whole-drawing rebuild no longer pays for itself.
  ///
  /// The camera-baked path culls to the visible window, so once the camera
  /// shows a small enough part of the drawing, that build is both cheaper and
  /// more exact than flattening every object at the new detail.
  static bool _worldVeryDeep({
    required WorldScene world,
    required CadViewport viewport,
  }) =>
      viewport.scale >
      world.viewport.scale * WorldSceneBuilder.previewDetail * 4;

  /// Builds the retained world display list when the document, layers or LOD
  /// has moved on.
  ///
  /// It is only called on a settled camera. During a zoom the previous scene is
  /// still drawn with the current matrix; because it covers the whole drawing,
  /// zooming out can never expose an empty border.
  void _ensureWorld(RenderTarget target) {
    final builder = _worldBuilder;
    if (builder == null || !retainWorld) {
      _worldScene = null;
      return;
    }
    // Paper-space composition and block editing still go through the camera-
    // baked pipeline until the retained scene learns those spaces.
    if (!target.document.activeLayout.isModelSpace ||
        target.document.isEditingBlock) {
      _worldScene = null;
      _worldVersion = -1;
      _worldJob = null;
      return;
    }
    final job = _worldJob;
    if (job != null) {
      final jobScale = job.reference.scale;
      final scale = target.viewport.scale;
      if (job.document.version == target.document.version &&
          scale <= jobScale * WorldSceneBuilder.previewDetail &&
          scale >= jobScale * WorldSceneBuilder.maxZoomOut) {
        return;
      }
      _worldJob = null;
      _worldBuildDue = false;
    }
    final scene = _worldScene;
    final sameInputs =
        _worldVersion == target.document.version &&
        _worldPlotLayers == target.plotLayers &&
        _sameLayers(_worldLayers, target.onlyLayers) &&
        _sameIds(_worldHiddenIds, target.hiddenIds);
    // The retained scene is flattened at four times the current detail, so it
    // stays usable through a zoom-in; rebuilding on every settle would add a
    // long pause without changing the picture. A zoom out of more than 2x is
    // the point where the extra detail starts costing more than it is worth.
    final scale = target.viewport.scale;
    final builtScale = scene?.viewport.scale ?? 0;
    final detailCurrent =
        scene != null &&
        scene.previewDetail == WorldSceneBuilder.previewDetail &&
        scale <= builtScale * WorldSceneBuilder.previewDetail &&
        scale >= builtScale * WorldSceneBuilder.maxZoomOut;
    if (sameInputs && detailCurrent) return;

    // Far past the retained detail, the camera-baked path is the display: it
    // culls to the visible window, while a world rebuild would flatten the
    // whole drawing for a view that is a fraction of it. Let the job wait
    // until the camera comes back within reach of the list it already has.
    if (scene != null &&
        _worldVeryDeep(world: scene, viewport: target.viewport)) {
      _worldJob = null;
      _worldBuildDue = false;
      _worldRefreshPending = false;
      _worldRefreshTimer?.cancel();
      _worldRefreshTimer = null;
      return;
    }

    // The first build waits for nothing; later builds (an edit, a layer
    // change, or a level-of-detail move) wait until the user has been idle for
    // a moment. The old scene still covers the whole drawing, so it can keep
    // painting during that wait.
    if (!_worldBuiltOnce) {
      _startWorldJob(target);
      return;
    }
    if (_worldBuildDue) {
      _worldBuildDue = false;
      _startWorldJob(target);
      return;
    }
    // A level-of-detail move is not an edit: nothing in the document changed,
    // so there is no reason to make the user wait out the refresh delay. Start
    // at once; the previous scene (or, past its detail, the camera-baked path)
    // keeps painting while the job is sliced across frames.
    if (sameInputs) {
      _startWorldJob(target);
      return;
    }
    _scheduleWorldRefresh();
  }

  void _startWorldJob(RenderTarget target) {
    final builder = _worldBuilder;
    if (builder == null) return;
    _worldJob = null;
    final job = builder.begin(
      target.document,
      target.viewport,
      onlyLayers: target.onlyLayers,
      plotLayers: target.plotLayers,
      hiddenIds: target.hiddenIds.isEmpty ? null : target.hiddenIds.toSet(),
    );
    if (job == null) {
      // An unfinishable first layout, an empty drawing or an unsupported space
      // must not make the renderer believe it has a retained scene.
      _worldBuiltOnce = false;
      _worldVersion = -1;
      _worldBuildDue = false;
      return;
    }
    _worldJob = job;
    _worldBuildDue = false;
  }

  /// Gives the current build a slice of this frame. The previous scene keeps
  /// painting until the job finishes.
  void _advanceWorld(RenderTarget target) {
    final job = _worldJob;
    if (job == null) return;
    if (job.document.version != target.document.version) {
      _worldJob = null;
      return;
    }
    final scene = job.step(worldStepBudget);
    if (scene == null) {
      _scheduleWorldStep();
      return;
    }
    _worldScene = scene;
    _worldVersion = job.document.version;
    _worldLayers = target.onlyLayers == null ? null : {...target.onlyLayers!};
    _worldPlotLayers = target.plotLayers;
    _worldHiddenIds = [...target.hiddenIds];
    _worldBuiltOnce = true;
    _worldBuildDue = false;
    _worldJob = null;
    onSceneBuilt?.call(scene.statsFor(target.viewport));
  }

  void _scheduleWorldStep() {
    if (_worldStepScheduled) return;
    _worldStepScheduled = true;
    scheduleMicrotask(() {
      _worldStepScheduled = false;
      onNeedsPaint?.call();
    });
  }

  /// The text atlas renders one page per frame, so a freshly warmed sheet
  /// converges over a few frames instead of pausing in the first one.
  void _scheduleAtlasStep() {
    if (_atlasStepScheduled) return;
    _atlasStepScheduled = true;
    scheduleMicrotask(() {
      _atlasStepScheduled = false;
      onNeedsPaint?.call();
    });
  }

  void _scheduleWorldRefresh() {
    if (_worldRefreshPending || _worldBuildDue) return;
    _worldRefreshPending = true;
    _worldRefreshTimer?.cancel();
    _worldRefreshTimer = Timer(worldRefreshDelay, () {
      _worldRefreshTimer = null;
      _worldRefreshPending = false;
      _worldBuildDue = true;
      onNeedsPaint?.call();
    });
  }

  /// Starts the short cross-fade from [scene] to the recording just stored.
  void _startFade(RenderScene scene, ui.Picture picture) {
    _endFade();
    _fadeScene = scene;
    _fadePicture = picture;
    _fadeStep = 0;
    _fadeTimer = Timer.periodic(fadeTick, (_) {
      _fadeStep++;
      if (_fadeStep >= fadeSteps) _endFade();
      onNeedsPaint?.call();
    });
  }

  void _endFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fadePicture?.dispose();
    _fadePicture = null;
    _fadeScene = null;
    _fadeStep = 0;
  }

  /// Paints the old recording, then fades the new one in over the strip the old
  /// coverage did not include.
  ///
  /// Geometry inside the old coverage is already identical on both recordings,
  /// so it is left alone. Clipping to the difference also keeps a faded copy of
  /// a line from being painted on top of the same line, which would darken
  /// every edge for the length of the fade.
  void _paintFade(
    ui.Canvas canvas,
    RenderTarget target,
    ScenePlacement placement,
  ) {
    final previousScene = _fadeScene;
    final previousPicture = _fadePicture;
    final painter = _painter;
    if (previousScene == null || previousPicture == null || painter == null) {
      _endFade();
      return;
    }
    DrawingCache.replayStored(
      canvas,
      previousScene,
      previousPicture,
      previousScene.placementFor(target.viewport),
      target.viewport,
      painter,
    );
    final progress = _fadeStep / fadeSteps;
    if (progress <= 0) return;
    final covered = _coverageOnScreen(previousScene, target.viewport);
    canvas.save();
    if (covered != null) {
      canvas.clipRect(covered, clipOp: ui.ClipOp.difference);
    }
    canvas.saveLayer(
      ui.Offset.zero & target.viewport.size,
      ui.Paint()
        ..color = ui.Color.fromARGB((progress * 255).round(), 255, 255, 255),
    );
    _cache.replay(canvas, placement, target.viewport, painter);
    canvas.restore();
    canvas.restore();
  }

  /// [scene]'s coverage as a rect in the logical pixels of [viewport].
  static ui.Rect? _coverageOnScreen(RenderScene scene, CadViewport viewport) {
    final coverage = scene.coverage;
    if (coverage.isEmpty || !viewport.isUsable) return null;
    return ui.Rect.fromPoints(
      viewport.toScreen(Vec2(coverage.minX, coverage.maxY)),
      viewport.toScreen(Vec2(coverage.maxX, coverage.minY)),
    );
  }

  /// Drops the recording after a change the camera cannot explain.
  void invalidate() {
    _cache.invalidate();
    _worldScene = null;
    _worldVersion = -1;
    _worldBuiltOnce = true;
    _worldJob = null;
    _seen = null;
    cancelSettle();
    _scheduleWorldRefresh();
  }

  /// Cancels a pending settle frame without dropping the recording.
  ///
  /// A canvas that leaves the tree no longer needs the exact rebuild the timer
  /// would request. The next render re-arms it if the camera changed again.
  void cancelSettle() {
    _settle?.cancel();
    _settle = null;
    _moving = false;
    _endFade();
    _worldRefreshTimer?.cancel();
    _worldRefreshTimer = null;
    _worldRefreshPending = false;
    _worldBuildDue = false;
  }

  void dispose() {
    cancelSettle();
    _worldPainter?.onNeedsPaint = null;
    _worldPainter?.dispose();
    _atlasStepScheduled = false;
    _worldJob = null;
    _worldRefreshTimer?.cancel();
    _worldRefreshTimer = null;
    onNeedsPaint = null;
    onSceneBuilt = null;
    _cache.dispose();
  }

  static bool _sameLayers(Set<String>? a, Set<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static bool _sameIds(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Arms the settle timer when the camera changed in a way only an exact
  /// build can resolve.
  ///
  /// A pan is not one of them: replaying the recording displaced by whole
  /// pixels is the same image a rebuild would produce, so a pan settles
  /// without ever building. Zoom and resize are, because the recording's
  /// curve tessellation and pixel alignment belong to the scale it was built
  /// at.
  void _track(CadViewport viewport) {
    final seen = _seen;
    _seen = viewport;
    if (seen == null) return;
    if (seen.scale == viewport.scale && seen.size == viewport.size) return;
    _moving = true;
    _settle?.cancel();
    _settle = Timer(settleDelay, _onSettled);
  }

  void _onSettled() {
    _settle = null;
    if (!_moving) return;
    final viewport = _seen;
    if (viewport != null && viewport.pixelLocked() != viewport) {
      // A resize is still waiting to re-lock the camera. Building now would
      // align the picture to a grid the window is about to leave.
      _settle = Timer(settleDelay, _onSettled);
      return;
    }
    _moving = false;
    onNeedsPaint?.call();
  }
}
