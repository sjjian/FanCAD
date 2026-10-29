import 'dart:ui' as ui;

import 'render_scene.dart';
import 'scene_painter.dart';
import 'viewport.dart';

/// Holds the last built scene and its recording so a camera move can reuse
/// them.
///
/// This is what keeps pan and zoom off the scene builder on a 200,000 entity
/// drawing. A pan replays the recording, which works because alignment is
/// baked into the scene at build time and both cameras are locked to whole
/// physical pixels: a pan is then a whole-pixel translation, and replaying
/// the recording is identical to rebuilding it rather than a blurred
/// approximation. A zoom cannot replay the recording — that would scale every
/// stroke with it — so it paints the cached scene again under the scale
/// instead, which keeps the linework sharp and its width on screen.
class DrawingCache {
  /// How far a zoom may run on the cached scene before it is rebuilt.
  ///
  /// Painting the batches under `canvas.scale` keeps the linework sharp and
  /// lands it exactly where the new camera would put it. What the scene
  /// cannot follow is curve tessellation and the merging of sub-pixel
  /// vertices, both of which belong to the scale it was built at. A rebuild
  /// in the middle of a gesture stalls a sheet-set drawing for a tenth of a
  /// second, which reads far worse than a coarse curve for the moment the
  /// camera is moving, so the window is a factor of four either way.
  static const double minPreviewScale = 0.25;
  static const double maxPreviewScale = 4.0;

  /// How many frames a zoom may keep painting past [RenderScene.coverage]
  /// before the caller is asked to rebuild.
  ///
  /// The scene only holds the overscan around the camera it was built for, so a
  /// zoom out that keeps going runs out of drawing and shows a blank border. A
  /// rebuild there costs the stall the gesture exists to avoid, so the strip is
  /// tolerated for a moment; a gesture that is still going after this many
  /// frames — a third of a second at 60 Hz — is better served by one rebuild
  /// than by a border that keeps growing.
  static const int overscanGraceFrames = 20;

  RenderScene? _scene;
  ui.Picture? _picture;
  int _documentVersion = -1;

  /// Frames painted since the cached scene first fell short of the viewport,
  /// back to zero while it still covers it. Drives [overscanGraceFrames].
  int _beyondCoverage = 0;

  RenderScene? get scene => _scene;
  ui.Picture? get picture => _picture;

  void invalidate() {
    _scene = null;
    _picture?.dispose();
    _picture = null;
    _documentVersion = -1;
    _beyondCoverage = 0;
  }

  void store(RenderScene scene, ui.Picture picture, int documentVersion) {
    if (!identical(_picture, picture)) _picture?.dispose();
    _scene = scene;
    _picture = picture;
    _documentVersion = documentVersion;
    _beyondCoverage = 0;
  }

  /// How the recording can stand in for [viewport], or null when the scene has
  /// to be rebuilt.
  ///
  /// A pan at the same widget size is always allowed and always exact. A window
  /// resize is that same translation while the size is still changing, then a
  /// crisp rebuild once the camera settles. A zoom is allowed while a gesture is
  /// in flight: during the gesture the linework follows the geometry rather
  /// than being realigned, and once the camera settles the caller asks again
  /// with `interactive: false` and gets a crisp rebuild.
  ScenePlacement? placementFor(
    CadViewport viewport,
    int documentVersion, {
    required bool interactive,
  }) {
    final scene = _scene;
    if (scene == null || _picture == null) return null;
    if (_documentVersion != documentVersion) return null;
    final placement = scene.placementFor(viewport);
    if (!scene.covers(viewport)) {
      // A zoom out in flight soon looks past the overscan. The strip beyond it
      // stays empty rather than rebuilding mid-gesture, but only for
      // [overscanGraceFrames]: a gesture that keeps going would otherwise watch
      // the drawing shrink into a border of blank canvas.
      final zooming = interactive && !placement.isTranslation;
      if (!zooming || !scene.overlaps(viewport)) return null;
      if (++_beyondCoverage > overscanGraceFrames) return null;
    } else {
      _beyondCoverage = 0;
    }
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

  /// Shows the cached scene under [placement] for [viewport], onto a canvas in
  /// logical pixels.
  ///
  /// A pan replays the recording. A zoom has [painter] paint the scene again
  /// under the scale instead: replaying would scale every stroke with it, so
  /// lines would swell while zooming in and snap back when the camera settles.
  /// Painting again keeps them at their width and skips what is off screen.
  void replay(
    ui.Canvas canvas,
    ScenePlacement placement,
    CadViewport viewport,
    ScenePainter painter,
  ) {
    final scene = _scene;
    final picture = _picture;
    if (scene == null || picture == null) return;
    final ratio = viewport.devicePixelRatio;
    final dpr = ratio > 0 && ratio.isFinite ? ratio : 1.0;
    canvas.save();
    // The recording is in logical pixels because the painter undoes the device
    // ratio before drawing; the placement is in physical pixels because that
    // is the space alignment happens in.
    canvas.translate(placement.offset.dx / dpr, placement.offset.dy / dpr);
    if (placement.isTranslation) {
      canvas.drawPicture(picture);
    } else {
      final scale = placement.scale;
      final offset = placement.offset;
      final size = viewport.size * dpr;
      canvas.scale(scale);
      painter.paint(
        canvas,
        scene,
        zoom: scale,
        window: ui.Rect.fromLTRB(
          -offset.dx / scale,
          -offset.dy / scale,
          (size.width - offset.dx) / scale,
          (size.height - offset.dy) / scale,
        ).inflate(2 / scale),
      );
    }
    canvas.restore();
  }

  void dispose() => invalidate();
}
