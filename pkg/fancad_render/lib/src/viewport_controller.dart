import 'dart:async';
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

  CadViewport get viewport => _viewport;
  bool get isInteracting => _interacting;

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
  void setSize(Size size, double devicePixelRatio) {
    if (size == _viewport.size &&
        devicePixelRatio == _viewport.devicePixelRatio) {
      return;
    }
    _viewport = _viewport.copyWith(
      size: size,
      devicePixelRatio: devicePixelRatio,
    );
    final pending = _pendingFit;
    if (pending != null && !size.isEmpty) {
      _pendingFit = null;
      _viewport = CadViewport.fit(
        pending,
        size,
        devicePixelRatio: devicePixelRatio,
      );
    }
    // A new size or ratio moves the screen origin, so the lock is reapplied
    // even though the centre did not change.
    _viewport = _viewport.pixelLocked();
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

  void zoomAtCenter(double factor) =>
      _moveTo(_viewport.zoomedAtCenter(factor));

  void zoomIn() => zoomAtCenter(1.25);
  void zoomOut() => zoomAtCenter(0.8);

  /// Frames [bounds]. Defers until the widget has a size, so this can be
  /// called immediately after opening a file.
  void zoomTo(Bounds2 bounds, {double margin = 0.06}) {
    if (bounds.isEmpty || !bounds.isFinite) return;
    if (_viewport.size.isEmpty) {
      _pendingFit = bounds;
      return;
    }
    viewport = CadViewport.fit(
      bounds,
      _viewport.size,
      margin: margin,
      devicePixelRatio: _viewport.devicePixelRatio,
    );
  }

  /// Frames the whole drawing.
  void zoomToExtents(CadDocument document) {
    final extents = document.extents;
    if (extents.isEmpty) {
      // An empty drawing still needs a sensible working scale rather than an
      // arbitrary one, so show a 200 unit wide area around the origin.
      zoomTo(const Bounds2(-100, -100, 100, 100));
      return;
    }
    zoomTo(extents);
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
