import 'dart:async';
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

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
  CanvasRenderer({TessellationCache? tessellation, ParagraphCache? paragraphs})
    : tessellation = tessellation ?? TessellationCache(),
      paragraphs = paragraphs ?? ParagraphCache();

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
    _track(target.viewport);
    final placement = _cache.placementFor(
      target.viewport,
      target.document.version,
      interactive: _moving,
    );
    if (placement != null) {
      _cache.replay(canvas, placement, target.viewport, _painter!);
      return;
    }

    final builder = _builder;
    final painter = _painter;
    if (builder == null || painter == null) {
      throw StateError('CanvasRenderer.bindAppearance was never called');
    }
    final scene = builder.build(
      target.document,
      target.viewport,
      onlyLayers: target.onlyLayers,
      plotLayers: target.plotLayers,
      hiddenIds: target.hiddenIds.isEmpty ? null : target.hiddenIds.toSet(),
    );
    final recorded = painter.record(scene);
    _cache.store(scene, recorded, target.document.version);
    canvas.drawPicture(recorded);
    onSceneBuilt?.call(scene);
  }

  /// Drops the recording after a change the camera cannot explain.
  void invalidate() {
    _cache.invalidate();
    _seen = null;
    _moving = false;
    _settle?.cancel();
    _settle = null;
  }

  void dispose() {
    _settle?.cancel();
    _settle = null;
    onNeedsPaint = null;
    onSceneBuilt = null;
    _cache.dispose();
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
