import 'dart:ui' as ui;

import 'render_scene.dart';
import 'viewport.dart';

/// Holds the last recorded drawing so a camera move can reuse it.
///
/// This is what makes pan and zoom cost the same on a 200,000 entity drawing
/// as on an empty one. It works because alignment is baked into the scene at
/// build time and both cameras are locked to whole physical pixels: a pan is
/// then a whole-pixel translation, and replaying the recording is identical to
/// rebuilding it rather than a blurred approximation.
class DrawingCache {
  /// How far a zoom may run on the recording before the scene is rebuilt.
  ///
  /// Replaying under `canvas.scale` re-rasterises the vector commands, so the
  /// linework stays sharp and lands exactly where the new camera would put it.
  /// What the recording cannot follow is curve tessellation and paper line
  /// weight, both of which belong to the scale it was built at, so the window
  /// is a factor of two either way.
  static const double minPreviewScale = 0.5;
  static const double maxPreviewScale = 2.0;

  RenderScene? _scene;
  ui.Picture? _picture;
  int _documentVersion = -1;

  RenderScene? get scene => _scene;
  ui.Picture? get picture => _picture;

  void invalidate() {
    _scene = null;
    _picture?.dispose();
    _picture = null;
    _documentVersion = -1;
  }

  void store(RenderScene scene, ui.Picture picture, int documentVersion) {
    if (!identical(_picture, picture)) _picture?.dispose();
    _scene = scene;
    _picture = picture;
    _documentVersion = documentVersion;
  }

  /// How the recording can stand in for [viewport], or null when the scene has
  /// to be rebuilt.
  ///
  /// A pan at the same widget size is always allowed and always exact. A window
  /// resize is that same translation while the size is still changing, then a
  /// crisp rebuild once the camera settles. A zoom is allowed only while a
  /// gesture is in
  /// flight: during the gesture the linework follows the geometry rather than
  /// being realigned, and once the camera settles the caller asks again with
  /// `interactive: false` and gets a crisp rebuild.
  ScenePlacement? placementFor(
    CadViewport viewport,
    int documentVersion, {
    required bool interactive,
  }) {
    final scene = _scene;
    if (scene == null || _picture == null) return null;
    if (_documentVersion != documentVersion) return null;
    if (!scene.covers(viewport)) return null;
    final placement = scene.placementFor(viewport);
    // A pan at the same widget size is exact. A window resize is the same kind
    // of translation, but only while the size is still changing: once the
    // camera settles the new size has to be recorded, including the strip the
    // overscan did not cover.
    final resized = scene.viewport.size != viewport.size;
    if (placement.isTranslation && !resized) return placement;
    if (!interactive) return null;
    if (resized && placement.isTranslation) return placement;
    if (!placement.scale.isFinite) return null;
    if (placement.scale < minPreviewScale ||
        placement.scale > maxPreviewScale) {
      return null;
    }
    return placement;
  }

  /// Replays the recording under [placement] onto a canvas in logical pixels.
  void replay(
    ui.Canvas canvas,
    ScenePlacement placement,
    double devicePixelRatio,
  ) {
    final picture = _picture;
    if (picture == null) return;
    final dpr = devicePixelRatio > 0 && devicePixelRatio.isFinite
        ? devicePixelRatio
        : 1.0;
    canvas.save();
    // The recording is in logical pixels because the painter undoes the device
    // ratio before drawing; the placement is in physical pixels because that
    // is the space alignment happens in.
    canvas.translate(placement.offset.dx / dpr, placement.offset.dy / dpr);
    if (!placement.isTranslation) canvas.scale(placement.scale);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void dispose() => invalidate();
}
