import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'batch.dart';
import 'scene.dart';
import 'text_cache.dart';

/// Paints a [RenderScene] onto a canvas.
///
/// Separate from any widget so the same scene can be rasterised into a
/// `ui.Picture` for the static layer, drawn directly for the interactive
/// overlay, or replayed at print resolution.
class ScenePainter {
  ScenePainter({ParagraphCache? paragraphs, this.fontFamily = 'monospace'})
    : paragraphs = paragraphs ?? ParagraphCache();

  final ParagraphCache paragraphs;

  /// Fallback face used until SHX stroke fonts are implemented. A monospaced
  /// face is the closest widely available match to the `txt` shape that most
  /// drawings specify.
  final String fontFamily;

  /// Reused between frames: allocating a Paint per batch shows up in profiles
  /// of drawings with many layers.
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..isAntiAlias = true;
  final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final Paint _pointPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  void paint(ui.Canvas canvas, RenderScene scene) {
    // Fills first: hatches and solids sit behind the linework that bounds
    // them, which is the order AutoCAD's draw order produces in practice.
    for (final batch in scene.fillBatches) {
      _fillPaint.color = batch.key.color;
      canvas.drawPath(batch.path, _fillPaint);
    }

    for (final batch in scene.lineBatches) {
      final width = batch.key.strokeWidth;
      _strokePaint
        ..color = batch.key.color
        ..strokeWidth = width
        // Hairlines stay aliased so ACI 7 is a real white or black pixel
        // instead of a grey blend against the canvas.
        ..isAntiAlias = width > 1;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        batch.vertices.view,
        _strokePaint,
      );
    }

    for (final batch in scene.pointBatches) {
      _pointPaint
        ..color = batch.key.color
        ..strokeWidth = batch.key.strokeWidth;
      canvas.drawRawPoints(
        ui.PointMode.points,
        batch.vertices.view,
        _pointPaint,
      );
    }

    for (final item in scene.texts) {
      _paintText(canvas, item);
    }

    for (final item in scene.images) {
      _paintImagePlaceholder(canvas, item);
    }
  }

  void _paintText(ui.Canvas canvas, TextItem item) {
    final paragraph = paragraphs.obtain(item, fontFamily: fontFamily);
    final width = item.wrapWidth > 0 ? item.wrapWidth : paragraph.maxIntrinsicWidth;
    final height = paragraph.height;

    // DWG anchors text at the baseline or at a box corner; a paragraph is
    // painted from its top-left. Resolve the difference here rather than at
    // build time so the same TextItem can be re-anchored if the font changes.
    final dx = switch (item.hAlign) {
      1 || 4 || 5 => -width / 2,
      2 => -width,
      _ => 0.0,
    };
    final dy = switch (item.vAlign) {
      0 || 1 => -height,
      2 => -height / 2,
      _ => 0.0,
    };

    canvas.save();
    canvas.translate(item.origin.dx, item.origin.dy);
    if (item.rotation != 0) canvas.rotate(item.rotation);
    canvas
      ..drawParagraph(paragraph, ui.Offset(dx, dy))
      ..restore();
  }

  /// Draws the outline and file name of an unloaded raster reference.
  ///
  /// Loading the pixels is asynchronous and belongs to the image cache, which
  /// arrives with the external reference work. Until then an image must still
  /// occupy its space visibly, because a missing underlay that leaves no trace
  /// is indistinguishable from a drawing error.
  void _paintImagePlaceholder(ui.Canvas canvas, ImageItem item) {
    final path = ui.Path()
      ..moveTo(item.origin.dx, item.origin.dy)
      ..relativeLineTo(item.uVector.dx, item.uVector.dy)
      ..relativeLineTo(item.vVector.dx, item.vVector.dy)
      ..relativeLineTo(-item.uVector.dx, -item.uVector.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const ui.Color(0x66FFFFFF),
    );
  }

  /// Rasterises a scene into a picture that can be replayed cheaply.
  ///
  /// The recording is culled to the viewport so a sheet border that lands
  /// off-screen cannot expand a [RepaintBoundary] over the application chrome.
  ui.Picture record(RenderScene scene) {
    final recorder = ui.PictureRecorder();
    final size = scene.viewport.size;
    final cull = size.width > 0 && size.height > 0 ? Offset.zero & size : null;
    paint(ui.Canvas(recorder, cull), scene);
    return recorder.endRecording();
  }
}
