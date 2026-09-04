import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fancad_core/fancad_core.dart';

import 'batch.dart';
import 'device_space.dart';
import 'drawing_font.dart';
import 'palette.dart';
import 'tessellation_cache.dart';
import 'viewport.dart';

/// Converts world-space primitives into batches of physical-pixel geometry.
///
/// The boundary where drawing units stop and pixels start: entities emit world
/// coordinates through [GeometrySink], and everything past this point — clip,
/// dash runs, line weight, alignment, the painter — is in physical pixels.
///
/// Plot and PDF go through `fancad_core`'s plotter, not this sink. The canvas
/// is the only production caller.
class BatchingSink implements GeometrySink {
  /// Text below one physical pixel is drawn as a bar. Labels of two to four
  /// pixels stay as type; only ink that would vanish into a speck is replaced.
  static const double minimumTextPixels = 1;

  BatchingSink({
    required this.viewport,
    required this.palette,
    this.fonts = const DrawingFontMap(),
    this.lineTypes = const {},
    this.globalLineTypeScale = 1,
  }) : pixels = viewport.pixels;

  final CadViewport viewport;

  /// The world-to-physical-pixel mapping every primitive is projected through.
  final PixelSpace pixels;
  final AciPalette palette;
  final DrawingFontMap fonts;

  /// Dash patterns in drawing units, by line type name. Solid line types are
  /// simply absent.
  final Map<String, List<double>> lineTypes;
  final double globalLineTypeScale;

  /// World-space clip used when drawing a paper-space viewport. Geometry that
  /// leaves the window is cut so it does not spill onto the sheet.
  Bounds2? worldClip;

  /// The drawing-order bucket every following primitive belongs to.
  ///
  /// Stays 0 until `$SORTENTS` is read, which is the point: batching happens
  /// inside a bucket, so a document with no explicit order keeps merging every
  /// same-styled line into one draw call.
  int drawOrder = 0;

  final Map<BatchKey, LineBatch> lineBatches = {};
  final Map<BatchKey, PointBatch> pointBatches = {};
  final Map<BatchKey, FillBatch> fillBatches = {};
  final List<TextItem> texts = [];
  final List<ImageItem> images = [];

  int segmentCount = 0;

  /// Reused between primitives so the hot loop does not allocate.
  Float32List _scratch = Float32List(1024);

  bool get isEmpty =>
      lineBatches.isEmpty &&
      pointBatches.isEmpty &&
      fillBatches.isEmpty &&
      texts.isEmpty &&
      images.isEmpty;

  void replay(List<CachedPrimitive> primitives) {
    replayCachedPrimitives(this, primitives);
  }

  /// Projects an interleaved world buffer into physical pixels.
  ///
  /// The returned view is only valid until the next call, which is fine because
  /// every caller copies immediately into a batch.
  Float32List _project(Float64List world) {
    if (_scratch.length < world.length) {
      var capacity = _scratch.length;
      while (capacity < world.length) {
        capacity *= 2;
      }
      _scratch = Float32List(capacity);
    }
    final scale = pixels.scale;
    final offsetX = pixels.originX;
    final offsetY = pixels.originY;
    for (var i = 0; i < world.length; i += 2) {
      _scratch[i] = world[i] * scale + offsetX;
      // The Y flip: drawing coordinates go up, screen coordinates go down.
      _scratch[i + 1] = offsetY - world[i + 1] * scale;
    }
    return Float32List.sublistView(_scratch, 0, world.length);
  }

  ui.Color _colorFor(ResolvedStyle style) {
    final color = palette.colorOf(style.color);
    if (style.transparency <= 0) return color;
    return color.withValues(alpha: 1 - style.transparency / 100);
  }

  /// Line weights are millimetres on paper (96 dpi), in physical pixels.
  /// Zooming in keeps that paper width; zooming out shrinks the stroke with
  /// the geometry. Below one physical pixel they become hairline, which the
  /// painter draws as exactly one pixel — the thinnest solid line the display
  /// has. Zero is that sentinel, so hairlines from any layer share one batch.
  double _strokeWidth(ResolvedStyle style) {
    final millimetres = LineWeight.toMillimetres(style.lineWeight);
    if (millimetres <= 0) return 0;
    // 96 dpi is the reference other CAD applications use for on-screen line
    // weight display.
    final zoom = viewport.scale < 1 ? viewport.scale : 1.0;
    final width = millimetres / 25.4 * 96 * zoom * pixels.dpr;
    if (!width.isFinite || width < 1) return 0;
    return width;
  }

  BatchKey _keyFor(ResolvedStyle style, {double extraWidth = 0}) => BatchKey(
    _colorFor(style),
    _strokeWidth(style) + extraWidth,
    order: drawOrder,
  );

  LineBatch _lineBatch(BatchKey key) =>
      lineBatches.putIfAbsent(key, () => LineBatch(key));

  @override
  void polyline(Float64List xy, ResolvedStyle style, {bool closed = false}) {
    if (xy.length < 4) return;
    final clip = worldClip;
    if (clip != null) {
      _polylineClipped(xy, style, closed: closed, clip: clip);
      return;
    }
    final projected = _project(xy);
    final batch = _lineBatch(_keyFor(style));
    final before = batch.segmentCount;
    final dashes = _dashPixelsFor(style);
    if (dashes == null) {
      batch.addPolyline(projected, closed: closed);
    } else {
      _addDashed(batch, projected, dashes, closed: closed);
    }
    segmentCount += batch.segmentCount - before;
  }

  /// The dash pattern in physical pixels, or null when the line should be
  /// solid.
  ///
  /// Dashes shorter than a few pixels read as a dimmer solid line, so below
  /// that threshold drawing solid is both cheaper and better looking. Patterns
  /// longer than the screen are also pointless: at that zoom the viewer is
  /// inside a single dash.
  List<double>? _dashPixelsFor(ResolvedStyle style) {
    final pattern = lineTypes[style.lineType];
    if (pattern == null || pattern.isEmpty) return null;
    final scale = pixels.scale * style.lineTypeScale * globalLineTypeScale;
    if (scale <= 0 || !scale.isFinite) return null;
    final dashes = [for (final segment in pattern) segment * scale];
    var total = 0.0;
    for (final segment in dashes) {
      total += segment;
    }
    if (total < pixels.fromLogical(6)) return null;
    final diagonal = pixels.fromLogical(
      viewport.size.width + viewport.size.height,
    );
    if (total > diagonal) return null;
    return dashes;
  }

  void _addDashed(
    LineBatch batch,
    Float32List screen,
    List<double> dashes, {
    required bool closed,
  }) {
    final count = screen.length ~/ 2;
    if (count < 2) return;
    var dashIndex = 0;
    var remaining = dashes[0];
    var drawing = true;

    void walk(double x0, double y0, double x1, double y1) {
      var length = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
      if (length <= 0) return;
      final dirX = (x1 - x0) / length;
      final dirY = (y1 - y0) / length;
      var startX = x0;
      var startY = y0;
      while (length > 1e-9) {
        final step = math.min(remaining, length);
        final endX = startX + dirX * step;
        final endY = startY + dirY * step;
        if (drawing) batch.vertices.add4(startX, startY, endX, endY);
        startX = endX;
        startY = endY;
        length -= step;
        remaining -= step;
        if (remaining <= 1e-9) {
          dashIndex = (dashIndex + 1) % dashes.length;
          remaining = dashes[dashIndex];
          drawing = !drawing;
        }
      }
    }

    for (var i = 0; i + 1 < count; i++) {
      walk(
        screen[i * 2],
        screen[i * 2 + 1],
        screen[(i + 1) * 2],
        screen[(i + 1) * 2 + 1],
      );
    }
    if (closed && count > 2) {
      walk(
        screen[(count - 1) * 2],
        screen[(count - 1) * 2 + 1],
        screen[0],
        screen[1],
      );
    }
  }

  void _polylineClipped(
    Float64List xy,
    ResolvedStyle style, {
    required bool closed,
    required Bounds2 clip,
  }) {
    final previous = worldClip;
    worldClip = null;
    void segment(double x0, double y0, double x1, double y1) {
      final cut = _clipSegment(x0, y0, x1, y1, clip);
      if (cut == null) return;
      polyline(
        Float64List.fromList([cut.$1, cut.$2, cut.$3, cut.$4]),
        style,
      );
    }

    final count = xy.length ~/ 2;
    for (var i = 0; i + 1 < count; i++) {
      segment(xy[i * 2], xy[i * 2 + 1], xy[(i + 1) * 2], xy[(i + 1) * 2 + 1]);
    }
    if (closed && count > 2) {
      segment(xy[(count - 1) * 2], xy[(count - 1) * 2 + 1], xy[0], xy[1]);
    }
    worldClip = previous;
  }

  /// Cohen–Sutherland clip of one segment against [box], or null if rejected.
  static (double, double, double, double)? _clipSegment(
    double x0,
    double y0,
    double x1,
    double y1,
    Bounds2 box,
  ) {
    var c0 = _outCode(x0, y0, box);
    var c1 = _outCode(x1, y1, box);
    while (true) {
      if ((c0 | c1) == 0) return (x0, y0, x1, y1);
      if ((c0 & c1) != 0) return null;
      final code = c0 != 0 ? c0 : c1;
      late final double x;
      late final double y;
      if (code & 8 != 0) {
        x = x0 + (x1 - x0) * (box.maxY - y0) / (y1 - y0);
        y = box.maxY;
      } else if (code & 4 != 0) {
        x = x0 + (x1 - x0) * (box.minY - y0) / (y1 - y0);
        y = box.minY;
      } else if (code & 2 != 0) {
        y = y0 + (y1 - y0) * (box.maxX - x0) / (x1 - x0);
        x = box.maxX;
      } else {
        y = y0 + (y1 - y0) * (box.minX - x0) / (x1 - x0);
        x = box.minX;
      }
      if (code == c0) {
        x0 = x;
        y0 = y;
        c0 = _outCode(x0, y0, box);
      } else {
        x1 = x;
        y1 = y;
        c1 = _outCode(x1, y1, box);
      }
    }
  }

  static int _outCode(double x, double y, Bounds2 box) {
    var code = 0;
    if (x < box.minX) {
      code |= 1;
    } else if (x > box.maxX) {
      code |= 2;
    }
    if (y < box.minY) {
      code |= 4;
    } else if (y > box.maxY) {
      code |= 8;
    }
    return code;
  }

  @override
  void fill(
    Float64List xy,
    ResolvedStyle style, {
    List<Float64List> holes = const [],
  }) {
    if (xy.length < 6) return;
    final clip = worldClip;
    if (clip != null) {
      var inside = false;
      for (var i = 0; i + 1 < xy.length; i += 2) {
        if (clip.containsPoint(xy[i], xy[i + 1])) {
          inside = true;
          break;
        }
      }
      if (!inside) return;
    }
    final key = _keyFor(style);
    final batch = fillBatches.putIfAbsent(key, () => FillBatch(key));
    batch.addRing(_project(xy));
    for (final hole in holes) {
      if (hole.length >= 6) batch.addRing(_project(hole));
    }
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    final clip = worldClip;
    if (clip != null && !clip.containsPoint(x, y)) return;
    // Point markers get a minimum size so they stay visible and clickable.
    final key = _keyFor(style, extraWidth: pixels.fromLogical(2));
    final batch = pointBatches.putIfAbsent(key, () => PointBatch(key));
    batch.vertices.add2(pixels.xOf(x), pixels.yOf(y));
  }

  @override
  void text(TextGeometry geometry, ResolvedStyle style) {
    if (geometry.text.isEmpty) return;
    final clip = worldClip;
    if (clip != null &&
        !clip.containsPoint(geometry.origin.x, geometry.origin.y)) {
      return;
    }
    final pixelHeight = geometry.height * pixels.scale;
    final color = _colorFor(style);
    if (pixelHeight < minimumTextPixels) {
      // Below a few pixels the glyphs are illegible, but the presence of text
      // is still information. Draw the block it occupies.
      final box = geometry.estimatedBounds();
      if (box.isEmpty) return;
      final key = BatchKey(
        color.withValues(alpha: 0.5),
        0,
        order: drawOrder,
      );
      fillBatches.putIfAbsent(key, () => FillBatch(key)).addRing(
        _project(
          Float64List.fromList([
            box.minX, box.minY,
            box.maxX, box.minY,
            box.maxX, box.maxY,
            box.minX, box.maxY,
          ]),
        ),
      );
      return;
    }
    texts.add(
      TextItem(
        text: geometry.text,
        origin: pixels.offsetOf(geometry.origin),
        pixelHeight: pixelHeight,
        // Screen Y is inverted, so a counter-clockwise drawing rotation
        // becomes a clockwise screen rotation.
        rotation: -geometry.rotation,
        color: color,
        hAlign: geometry.hAlign.index,
        vAlign: geometry.vAlign.index,
        wrapWidth: geometry.rectangleWidth * pixels.scale,
        isMultiline: geometry.isMultiline,
        widthFactor: geometry.widthFactor,
        obliqueAngle: geometry.obliqueAngle,
        tracking: geometry.tracking,
        fontFamily: fonts.resolve(
          styleFont: geometry.fontFamily,
          bigFont: geometry.bigFontFamily,
          text: geometry.text,
        ),
        boxAnchor: geometry.anchor == TextAnchor.box,
        backwards: geometry.backwards,
        upsideDown: geometry.upsideDown,
        underline: geometry.underline,
        overline: geometry.overline,
        strike: geometry.strike,
        order: drawOrder,
      ),
    );
  }

  @override
  void image(ImageGeometry geometry, ResolvedStyle style) {
    final origin = pixels.offsetOf(geometry.origin);
    images.add(
      ImageItem(
        reference: geometry.reference,
        origin: origin,
        uVector: pixels.offsetOf(geometry.origin + geometry.uVector) - origin,
        vVector: pixels.offsetOf(geometry.origin + geometry.vVector) - origin,
        order: drawOrder,
      ),
    );
  }
}
