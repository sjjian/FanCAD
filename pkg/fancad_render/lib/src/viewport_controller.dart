import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/foundation.dart';

import 'viewport.dart';

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
  /// Used only to re-lock the camera to the pixel grid after a splitter drag:
  /// the camera itself is the controller's business, and a resize shifts it by
  /// sub-pixel amounts that should not be rounded back in on every event. How
  /// long a moving camera may keep the renderer on its recording is decided by
  /// the renderer, from the same duration.
  static const Duration settleDelay = cameraSettleDelay;

  CadViewport _viewport;

  /// Last snapped pointer, published by the canvas. Status readouts listen
  /// here so a mouse move does not write a store or rebuild the page.
  Vec2? _pointer;

  /// Set while a pan or zoom gesture is in flight, so a command can tell a
  /// drag from a click. Purely input bookkeeping: the renderer never sees it.
  bool _interacting = false;

  Timer? _settle;

  /// Viewport as it was when the current pan/pinch began, so Escape can put
  /// the camera back.
  CadViewport? _interactionOrigin;

  /// Layout camera saved when block editing starts. Closing the block puts
  /// this back, so the drawing keeps the zoom and position it had. A second
  /// save is ignored: switching from one block to another must not replace
  /// the layout view with the block view.
  CadViewport? _heldView;

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
  /// A resize that does anchor the drawing leaves the camera a sub-pixel
  /// amount off the grid until [settleDelay] elapses. Rounding every layout
  /// would feed that rounding back into the next delta and let a splitter drag
  /// creep, so the lock is taken once, after the resize stops.
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
      _settle?.cancel();
      _settle = Timer(settleDelay, _lockAfterResize);
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
    notifyListeners();
  }

  void endInteraction() {
    if (!_interacting) return;
    _interacting = false;
    _interactionOrigin = null;
    notifyListeners();
  }

  /// Moves the camera to [next] and publishes it.
  void _moveTo(CadViewport next) {
    final locked = next.pixelLocked();
    if (locked == _viewport) return;
    _viewport = locked;
    notifyListeners();
  }

  /// Ends a resize: lock the camera once, so the next rebuild aligns to the
  /// pixel grid the window finally landed on.
  void _lockAfterResize() {
    _settle = null;
    final locked = _viewport.pixelLocked();
    if (locked == _viewport) return;
    _viewport = locked;
    notifyListeners();
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

  /// Moves [point] to the middle of the unobstructed canvas. Zoom stays put.
  ///
  /// [insetLeft] and [insetRight] are the side panes covering the drawing, so
  /// the point lands in the hole between them rather than under a panel.
  void centerInHole(Vec2 point, {double insetLeft = 0, double insetRight = 0}) {
    final size = _viewport.size;
    final scale = _viewport.scale;
    if (size.isEmpty || scale.abs() <= 1e-12) {
      centerOn(point);
      return;
    }
    final left = insetLeft.clamp(0, size.width).toDouble();
    final right = insetRight
        .clamp(0, math.max(0.0, size.width - left))
        .toDouble();
    final shift = (left - right) / (2 * scale);
    centerOn(Vec2(point.x - shift, point.y));
  }

  /// Remembers the current camera once. See [_heldView].
  void holdView() => _heldView ??= _viewport;

  /// Forgets a held camera without moving the view.
  void dropHeldView() => _heldView = null;

  /// Puts the camera back to the one [holdView] saved.
  ///
  /// The widget size stays as it is now: the window may have been resized
  /// while the block was open, and the saved size would fight the next layout.
  /// Returns false when nothing was held.
  bool restoreHeldView() {
    final held = _heldView;
    _heldView = null;
    if (held == null) return false;
    viewport = held.copyWith(
      size: _viewport.size,
      devicePixelRatio: _viewport.devicePixelRatio,
    );
    return true;
  }

  @override
  void dispose() {
    _settle?.cancel();
    _settle = null;
    super.dispose();
  }
}
