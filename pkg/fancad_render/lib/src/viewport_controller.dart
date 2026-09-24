import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/foundation.dart';

import 'viewport.dart';

/// How much work the renderer should do for the current camera.
enum RenderQuality {
  /// The camera is moving. Reuse the last recording, translated or scaled.
  /// Constant cost regardless of drawing size, and it leaves the linework
  /// following the geometry instead of being realigned mid-gesture.
  interactive,

  /// The camera has settled. Rebuild the scene and align it to the pixel grid.
  crisp,
}

/// Owns the camera for one document tab.
///
/// A separate notifier from the document itself, because panning must not mark
/// a drawing dirty and must not invalidate anything that depends on document
/// content.
class ViewportController extends ChangeNotifier {
  ViewportController({CadViewport? initial})
    : _viewport =
          (initial ??
                  const CadViewport(
                    center: Vec2.zero(),
                    scale: 1,
                    size: Size.zero,
                  ))
              .pixelLocked();

  /// How long after the last camera move the view counts as settled.
  ///
  /// A pan or a pinch reports its own end, but a mouse wheel does not: there is
  /// no event that says the notches have stopped. This delay stands in for the
  /// missing gesture end, so a wheel spin reuses the recording like a pinch
  /// does instead of rebuilding once per notch.
  static const Duration settleDelay = Duration(milliseconds: 90);

  CadViewport _viewport;

  /// Last snapped pointer, published by the canvas. Status readouts listen
  /// here so a mouse move does not write a store or rebuild the page.
  Vec2? _pointer;

  /// Set while a pan or zoom gesture is in flight, so the renderer can prefer
  /// reusing the last scene over building an exact one.
  bool _interacting = false;

  RenderQuality _quality = RenderQuality.crisp;
  Timer? _settle;

  /// Viewport as it was when the current pan/pinch began, so Escape can put
  /// the camera back.
  CadViewport? _interactionOrigin;

  /// Pending fit request, applied once the widget reports a real size.
  Bounds2? _pendingFit;
  double _pendingInsetLeft = 0;
  double _pendingInsetRight = 0;

  /// Canvas top-left in the window, from the last layout that reported one.
  ///
  /// A splitter drag moves this origin, the widget size, or both. The next
  /// [setSize] shifts [CadViewport.center] so a drawing point keeps the screen
  /// pixel it already occupied.
  Offset? _screenOrigin;

  CadViewport get viewport => _viewport;
  Vec2? get pointer => _pointer;
  bool get isInteracting => _interacting;

  /// Records the snapped pointer. Identical points do not notify.
  void notePointer(Vec2? world) {
    if (world == _pointer) return;
    _pointer = world;
    notifyListeners();
  }

  RenderQuality get quality => _quality;

  /// Every camera this controller hands out is [CadViewport.pixelLocked], so
  /// the renderer's alignment survives a pan and the cursor agrees with the
  /// pixels a line was drawn on.
  set viewport(CadViewport value) {
    final locked = value.pixelLocked();
    if (locked == _viewport) return;
    _viewport = locked;
    notifyListeners();
  }

  /// Called by the canvas on layout. Applies a deferred fit if one is queued.
  ///
  /// [screenOrigin] is the canvas top-left in the window. When the previous
  /// layout reported one too, the centre moves with the widget so the drawing
  /// stays still on screen while the window is resized. Omit it and the
  /// centre stays put, which is what tests and the first layout do.
  ///
  /// A resize that does anchor the drawing is interactive until
  /// [settleDelay] elapses. Pixel locking waits for that settle, so the
  /// resize does not snap the recording onto a new pixel grid every frame.
  void setSize(Size size, double devicePixelRatio, {Offset? screenOrigin}) {
    final previousOrigin = _screenOrigin;
    final previousSize = _viewport.size;
    if (screenOrigin != null) _screenOrigin = screenOrigin;
    if (size == previousSize &&
        devicePixelRatio == _viewport.devicePixelRatio) {
      return;
    }
    final pending = _pendingFit;
    final fitting = pending != null && !size.isEmpty;
    if (fitting) _pendingFit = null;
    final insetLeft = _pendingInsetLeft;
    final insetRight = _pendingInsetRight;
    final anchor =
        !fitting &&
        screenOrigin != null &&
        previousOrigin != null &&
        _viewport.isUsable;
    var next = fitting
        ? _frame(
            pending,
            size,
            devicePixelRatio: devicePixelRatio,
            insetLeft: insetLeft,
            insetRight: insetRight,
          )
        : _viewport.copyWith(size: size, devicePixelRatio: devicePixelRatio);
    if (anchor) {
      final dLeft = screenOrigin.dx - previousOrigin.dx;
      final dTop = screenOrigin.dy - previousOrigin.dy;
      final dWidth = size.width - previousSize.width;
      final dHeight = size.height - previousSize.height;
      final scale = _viewport.scale;
      next = next.copyWith(
        center: Vec2(
          _viewport.center.x + (dLeft + dWidth / 2) / scale,
          _viewport.center.y - (dTop + dHeight / 2) / scale,
        ),
      );
    }
    if (anchor) {
      _viewport = next;
      _quality = RenderQuality.interactive;
      _settle?.cancel();
      _settle = Timer(settleDelay, _onResizeSettled);
      notifyListeners();
      return;
    }
    // A new size or ratio moves the screen origin, so the lock is reapplied
    // even though the centre did not change.
    _viewport = next.pixelLocked();
    notifyListeners();
  }

  void beginInteraction() {
    if (_interacting) return;
    _interacting = true;
    _interactionOrigin = _viewport;
    _quality = RenderQuality.interactive;
    _settle?.cancel();
    _settle = null;
    notifyListeners();
  }

  void endInteraction() {
    if (!_interacting) return;
    _interacting = false;
    _interactionOrigin = null;
    _settleNow();
    notifyListeners();
  }

  /// Moves the camera, marks it as moving, and arms the settle timer, as one
  /// write and one notification.
  ///
  /// The camera and the quality have to move together. A zoom clamped at
  /// [CadViewport.minScale] or [CadViewport.maxScale] leaves the camera where
  /// it was, so writing the quality separately would drop the renderer onto
  /// the cached recording with nothing to tell it, and it would stay there
  /// until the settle timer happened to fire.
  ///
  /// A gesture reports its own end, so while one is in flight there is nothing
  /// to time. A wheel notch has no end, which is what the timer is for.
  void _moveTo(CadViewport next) {
    final locked = next.pixelLocked();
    if (locked == _viewport) return;
    _viewport = locked;
    _quality = RenderQuality.interactive;
    _settle?.cancel();
    _settle = _interacting ? null : Timer(settleDelay, _onSettled);
    notifyListeners();
  }

  void _onSettled() {
    _settle = null;
    if (_quality == RenderQuality.crisp) return;
    _quality = RenderQuality.crisp;
    notifyListeners();
  }

  /// Ends a resize: lock the camera once, then rebuild at the settled size.
  void _onResizeSettled() {
    _settle = null;
    _viewport = _viewport.pixelLocked();
    _quality = RenderQuality.crisp;
    notifyListeners();
  }

  void _settleNow() {
    _settle?.cancel();
    _settle = null;
    _quality = RenderQuality.crisp;
  }

  /// Restores the camera from the start of the current pan or pinch.
  ///
  /// Returns true only when the camera actually moved. A two-finger rest that
  /// never panned must not consume Escape — that key still has to cancel a
  /// command or the selection.
  bool revertInteraction() {
    if (!_interacting) return false;
    final origin = _interactionOrigin;
    _interacting = false;
    _interactionOrigin = null;
    _settleNow();
    final changed = origin != null && origin != _viewport;
    if (changed) {
      _viewport = origin;
    }
    notifyListeners();
    return changed;
  }

  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) return;
    _moveTo(_viewport.panned(screenDelta));
  }

  void zoomBy(double factor, Offset anchor) =>
      _moveTo(_viewport.zoomed(factor, anchor));

  void zoomAtCenter(double factor) => _moveTo(_viewport.zoomedAtCenter(factor));

  void zoomIn() => zoomAtCenter(1.25);
  void zoomOut() => zoomAtCenter(0.8);

  /// Frames [bounds]. Defers until the widget has a size, so this can be
  /// called immediately after opening a file.
  ///
  /// [insetLeft] and [insetRight] are the panes covering the widget. The fit
  /// uses the uncovered interval, then the centre is shifted so that interval
  /// holds the drawing. The widget size stays the full canvas.
  void zoomTo(
    Bounds2 bounds, {
    double margin = 0.06,
    double insetLeft = 0,
    double insetRight = 0,
  }) {
    if (bounds.isEmpty || !bounds.isFinite) return;
    if (_viewport.size.isEmpty) {
      _pendingFit = bounds;
      _pendingInsetLeft = insetLeft;
      _pendingInsetRight = insetRight;
      return;
    }
    viewport = _frame(
      bounds,
      _viewport.size,
      margin: margin,
      devicePixelRatio: _viewport.devicePixelRatio,
      insetLeft: insetLeft,
      insetRight: insetRight,
    );
  }

  CadViewport _frame(
    Bounds2 bounds,
    Size size, {
    double margin = 0.06,
    required double devicePixelRatio,
    double insetLeft = 0,
    double insetRight = 0,
  }) {
    final left = insetLeft.clamp(0, size.width).toDouble();
    final right = insetRight
        .clamp(0, math.max(0, size.width - left))
        .toDouble();
    final hole = Size(math.max(size.width - left - right, 1), size.height);
    final fitted = CadViewport.fit(
      bounds,
      hole,
      margin: margin,
      devicePixelRatio: devicePixelRatio,
    );
    final shift = (left - right) / (2 * fitted.scale);
    return fitted.copyWith(
      size: size,
      center: Vec2(fitted.center.x - shift, fitted.center.y),
    );
  }

  /// Frames the whole drawing.
  void zoomToExtents(
    CadDocument document, {
    double insetLeft = 0,
    double insetRight = 0,
  }) {
    final extents = document.extents;
    if (extents.isEmpty) {
      // An empty drawing still needs a sensible working scale rather than an
      // arbitrary one, so show a 200 unit wide area around the origin.
      zoomTo(
        const Bounds2(-100, -100, 100, 100),
        insetLeft: insetLeft,
        insetRight: insetRight,
      );
      return;
    }
    zoomTo(extents, insetLeft: insetLeft, insetRight: insetRight);
  }

  /// Centres on a drawing point without changing zoom.
  void centerOn(Vec2 point) => viewport = _viewport.copyWith(center: point);

  @override
  void dispose() {
    _settle?.cancel();
    _settle = null;
    super.dispose();
  }
}
