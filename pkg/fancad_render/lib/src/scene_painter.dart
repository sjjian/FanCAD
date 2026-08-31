import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'batch.dart';
import 'drawing_font.dart';
import 'scene.dart';
import 'text_cache.dart';

/// Paints a [RenderScene] onto a canvas.
///
/// Separate from any widget so the same scene can be rasterised into a
/// `ui.Picture` for the static layer, drawn directly for the interactive
/// overlay, or replayed at print resolution.
class ScenePainter {
  ScenePainter({ParagraphCache? paragraphs, String? fontFamily})
    : paragraphs = paragraphs ?? ParagraphCache(),
      fontFamily = fontFamily ?? const DrawingFontMap().latinFallback;

  final ParagraphCache paragraphs;

  /// Last-resort face when a [TextItem] has no resolved family. Scene
  /// construction maps STYLE / CJK onto a system face; this is only for
  /// overlay strings that never went through that map.
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

  /// Impeller drops a true zero-width `drawRawPoints` stroke. The batch key
  /// still stores 0 for hairline so identical lines stay in one batch.
  static double _hairline(double width) => width <= 0 ? 1 : width;

  void paint(ui.Canvas canvas, RenderScene scene) {
    // Fills first: hatches and solids sit behind the linework that bounds
    // them, which is the order AutoCAD's draw order produces in practice.
    for (final batch in scene.fillBatches) {
      _fillPaint.color = batch.key.color;
      canvas.drawPath(batch.path, _fillPaint);
    }

    for (final batch in scene.lineBatches) {
      final width = _hairline(batch.key.strokeWidth);
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
        ..strokeWidth = _hairline(batch.key.strokeWidth);
      canvas.drawRawPoints(
        ui.PointMode.points,
        batch.vertices.view,
        _pointPaint,
      );
    }

    for (final item in scene.texts) {
      if (_isFarOffscreen(item.origin, scene.viewport.size)) continue;
      _paintText(canvas, item);
    }

    for (final item in scene.images) {
      _paintImagePlaceholder(canvas, item);
    }
  }

  /// Stolen *D members and nested dimensions can land millions of pixels
  /// off the sheet. Drawing those paragraphs expands a recorded picture
  /// past the chrome and is never visible anyway.
  static bool _isFarOffscreen(Offset origin, Size size) {
    final pad = size.width + size.height;
    return origin.dx < -pad ||
        origin.dy < -pad ||
        origin.dx > size.width + pad ||
        origin.dy > size.height + pad;
  }

  void _paintText(ui.Canvas canvas, TextItem item) {
    final paragraph = paragraphs.obtain(item, fontFamily: fontFamily);
    final width =
        (item.wrapWidth > 0 ? item.wrapWidth : paragraph.maxIntrinsicWidth) *
        item.widthFactor;
    final height = paragraph.height;
    final baseline = paragraph.alphabeticBaseline;

    // DWG anchors TEXT on the baseline and MTEXT on a box corner. A
    // paragraph is painted from its top-left, so the two tables differ:
    // a top attachment must stay at dy = 0, not jump up by a line.
    final dx = switch (item.hAlign) {
      1 || 4 || 5 => -width / 2,
      2 => -width,
      _ => 0.0,
    };
    final dy = item.boxAnchor
        ? switch (item.vAlign) {
            2 => -height / 2,
            0 || 1 => -height,
            _ => 0.0,
          }
        : switch (item.vAlign) {
            3 => 0.0,
            2 => -baseline / 2,
            1 => -height,
            _ => -baseline,
          };

    canvas.save();
    canvas.translate(item.origin.dx, item.origin.dy);
    if (item.rotation != 0) canvas.rotate(item.rotation);
    if (item.backwards || item.upsideDown) {
      canvas.scale(item.backwards ? -1 : 1, item.upsideDown ? -1 : 1);
    }
    canvas.translate(dx, dy);
    if (item.obliqueAngle.abs() > 1e-9) {
      final shear = math.tan(item.obliqueAngle);
      canvas.transform(
        Float64List.fromList([
          1, 0, 0, 0,
          shear, 1, 0, 0,
          0, 0, 1, 0,
          0, 0, 0, 1,
        ]),
      );
    }
    if ((item.widthFactor - 1).abs() > 1e-9) {
      canvas.scale(item.widthFactor, 1);
    }
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    if (item.underline || item.overline || item.strike) {
      final span =
          item.wrapWidth > 0 ? item.wrapWidth / item.widthFactor : paragraph.maxIntrinsicWidth;
      final stroke = Paint()
        ..color = item.color
        ..strokeWidth = math.max(0.6, item.pixelHeight * 0.06)
        ..style = PaintingStyle.stroke;
      if (item.underline) {
        canvas.drawLine(
          ui.Offset(0, baseline + 1),
          ui.Offset(span, baseline + 1),
          stroke,
        );
      }
      if (item.overline) {
        canvas.drawLine(ui.Offset.zero, ui.Offset(span, 0), stroke);
      }
      if (item.strike) {
        canvas.drawLine(
          ui.Offset(0, baseline * 0.55),
          ui.Offset(span, baseline * 0.55),
          stroke,
        );
      }
    }
    canvas.restore();
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
