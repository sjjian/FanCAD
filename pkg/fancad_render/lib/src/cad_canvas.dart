import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'overlay.dart';
import 'palette.dart';
import 'scene.dart';
import 'scene_painter.dart';
import 'tessellation_cache.dart';
import 'text_cache.dart';
import 'viewport.dart';
import 'viewport_controller.dart';

/// Pointer and keyboard events, in drawing coordinates.
///
/// Tools implement this instead of touching Flutter gesture APIs, so a tool can
/// be driven from a script or a test with no widget tree at all.
abstract class CanvasInputHandler {
  /// Returns true if the tool consumed the event.
  bool onPointerDown(Vec2 world, PointerDownEvent event) => false;
  bool onPointerMove(Vec2 world, PointerEvent event) => false;
  bool onPointerUp(Vec2 world, PointerUpEvent event) => false;
  void onPointerExit() {}
}

/// The drawing viewport.
///
/// Two painted layers with different repaint rates. The lower one holds the
/// drawing and only rebuilds when the document or the camera changes; the upper
/// one holds selection, grips and previews and repaints on every mouse move.
/// Keeping them apart is what makes a rubber-band line over a 200,000 entity
/// drawing cost the same as over an empty one.
class CadCanvas extends StatefulWidget {
  const CadCanvas({
    required this.document,
    required this.controller,
    this.overlay = OverlayModel.empty,
    this.inputHandler,
    this.palette,
    this.overlayTheme = const OverlayTheme(),
    this.background = const Color(0xFF1B1D21),
    this.onSceneBuilt,
    this.onContextMenu,
    this.onDoubleClick,
    this.showGrid = true,
    this.onlyLayers,
    super.key,
  });

  final CadDocument document;
  final ViewportController controller;
  final OverlayModel overlay;
  final CanvasInputHandler? inputHandler;
  final AciPalette? palette;
  final OverlayTheme overlayTheme;
  final Color background;

  /// Called after each scene build, for the status bar's frame statistics.
  final void Function(RenderScene scene)? onSceneBuilt;

  /// A right-click that did not become a pan. The shell owns the menu.
  final void Function(Offset localPosition)? onContextMenu;

  /// A primary-button double-click. The shell uses this to zoom extents.
  final void Function(Offset localPosition)? onDoubleClick;

  final bool showGrid;

  /// When set, only these layers are drawn. Used by the layer isolation command.
  final Set<String>? onlyLayers;

  @override
  State<CadCanvas> createState() => CadCanvasState();
}

class CadCanvasState extends State<CadCanvas> {
  late final AciPalette _palette =
      widget.palette ?? AciPalette(background: widget.background);
  late final SceneBuilder _sceneBuilder = SceneBuilder(
    palette: _palette,
    cache: _tessellation,
  );
  final TessellationCache _tessellation = TessellationCache();
  final ScenePainter _scenePainter = ScenePainter(paragraphs: ParagraphCache());
  late final OverlayPainter _overlayPainter = OverlayPainter(
    theme: widget.overlayTheme,
  );

  final _SceneHolder _holder = _SceneHolder();

  /// Set while a mouse-button pan is in flight (middle, right, or space+left).
  int? _panPointer;
  Offset _lastPanPosition = Offset.zero;
  Offset _panStart = Offset.zero;
  bool _panDragging = false;
  bool _panIsSecondary = false;

  /// Pixels before a right-button press becomes a pan. Below this, release
  /// is a context-menu click — otherwise a two-finger tap on a Mac never
  /// gets to open a menu.
  static const _panSlop = 4.0;

  DateTime? _lastPrimaryUpAt;
  Offset? _lastPrimaryUpPos;
  bool _primaryDown = false;

  static const _doubleClickWindow = Duration(milliseconds: 400);
  static const _doubleClickSlop = 6.0;

  /// Trackpad two-finger / pinch gesture. On macOS these arrive as
  /// [PointerPanZoomEvent]s, not [PointerScrollEvent]s — which is why a
  /// wheel-only handler looks like "the canvas cannot zoom".
  int? _trackpadPointer;
  double _lastTrackpadScale = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onViewportChanged);
  }

  @override
  void didUpdateWidget(CadCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onViewportChanged);
      widget.controller.addListener(_onViewportChanged);
    }
    if (oldWidget.document != widget.document) {
      _tessellation.clear();
      _holder.invalidate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onViewportChanged);
    super.dispose();
  }

  void _onViewportChanged() => setState(() {});

  /// Drops cached geometry for entities that changed. Called by the shell when
  /// the document reports a change.
  void applyDocumentChange(DocumentChange change) {
    if (change.requiresFullRegeneration) {
      _tessellation.clear();
    } else {
      _tessellation.invalidate([
        ...change.modified,
        ...change.removed,
        ...change.added,
      ]);
    }
    _holder.invalidate();
    if (mounted) setState(() {});
  }

  Vec2 _toWorld(Offset local) => widget.controller.viewport.toWorld(local);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final ratio = MediaQuery.devicePixelRatioOf(context);
        // Reporting the size during layout would mutate state mid-build, so it
        // is deferred by one frame. The first frame paints an empty viewport.
        if (size != widget.controller.viewport.size ||
            ratio != widget.controller.viewport.devicePixelRatio) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.controller.setSize(size, ratio);
          });
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerHover: _handlePointerHover,
          onPointerSignal: _handlePointerSignal,
          onPointerPanZoomStart: _handlePanZoomStart,
          onPointerPanZoomUpdate: _handlePanZoomUpdate,
          onPointerPanZoomEnd: _handlePanZoomEnd,
          onPointerCancel: (_) => _endAllGestures(),
          child: MouseRegion(
            cursor: _panDragging || _trackpadPointer != null
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.precise,
            onExit: (_) => widget.inputHandler?.onPointerExit(),
            child: ColoredBox(
              color: widget.background,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _DrawingLayerPainter(
                        document: widget.document,
                        documentVersion: widget.document.version,
                        viewport: widget.controller.viewport,
                        builder: _sceneBuilder,
                        painter: _scenePainter,
                        holder: _holder,
                        onlyLayers: widget.onlyLayers,
                        onSceneBuilt: widget.onSceneBuilt,
                        grid: widget.showGrid
                            ? _GridStyle(
                                color: widget.background,
                                palette: _palette,
                              )
                            : null,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _OverlayLayerPainter(
                        document: widget.document,
                        viewport: widget.controller.viewport,
                        model: widget.overlay,
                        painter: _overlayPainter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isPanButton(event)) {
      _panPointer = event.pointer;
      _lastPanPosition = event.localPosition;
      _panStart = event.localPosition;
      _panDragging = false;
      _panIsSecondary = event.buttons & kSecondaryMouseButton != 0;
      return;
    }
    if (event.buttons & kPrimaryMouseButton != 0 && _isDoubleClick(event)) {
      _lastPrimaryUpAt = null;
      _lastPrimaryUpPos = null;
      _primaryDown = false;
      widget.onDoubleClick?.call(event.localPosition);
      return;
    }
    _primaryDown = event.buttons & kPrimaryMouseButton != 0;
    widget.inputHandler?.onPointerDown(_toWorld(event.localPosition), event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_panPointer == event.pointer) {
      if (!_panDragging) {
        if ((event.localPosition - _panStart).distance < _panSlop) return;
        _panDragging = true;
        widget.controller.beginInteraction();
      }
      widget.controller.panBy(event.localPosition - _lastPanPosition);
      _lastPanPosition = event.localPosition;
      return;
    }
    widget.inputHandler?.onPointerMove(_toWorld(event.localPosition), event);
  }

  void _handlePointerHover(PointerHoverEvent event) {
    widget.inputHandler?.onPointerMove(_toWorld(event.localPosition), event);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_panPointer == event.pointer) {
      final openMenu = _panIsSecondary && !_panDragging;
      final menuAt = event.localPosition;
      _endPan();
      if (openMenu) widget.onContextMenu?.call(menuAt);
      return;
    }
    if (_primaryDown) {
      _lastPrimaryUpAt = DateTime.now();
      _lastPrimaryUpPos = event.localPosition;
      _primaryDown = false;
    }
    widget.inputHandler?.onPointerUp(_toWorld(event.localPosition), event);
  }

  bool _isDoubleClick(PointerDownEvent event) {
    final at = _lastPrimaryUpAt;
    final pos = _lastPrimaryUpPos;
    if (at == null || pos == null) return false;
    return DateTime.now().difference(at) <= _doubleClickWindow &&
        (event.localPosition - pos).distance <= _doubleClickSlop;
  }

  void _endPan() {
    if (_panPointer == null) return;
    final wasDragging = _panDragging;
    _panPointer = null;
    _panDragging = false;
    _panIsSecondary = false;
    if (wasDragging) widget.controller.endInteraction();
  }

  void _endTrackpad() {
    if (_trackpadPointer == null) return;
    _trackpadPointer = null;
    _lastTrackpadScale = 1;
    widget.controller.endInteraction();
  }

  void _endAllGestures() {
    _endPan();
    _endTrackpad();
  }

  /// Middle button is the CAD default; right-drag and space+left cover a
  /// Mac trackpad, which has no middle button.
  bool _isPanButton(PointerEvent event) {
    if (event.buttons & kMiddleMouseButton != 0) return true;
    if (event.buttons & kSecondaryMouseButton != 0) return true;
    return event.buttons & kPrimaryMouseButton != 0 && _spaceHeld;
  }

  bool get _spaceHeld => HardwareKeyboard.instance.logicalKeysPressed.contains(
    LogicalKeyboardKey.space,
  );

  bool get _zoomModifierHeld =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // A notch of the wheel is one zoom step, anchored at the cursor. The
    // exponent keeps the step proportional so zooming feels the same at every
    // scale.
    final steps = -event.scrollDelta.dy / 120;
    if (steps == 0) return;
    widget.controller.zoomBy(_zoomStep(steps), event.localPosition);
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadPointer = event.pointer;
    _lastTrackpadScale = 1;
    widget.controller.beginInteraction();
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (_trackpadPointer != event.pointer) return;
    final scale = event.scale;
    if (scale > 0 && scale != _lastTrackpadScale) {
      widget.controller.zoomBy(scale / _lastTrackpadScale, event.localPosition);
      _lastTrackpadScale = scale;
    }
    final delta = event.localPanDelta;
    if (delta == Offset.zero) return;
    // Two-finger drag pans. Cmd/Ctrl + scroll still zooms, matching a
    // mouse wheel, for people who never pinch.
    if (_zoomModifierHeld && scale == _lastTrackpadScale) {
      final steps = -delta.dy / 40;
      if (steps != 0) {
        widget.controller.zoomBy(_zoomStep(steps), event.localPosition);
      }
      return;
    }
    widget.controller.panBy(delta);
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    if (_trackpadPointer != event.pointer) return;
    _endTrackpad();
  }

  static double _zoomStep(double steps) {
    const perNotch = 1.2;
    var factor = 1.0;
    var remaining = steps;
    while (remaining >= 1) {
      factor *= perNotch;
      remaining -= 1;
    }
    while (remaining <= -1) {
      factor /= perNotch;
      remaining += 1;
    }
    // Trackpads report fractional notches, so interpolate the remainder.
    if (remaining != 0) {
      factor *= 1 + (perNotch - 1) * remaining;
    }
    return factor;
  }
}

/// Holds the last built scene so a pan can reuse it.
class _SceneHolder {
  RenderScene? scene;
  ui.Picture? picture;

  void invalidate() {
    scene = null;
    picture?.dispose();
    picture = null;
  }

  void store(RenderScene value, ui.Picture recorded) {
    picture?.dispose();
    scene = value;
    picture = recorded;
  }
}

class _GridStyle {
  const _GridStyle({required this.color, required this.palette});

  final Color color;
  final AciPalette palette;
}

class _DrawingLayerPainter extends CustomPainter {
  _DrawingLayerPainter({
    required this.document,
    required this.documentVersion,
    required this.viewport,
    required this.builder,
    required this.painter,
    required this.holder,
    required this.onlyLayers,
    required this.onSceneBuilt,
    required this.grid,
  });

  final CadDocument document;

  /// Captured rather than read from [document], so that a change is visible to
  /// `shouldRepaint`, which is handed the same mutable document instance.
  final int documentVersion;

  final CadViewport viewport;
  final SceneBuilder builder;
  final ScenePainter painter;
  final _SceneHolder holder;
  final Set<String>? onlyLayers;
  final void Function(RenderScene scene)? onSceneBuilt;
  final _GridStyle? grid;

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (grid != null) _paintGrid(canvas, size);

    final cached = holder.scene;
    final picture = holder.picture;
    if (cached != null && picture != null && cached.canReuseFor(viewport)) {
      // The scene was built in the screen space of a viewport at the same zoom,
      // so a translation is an exact re-projection rather than an approximation.
      final delta = cached.translationFor(viewport);
      canvas
        ..save()
        ..translate(delta.dx, delta.dy)
        ..drawPicture(picture)
        ..restore();
      return;
    }

    final scene = builder.build(document, viewport, onlyLayers: onlyLayers);
    final recorded = painter.record(scene);
    holder.store(scene, recorded);
    canvas.drawPicture(recorded);
    onSceneBuilt?.call(scene);
  }

  /// A reference grid, spaced at a round number of drawing units.
  ///
  /// Two densities: a fine grid and a bolder one every ten lines, which is what
  /// makes it readable as a measuring aid rather than as wallpaper.
  void _paintGrid(ui.Canvas canvas, Size size) {
    if (!viewport.isUsable) return;
    final style = grid!;
    // Aim for roughly one line every 12 pixels, snapped to a 1, 2, 5 sequence.
    final target = viewport.pixelsToWorld(12);
    final magnitude = _niceStep(target);
    final minorPixels = magnitude * viewport.scale;
    if (minorPixels < 4) return;

    final visible = viewport.visibleBounds;
    final foreground = style.palette.foreground;
    final minor = Paint()
      ..color = foreground.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = foreground.withValues(alpha: 0.11)
      ..strokeWidth = 1;

    final startX = (visible.minX / magnitude).floor();
    final endX = (visible.maxX / magnitude).ceil();
    for (var i = startX; i <= endX; i++) {
      final x = viewport.toScreen(Vec2(i * magnitude, 0)).dx;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 10 == 0 ? major : minor,
      );
    }
    final startY = (visible.minY / magnitude).floor();
    final endY = (visible.maxY / magnitude).ceil();
    for (var i = startY; i <= endY; i++) {
      final y = viewport.toScreen(Vec2(0, i * magnitude)).dy;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 10 == 0 ? major : minor,
      );
    }

    // The drawing origin, which is worth being able to find.
    final origin = viewport.toScreen(const Vec2.zero());
    if (origin.dx >= -20 &&
        origin.dx <= size.width + 20 &&
        origin.dy >= -20 &&
        origin.dy <= size.height + 20) {
      final axis = Paint()
        ..color = foreground.withValues(alpha: 0.22)
        ..strokeWidth = 1;
      canvas
        ..drawLine(Offset(0, origin.dy), Offset(size.width, origin.dy), axis)
        ..drawLine(Offset(origin.dx, 0), Offset(origin.dx, size.height), axis);
    }
  }

  /// The smallest 1, 2 or 5 times a power of ten that is at least [value].
  ///
  /// Grid spacing has to be a number a person can do arithmetic with, which is
  /// why it snaps to this sequence rather than to the raw pixel target.
  static double _niceStep(double value) {
    if (!value.isFinite || value <= 0) return 1;
    final exponent = (math.log(value) / math.ln10).floor();
    final decade = math.pow(10, exponent).toDouble();
    for (final multiple in const [1.0, 2.0, 5.0]) {
      if (decade * multiple >= value) return decade * multiple;
    }
    return decade * 10;
  }

  @override
  bool shouldRepaint(_DrawingLayerPainter old) =>
      old.document != document ||
      old.documentVersion != documentVersion ||
      old.viewport != viewport ||
      old.onlyLayers != onlyLayers;
}

class _OverlayLayerPainter extends CustomPainter {
  _OverlayLayerPainter({
    required this.document,
    required this.viewport,
    required this.model,
    required this.painter,
  });

  final CadDocument document;
  final CadViewport viewport;
  final OverlayModel model;
  final OverlayPainter painter;

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (model.isEmpty) return;
    painter.paint(canvas, model, viewport, document);
  }

  @override
  bool shouldRepaint(_OverlayLayerPainter old) =>
      old.model != model || old.viewport != viewport;
}
