import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';

/// A growable `Float32List`.
///
/// The renderer's inner loop appends screen coordinates a few at a time and
/// then hands the whole thing to `Canvas.drawRawPoints`, which wants a
/// `Float32List`. A `List<double>` would allocate a box per coordinate, and
/// `Float32List.fromList` at the end would copy everything twice.
class Float32Buffer {
  Float32Buffer([int initialCapacity = 1024])
    : _data = Float32List(initialCapacity);

  Float32List _data;
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isNotEmpty => !isEmpty;

  /// A view of the filled region. Valid until the next append.
  Float32List get view => Float32List.sublistView(_data, 0, _length);

  void add2(double x, double y) {
    _ensure(2);
    _data[_length++] = x;
    _data[_length++] = y;
  }

  void add4(double x0, double y0, double x1, double y1) {
    _ensure(4);
    _data[_length++] = x0;
    _data[_length++] = y0;
    _data[_length++] = x1;
    _data[_length++] = y1;
  }

  void clear() => _length = 0;

  void _ensure(int extra) {
    if (_length + extra <= _data.length) return;
    var capacity = _data.isEmpty ? 1024 : _data.length;
    while (capacity < _length + extra) {
      capacity *= 2;
    }
    final grown = Float32List(capacity)..setRange(0, _length, _data);
    _data = grown;
  }
}

/// The identity of a draw call: primitives sharing one of these are merged.
///
/// [strokeWidth] is in physical pixels, and 0 is the hairline sentinel — the
/// thinnest solid line the display has, which the painter draws as exactly one
/// physical pixel. A 0.18 mm and a 0.20 mm pen are both that line at most zoom
/// levels, and merging them removes a draw call for free.
///
/// [order] is the drawing-order bucket, so geometry that has to sit on top of
/// other geometry cannot be merged underneath it.
@immutable
class BatchKey {
  const BatchKey(this.color, this.strokeWidth, {this.order = 0});

  final ui.Color color;
  final double strokeWidth;
  final int order;

  @override
  bool operator ==(Object other) =>
      other is BatchKey &&
      other.color == color &&
      other.strokeWidth == strokeWidth &&
      other.order == order;

  @override
  int get hashCode => Object.hash(color, strokeWidth, order);

  @override
  String toString() =>
      'BatchKey(#${color.toARGB32().toRadixString(16)}, $strokeWidth'
      '${order == 0 ? '' : ', order $order'})';
}

/// Reusable buffers for [LineBatch.removeOverlaps].
///
/// A sheet set has one batch per colour and width, and a fresh hash table per
/// batch per build was twelve milliseconds of a 200,000 segment rebuild. The
/// buffers only grow, and a build is single-threaded, so one of these on the
/// builder serves every batch.
class BatchScratch {
  Int32List keys = Int32List(0);
  Int32List table = Int32List(0);
}

/// Line segments in physical pixels, sharing one colour and width.
class LineBatch {
  LineBatch(this.key);

  final BatchKey key;
  final Float32Buffer vertices = Float32Buffer();

  int get segmentCount => vertices.length ~/ 4;
  bool get isEmpty => vertices.isEmpty;

  /// How close, in physical pixels, a vertex may be to the last one kept
  /// before it is skipped. The run it belonged to then deviates from the
  /// drawn segment by less than this, which no display can show.
  static const double mergeDistance = 1.0;

  /// Marks a [removeOverlaps] key as a pixel cell rather than two endpoints.
  static const int _pixelKey = -0x80000000;

  /// Bounds of the kept segments, in physical pixels, or null until
  /// [removeOverlaps] has run (a batch a test built by hand).
  ///
  /// The painter uses it to tell "all of this batch is on screen" from "part
  /// of it is", which is what decides whether a zoomed repaint can hand the
  /// whole buffer to `drawRawPoints` instead of copying the visible segments
  /// into a scratch buffer first.
  ui.Rect? bounds;

  /// Side of the visibility grid [indexCells] builds.
  static const int gridSide = 4;

  /// Batches below this size skip the grid: scanning a few hundred segments
  /// costs less than the extra draw calls a grid would make.
  static const int minimumIndexedSegments = 256;

  static const int _gridCells = gridSide * gridSide;

  /// Segment ranges of the visibility grid, or null until [indexCells] runs.
  ///
  /// Entry `c` through `c + 1` is cell `c`; entry [_gridCells] starts the tail
  /// of segments that span more than one cell.
  Int32List? _cellStarts;

  /// Bounds of each cell, in physical pixels, when [_cellStarts] is set.
  List<ui.Rect>? _cellBounds;

  /// Bounds of the spanning tail, or null when that tail is empty.
  ui.Rect? _wideBounds;

  /// Whether the batch was cut into a grid, which lets the painter skip whole
  /// cells instead of testing every segment against its window.
  bool get hasCells => _cellStarts != null;
  Int32List? get cellStarts => _cellStarts;
  List<ui.Rect>? get cellBounds => _cellBounds;
  ui.Rect? get wideBounds => _wideBounds;

  /// Appends a polyline given as `[x, y, ...]` in physical pixels.
  ///
  /// Vertices stay where the projection put them; only the ones closer than
  /// [mergeDistance] to the vertex before are dropped, the last one included.
  /// A zoomed-out curve or glyph is otherwise dozens of segments inside a
  /// single pixel, and a run that ends a fraction of a pixel past the last
  /// kept point would add a stub that no display can show. Stretching a
  /// sub-pixel stub to a 1 px tick would invent a notch that is not in the
  /// drawing, so a polyline that collapses entirely keeps its first segment.
  void addPolyline(Float32List screen, {bool closed = false}) {
    final count = screen.length ~/ 2;
    if (count < 2) return;
    const limit = mergeDistance * mergeDistance;
    final before = vertices.length;
    var keptX = screen[0];
    var keptY = screen[1];
    for (var i = 1; i < count; i++) {
      final x = screen[i * 2];
      final y = screen[i * 2 + 1];
      final dx = x - keptX, dy = y - keptY;
      if (dx * dx + dy * dy < limit) continue;
      vertices.add4(keptX, keptY, x, y);
      keptX = x;
      keptY = y;
    }
    if (closed && count > 2) {
      final dx = screen[0] - keptX, dy = screen[1] - keptY;
      if (dx * dx + dy * dy >= limit) {
        vertices.add4(keptX, keptY, screen[0], screen[1]);
      }
    }
    if (vertices.length == before) {
      vertices.add4(screen[0], screen[1], screen[2], screen[3]);
    }
  }

  /// Drops segments that coincide with one already in the batch, to an eighth
  /// of a physical pixel and in either direction. A segment shorter than a
  /// pixel only marks the pixel it sits in, so one per pixel is kept.
  ///
  /// Sheet sets overlay the same outline many times over (a border in every
  /// sheet block, a hatch boundary on its polyline), alignment snaps close
  /// parallels onto the same pixel row, and a zoomed-out glyph or hatch is a
  /// cloud of sub-pixel strokes. Overlapping copies paint the same pixels, and
  /// anti-aliased edges drawn twice only get darker.
  void removeOverlaps([BatchScratch? scratch]) {
    final count = segmentCount;
    if (count < 2) {
      bounds = _measure();
      return;
    }
    final xy = vertices._data;
    var keys = scratch?.keys ?? Int32List(0);
    if (keys.length < count * 4) keys = Int32List(count * 4);
    var capacity = 1;
    while (capacity < count * 2) {
      capacity <<= 1;
    }
    var table = scratch?.table ?? Int32List(0);
    if (table.length < capacity) table = Int32List(capacity);
    table.fillRange(0, capacity, -1);
    if (scratch != null) {
      scratch
        ..keys = keys
        ..table = table;
    }
    final mask = capacity - 1;
    var kept = 0;
    for (var s = 0; s < count; s++) {
      final o = s * 4;
      final dx = xy[o + 2] - xy[o], dy = xy[o + 3] - xy[o + 1];
      int ax, ay, bx, by;
      if (dx * dx + dy * dy < 1) {
        ax = ((xy[o] + xy[o + 2]) * 0.5).floor();
        ay = ((xy[o + 1] + xy[o + 3]) * 0.5).floor();
        bx = by = _pixelKey;
      } else {
        ax = (xy[o] * 8).round();
        ay = (xy[o + 1] * 8).round();
        bx = (xy[o + 2] * 8).round();
        by = (xy[o + 3] * 8).round();
        if (ax > bx || (ax == bx && ay > by)) {
          (ax, ay, bx, by) = (bx, by, ax, ay);
        }
      }
      var slot = Object.hash(ax, ay, bx, by) & mask;
      var duplicate = false;
      while (true) {
        final other = table[slot];
        if (other < 0) break;
        final k = other * 4;
        if (keys[k] == ax &&
            keys[k + 1] == ay &&
            keys[k + 2] == bx &&
            keys[k + 3] == by) {
          duplicate = true;
          break;
        }
        slot = (slot + 1) & mask;
      }
      if (duplicate) continue;
      table[slot] = kept;
      final k = kept * 4;
      keys[k] = ax;
      keys[k + 1] = ay;
      keys[k + 2] = bx;
      keys[k + 3] = by;
      if (kept != s) {
        xy[k] = xy[o];
        xy[k + 1] = xy[o + 1];
        xy[k + 2] = xy[o + 2];
        xy[k + 3] = xy[o + 3];
      }
      kept++;
    }
    vertices._length = kept * 4;
    bounds = _measure();
  }

  /// Union of the kept segments, in physical pixels, or null when the buffer
  /// holds no whole segment.
  ui.Rect? _measure() {
    final xy = vertices._data;
    final length = vertices._length;
    if (length < 4) return null;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (var i = 0; i + 3 < length; i += 4) {
      for (var k = 0; k < 4; k += 2) {
        final x = xy[i + k], y = xy[i + k + 1];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Sorts the segments into a [gridSide] x [gridSide] grid over [bounds], so
  /// a zoomed repaint can skip whole cells instead of testing every segment
  /// against its window.
  ///
  /// A segment whose bounding box sits inside one cell joins that cell. A
  /// segment that spans cells joins the tail instead, because drawing it with
  /// any single cell could drop it while part of it is still on screen. Every
  /// segment ends up in exactly one place, so a cell can be drawn from a
  /// contiguous range of the vertex buffer with no copy and no double paint.
  ///
  /// Runs after [removeOverlaps], which is what [bounds] comes from.
  void indexCells() {
    final count = segmentCount;
    if (count < minimumIndexedSegments) return;
    final box = bounds ?? _measure();
    if (box == null || !(box.width > 0) || !(box.height > 0)) return;

    final cellWidth = box.width / gridSide;
    final cellHeight = box.height / gridSide;
    final xy = vertices._data;

    // Where each segment belongs, then the offset each bucket starts at.
    final bucketOf = Int32List(count);
    final counts = Int32List(_gridCells + 1);
    int column(double x) =>
        ((x - box.left) / cellWidth).floor().clamp(0, gridSide - 1);
    int row(double y) =>
        ((y - box.top) / cellHeight).floor().clamp(0, gridSide - 1);
    for (var s = 0; s < count; s++) {
      final o = s * 4;
      final x0 = xy[o], y0 = xy[o + 1], x1 = xy[o + 2], y1 = xy[o + 3];
      final cx0 = column(math.min(x0, x1));
      final cx1 = column(math.max(x0, x1));
      final cy0 = row(math.min(y0, y1));
      final cy1 = row(math.max(y0, y1));
      final bucket = cx0 == cx1 && cy0 == cy1
          ? cy0 * gridSide + cx0
          : _gridCells;
      bucketOf[s] = bucket;
      counts[bucket]++;
    }

    final starts = Int32List(_gridCells + 1);
    var at = 0;
    for (var c = 0; c <= _gridCells; c++) {
      starts[c] = at;
      at += counts[c];
    }

    // Stable placement into the new order, then straight back into the buffer.
    final sorted = Float32List(count * 4);
    final cursor = Int32List.fromList(starts);
    for (var s = 0; s < count; s++) {
      final to = cursor[bucketOf[s]] * 4;
      final from = s * 4;
      sorted[to] = xy[from];
      sorted[to + 1] = xy[from + 1];
      sorted[to + 2] = xy[from + 2];
      sorted[to + 3] = xy[from + 3];
      cursor[bucketOf[s]]++;
    }
    xy.setRange(0, count * 4, sorted);

    _cellStarts = starts;
    _cellBounds = List.generate(_gridCells, (c) {
      final left = box.left + (c % gridSide) * cellWidth;
      final top = box.top + (c ~/ gridSide) * cellHeight;
      // A pixel of slack: a segment on the shared edge of two cells rounds
      // into one of them, and the cell it left must still claim the window.
      return ui.Rect.fromLTRB(
        left - 1,
        top - 1,
        left + cellWidth + 1,
        top + cellHeight + 1,
      );
    });

    final wideStart = starts[_gridCells];
    if (wideStart >= count) {
      _wideBounds = null;
      return;
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (var o = wideStart * 4; o + 3 < count * 4; o += 4) {
      for (var k = 0; k < 4; k += 2) {
        final x = xy[o + k], y = xy[o + k + 1];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    _wideBounds = ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Point markers in physical pixels, sharing one colour and size.
class PointBatch {
  PointBatch(this.key);

  final BatchKey key;
  final Float32Buffer vertices = Float32Buffer();

  int get pointCount => vertices.length ~/ 2;
  bool get isEmpty => vertices.isEmpty;
}

/// Filled regions in physical pixels, accumulated into a single path per
/// colour.
class FillBatch {
  FillBatch(this.key);

  final BatchKey key;
  final ui.Path path = ui.Path()..fillType = ui.PathFillType.evenOdd;
  int ringCount = 0;

  bool get isEmpty => ringCount == 0;

  void addRing(Float32List screen) {
    final count = screen.length ~/ 2;
    if (count < 3) return;
    path.moveTo(screen[0], screen[1]);
    for (var i = 1; i < count; i++) {
      path.lineTo(screen[i * 2], screen[i * 2 + 1]);
    }
    path.close();
    ringCount++;
  }
}

/// A text run ready to paint, in physical pixels.
@immutable
class TextItem {
  const TextItem({
    required this.text,
    required this.origin,
    required this.pixelHeight,
    required this.rotation,
    required this.color,
    required this.hAlign,
    required this.vAlign,
    this.wrapWidth = 0,
    this.isMultiline = false,
    this.widthFactor = 1,
    this.obliqueAngle = 0,
    this.tracking = 1,
    this.fontFamily = '',
    this.boxAnchor = false,
    this.backwards = false,
    this.upsideDown = false,
    this.underline = false,
    this.overline = false,
    this.strike = false,
    this.order = 0,
  });

  final String text;
  final ui.Offset origin;

  /// Drawing-order bucket, matching [BatchKey.order].
  final int order;

  /// Cap height in physical pixels, already scaled by the viewport.
  final double pixelHeight;

  /// Clockwise screen rotation in radians, already Y-flipped.
  final double rotation;
  final ui.Color color;
  final int hAlign;
  final int vAlign;
  final double wrapWidth;
  final bool isMultiline;
  final double widthFactor;
  final double obliqueAngle;
  final double tracking;

  /// Resolved system face. Empty means the painter's fallback family.
  final String fontFamily;

  /// True for MTEXT: [origin] is a box attachment, not a TEXT baseline.
  final bool boxAnchor;
  final bool backwards;
  final bool upsideDown;
  final bool underline;
  final bool overline;
  final bool strike;
}

/// An image placement ready to paint, in physical pixels.
@immutable
class ImageItem {
  const ImageItem({
    required this.reference,
    required this.origin,
    required this.uVector,
    required this.vVector,
    this.order = 0,
  });

  final String reference;
  final ui.Offset origin;
  final ui.Offset uVector;
  final ui.Offset vVector;

  /// Drawing-order bucket, matching [BatchKey.order].
  final int order;
}
