import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'batch.dart';
import 'drawing_font.dart';
import 'render_scene.dart';
import 'text_cache.dart';

/// Paints a [RenderScene] onto a canvas.
///
/// Separate from any widget so the same scene can be recorded into a
/// `ui.Picture` for the drawing layer. Overlay glyphs use a separate painter;
/// plots go through `fancad_core`.
///
/// Deliberately dumb: every alignment decision was already made and baked into
/// the vertex buffers by [SceneBuilder]. Deciding anything here would mean
/// deciding it again on every frame, and a decision that changes with the
/// frame is what made hairlines blink while zooming.
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

  /// Segments kept by [_cullTo], reused between batches and frames so a
  /// zoomed repaint does not allocate per batch.
  Float32List _culled = Float32List(0);

  /// Impeller drops a true zero-width `drawRawPoints` stroke, and a hairline
  /// means one physical pixel anyway. The batch key still stores 0 so
  /// identical lines from any layer stay in one batch.
  static double _hairline(double width) => width <= 0 ? 1 : width;

  /// Draws [scene].
  ///
  /// Anti-aliasing is on for every stroke and never toggled. An axis-aligned
  /// hairline was aligned onto a physical pixel centre during the build, so it
  /// covers one pixel column completely and an ACI 3 stays a saturated green;
  /// a sloped line gets the soft edge that keeps it off the staircase. The old
  /// pairing of "align and turn AA off" made zoom pop between solid and grey
  /// green as segments crossed the threshold.
  ///
  /// [zoom] is the scale the caller has already applied to [canvas] to show
  /// the scene under a camera that has zoomed since it was built. Strokes are
  /// divided by it, so a line keeps its width on screen instead of swelling
  /// with the zoom and snapping back when the scene is rebuilt. [window] is
  /// the part of the scene, in its physical pixels, that is on screen;
  /// segments outside it are skipped.
  ///
  /// [exactText] lays every label out at its own size instead of at the height
  /// band the cache keeps. The screen takes the band, because a settled zoom
  /// would otherwise re-shape every label; a plot export takes the exact
  /// layout, because its text is the output rather than a preview of it.
  void paint(
    ui.Canvas canvas,
    RenderScene scene, {
    double zoom = 1,
    Rect? window,
    bool exactText = false,
  }) {
    final dpr = _ratio(scene.viewport.devicePixelRatio);
    canvas.save();
    // Batches are in physical pixels. Undoing the ratio once, here, is what
    // lets a hairline be one physical pixel and an alignment be a physical
    // pixel centre without every call site repeating the conversion.
    canvas.scale(1 / dpr);

    final extent = scene.viewport.size * dpr;
    final strokeScale = zoom > 0 && zoom.isFinite ? 1 / zoom : 1.0;
    for (final pass in scene.passes) {
      _paintPass(canvas, pass, dpr, extent, strokeScale, window, exactText);
    }

    canvas.restore();
  }

  /// Paints one drawing-order bucket.
  ///
  /// Underlays first, then fills, then the linework that bounds them, then
  /// markers, then text. That is the order AutoCAD's draw order produces in
  /// practice for a document that does not specify one.
  void _paintPass(
    ui.Canvas canvas,
    RenderPass pass,
    double dpr,
    Size extent,
    double strokeScale,
    Rect? window,
    bool exactText,
  ) {
    for (final item in pass.images) {
      _paintImagePlaceholder(canvas, item, dpr);
    }

    for (final batch in pass.fillBatches) {
      _fillPaint.color = batch.key.color;
      canvas.drawPath(batch.path, _fillPaint);
    }

    // One `drawRawPoints` per batch, not one `drawLine` per segment. The
    // recording is replayed on every pan, so an op per segment is charged to
    // the pan as well: measured on the test rasteriser it records an order of
    // magnitude slower and makes the picture half again as large, for the same
    // raster time.
    //
    // A zoom passes the part of the scene it can see, and `_paintLines` draws
    // only that: a batch wholly inside the window goes out untouched, one
    // wholly outside is skipped, and one that straddles it is drawn cell by
    // cell. That keeps a zoom out — where the whole drawing is on screen and
    // culling can drop nothing — at one call per batch, while a zoom in walks
    // the cells that are left instead of every segment in the drawing.
    for (final batch in pass.lineBatches) {
      _strokePaint
        ..color = batch.key.color
        ..strokeWidth = _hairline(batch.key.strokeWidth) * strokeScale;
      _paintLines(canvas, batch, window);
    }

    for (final batch in pass.pointBatches) {
      _pointPaint
        ..color = batch.key.color
        ..strokeWidth = _hairline(batch.key.strokeWidth) * strokeScale;
      canvas.drawRawPoints(
        ui.PointMode.points,
        batch.vertices.view,
        _pointPaint,
      );
    }

    for (final item in pass.texts) {
      if (_isFarOffscreen(item.origin, extent)) continue;
      if (window != null && !_mayReach(item, window)) continue;
      _paintText(canvas, item, dpr, exactText);
    }
  }

  /// Draws [batch], keeping only what [window] can show when one is given.
  ///
  /// [LineBatch.bounds] answers for a whole batch without touching a vertex,
  /// and [LineBatch.cellStarts] cuts a batch that straddles the window into
  /// cells, so neither case walks the whole drawing. Only a batch too small to
  /// have a grid falls back to [_cullTo], where scanning costs less than the
  /// extra draw calls a grid would make.
  void _paintLines(ui.Canvas canvas, LineBatch batch, Rect? window) {
    final xy = batch.vertices.view;
    if (xy.isEmpty) return;
    if (window == null) {
      canvas.drawRawPoints(ui.PointMode.lines, xy, _strokePaint);
      return;
    }
    // A pen reaches past its segment, so grow the window before comparing it
    // with anything. Without this a wide line just outside the window is
    // dropped while half its stroke would have been on screen.
    final half = _strokePaint.strokeWidth / 2;
    final reach = half > 0 ? window.inflate(half) : window;

    final bounds = batch.bounds;
    if (bounds != null) {
      if (!_touches(bounds, reach)) return;
      if (_inside(bounds, reach)) {
        canvas.drawRawPoints(ui.PointMode.lines, xy, _strokePaint);
        return;
      }
    }

    final starts = batch.cellStarts;
    final cells = batch.cellBounds;
    if (starts != null && cells != null) {
      for (var c = 0; c < cells.length; c++) {
        final start = starts[c], end = starts[c + 1];
        if (start == end || !_touches(cells[c], reach)) continue;
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(xy, start * 4, end * 4),
          _strokePaint,
        );
      }
      final wideStart = starts[cells.length];
      final wide = batch.wideBounds;
      if (wideStart < batch.segmentCount &&
          wide != null &&
          _touches(wide, reach)) {
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(xy, wideStart * 4, xy.length),
          _strokePaint,
        );
      }
      return;
    }

    final culled = _cullTo(xy, reach);
    if (culled.isEmpty) return;
    canvas.drawRawPoints(ui.PointMode.lines, culled, _strokePaint);
  }

  static bool _touches(Rect a, Rect b) =>
      a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;

  static bool _inside(Rect a, Rect b) =>
      a.left >= b.left &&
      a.right <= b.right &&
      a.top >= b.top &&
      a.bottom <= b.bottom;

  /// The segments of [xy] that can touch [window], in a buffer reused between
  /// batches.
  ///
  /// The result is a view into that buffer, valid until the next call, so the
  /// caller has to copy it or draw it before the next batch. A segment is
  /// dropped only when its whole bounding box is outside [window]; the window
  /// carries the margin for a pen that reaches past its endpoints.
  Float32List _cullTo(Float32List xy, Rect window) {
    if (_culled.length < xy.length) {
      var capacity = _culled.isEmpty ? 1024 : _culled.length;
      while (capacity < xy.length) {
        capacity *= 2;
      }
      _culled = Float32List(capacity);
    }
    var kept = 0;
    for (var i = 0; i + 3 < xy.length; i += 4) {
      final x0 = xy[i], y0 = xy[i + 1], x1 = xy[i + 2], y1 = xy[i + 3];
      if (math.max(x0, x1) < window.left ||
          math.min(x0, x1) > window.right ||
          math.max(y0, y1) < window.top ||
          math.min(y0, y1) > window.bottom) {
        continue;
      }
      _culled[kept++] = x0;
      _culled[kept++] = y0;
      _culled[kept++] = x1;
      _culled[kept++] = y1;
    }
    return Float32List.sublistView(_culled, 0, kept);
  }

  /// Whether a label anchored at its origin could touch [window]. Measuring it
  /// would cost what drawing it does, so the reach is a generous bound: a full
  /// em per character in any direction, plus the wrap width.
  ///
  /// [TextItem.pixelHeight] is the cap height, not the em, and a CJK advance is
  /// a whole em — about 1.4 times the cap height in the default face, and up to
  /// 2.5 in the narrowest one. Using the cap height directly under-reached a
  /// long note by a third and culled it while half of it was on screen.
  bool _mayReach(TextItem item, Rect window) {
    final family = item.fontFamily.isEmpty ? fontFamily : item.fontFamily;
    final capRatio = paragraphs.capRatio(family);
    final em = capRatio > 0 ? item.pixelHeight / capRatio : item.pixelHeight;
    final reach =
        em *
            (item.text.length + 2) *
            math.max(item.widthFactor, 1) *
            math.max(item.tracking, 1) +
        item.wrapWidth;
    return window.inflate(reach).contains(item.origin);
  }

  static double _ratio(double dpr) => dpr > 0 && dpr.isFinite ? dpr : 1.0;

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

  void _paintText(ui.Canvas canvas, TextItem item, double dpr, bool exactText) {
    final (:paragraph, :scale) = exactText
        ? (
            paragraph: paragraphs.obtain(item, fontFamily: fontFamily),
            scale: 1.0,
          )
        : paragraphs.obtainBanded(item, fontFamily: fontFamily);
    final width =
        (item.wrapWidth > 0
            ? item.wrapWidth
            : paragraph.maxIntrinsicWidth * scale) *
        item.widthFactor;
    final height = paragraph.height * scale;
    final baseline = paragraph.alphabeticBaseline * scale;

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
          1,
          0,
          0,
          0,
          shear,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
      );
    }
    if ((item.widthFactor - 1).abs() > 1e-9) {
      canvas.scale(item.widthFactor, 1);
    }
    if (scale != 1) {
      canvas.save();
      canvas.scale(scale);
      canvas.drawParagraph(paragraph, ui.Offset.zero);
      canvas.restore();
    } else {
      canvas.drawParagraph(paragraph, ui.Offset.zero);
    }
    if (item.underline || item.overline || item.strike) {
      final span = item.wrapWidth > 0
          ? item.wrapWidth / item.widthFactor
          : paragraph.maxIntrinsicWidth * scale;
      final stroke = Paint()
        ..color = item.color
        ..strokeWidth = math.max(dpr, item.pixelHeight * 0.06)
        ..style = PaintingStyle.stroke;
      if (item.underline) {
        canvas.drawLine(
          ui.Offset(0, baseline + dpr),
          ui.Offset(span, baseline + dpr),
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

  /// Draws the outline of an unloaded raster reference.
  ///
  /// Pixel decode is not wired yet. Until it is, an IMAGE still occupies its
  /// space visibly, because a missing underlay that leaves no trace is
  /// indistinguishable from a drawing error.
  void _paintImagePlaceholder(ui.Canvas canvas, ImageItem item, double dpr) {
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
        ..strokeWidth = dpr
        ..color = const ui.Color(0x66FFFFFF),
    );
  }

  /// Rasterises a scene into a picture that can be replayed cheaply.
  ///
  /// The recording is culled to [RenderScene.coverageOnScreen], which is the
  /// overscan the batches were built for, not the widget. A sheet border that
  /// lands off that box still cannot expand a [RepaintBoundary] over the
  /// chrome — the live painter clips to the widget — but a pan that stays
  /// inside the overscan has pixels to reveal instead of a blank strip.
  /// The cull box is in logical pixels because [paint] undoes the device ratio
  /// before drawing anything.
  ui.Picture record(RenderScene scene) {
    final recorder = ui.PictureRecorder();
    final cull = scene.coverageOnScreen;
    paint(
      ui.Canvas(recorder, cull.width > 0 && cull.height > 0 ? cull : null),
      scene,
    );
    return recorder.endRecording();
  }
}
