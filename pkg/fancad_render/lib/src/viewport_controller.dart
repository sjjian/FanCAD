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
          initial ??
          const CadViewport(
            center: Vec2.zero(),
            scale: 1,
            size: Size.zero,
          );

  CadViewport _viewport;

  /// Set while a pan or zoom gesture is in flight, so the renderer can prefer
  /// reusing the last scene over building an exact one.
  bool _interacting = false;

  /// Pending fit request, applied once the widget reports a real size.
  Bounds2? _pendingFit;

  CadViewport get viewport => _viewport;
  bool get isInteracting => _interacting;

  set viewport(CadViewport value) {
    if (value == _viewport) return;
    _viewport = value;
    notifyListeners();
  }

  /// Called by the canvas on layout. Applies a deferred fit if one is queued.
  void setSize(Size size, double devicePixelRatio) {
    if (size == _viewport.size &&
        devicePixelRatio == _viewport.devicePixelRatio) {
      return;
    }
    final hadNoSize = _viewport.size.isEmpty;
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
    } else if (hadNoSize && !size.isEmpty) {
      // Keep the same drawing point centred when the widget first gets a size.
      _viewport = _viewport.copyWith(center: _viewport.center);
    }
    notifyListeners();
  }

  void beginInteraction() {
    if (_interacting) return;
    _interacting = true;
    notifyListeners();
  }

  void endInteraction() {
    if (!_interacting) return;
    _interacting = false;
    notifyListeners();
  }

  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) return;
    viewport = _viewport.panned(screenDelta);
  }

  void zoomBy(double factor, Offset anchor) {
    viewport = _viewport.zoomed(factor, anchor);
  }

  void zoomAtCenter(double factor) =>
      viewport = _viewport.zoomedAtCenter(factor);

  void zoomIn() => zoomAtCenter(1.25);
  void zoomOut() => zoomAtCenter(0.8);

  /// Frames [bounds]. Defers until the widget has a size, so this can be
  /// called immediately after opening a file.
  void zoomTo(Bounds2 bounds, {double margin = 0.06}) {
    if (bounds.isEmpty) return;
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
}
