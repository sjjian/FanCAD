import 'dart:math' as math;
import 'dart:typed_data';

import 'batch.dart';
import 'device_space.dart';

/// Puts thin axis-aligned segments onto the pixel grid.
///
/// Runs once per scene build, over the finished batches, before the scene is
/// frozen. That it runs here and not in the painter is the whole point: the
/// painter runs on every frame, and an alignment recomputed per frame changes
/// with the frame. A pair of close parallels then merges on one frame and
/// splits on the next, which is what made green linework blink while zooming.
///
/// Three rules, applied in order:
///
/// - a segment more than [axisTolerance] off an axis is left where the
///   projection put it, because rounding a shallow run is what turns it into a
///   staircase
/// - an axis-aligned segment moves to where its stroke edges land on pixel
///   boundaries, so a hairline occupies one full column instead of blending
///   across two
/// - two overlapping parallels closer together than the pen is wide go onto
///   the same line
///
/// The third rule is level of detail, not a repair. At that zoom the gap is
/// narrower than the thinnest line the display can draw, so the alternative is
/// not "two lines", it is two lines that appear and disappear depending on
/// where the pair happens to fall on the pixel grid.
class LineAligner {
  /// How far off an axis a segment may be and still count as axis-aligned, in
  /// physical pixels. A deviation this small cannot be seen; a larger one
  /// would show up as a step.
  static const double axisTolerance = 0.25;

  /// Gaps below this fraction of the pen width always merge, and gaps above
  /// [splitAbove] never do. Inside the band the previous answer is kept, so a
  /// pair sitting near the threshold does not change its mind when a curve is
  /// re-flattened at a different tolerance or the wheel is nudged back and
  /// forth. With no previous answer the decision falls back to one pen width,
  /// which is the point below which the grid cannot represent the gap.
  static const double mergeBelow = 0.6;
  static const double splitAbove = 1.4;

  /// Strokes wider than this are left alone: they already cover whole columns,
  /// and moving them would displace geometry the user can measure.
  static const double widestAligned = 2.5;

  Map<int, bool> _previous = {};
  Map<int, bool> _current = {};

  /// Indices into the vertex buffer of the axis-aligned segments, reused
  /// between batches so a large drawing does not allocate per batch.
  final List<int> _starts = <int>[];
  Float32List _cross = Float32List(0);
  Float32List _assigned = Float32List(0);

  /// Remembered merge decisions, for the leftover tests and diagnostics.
  int get decisionCount => _current.length;

  void clear() {
    _previous = {};
    _current = {};
  }

  /// Aligns every batch in place. Vertex buffers are mutated.
  void align({
    required Iterable<LineBatch> lines,
    required Iterable<PointBatch> points,
    required PixelSpace pixels,
  }) {
    // Swap rather than clear so pairs that left the view stop costing memory,
    // while the pairs still on screen keep their answer from the last build.
    final stale = _previous;
    _previous = _current;
    _current = stale..clear();

    for (final batch in lines) {
      _alignLines(batch, pixels);
    }
    for (final batch in points) {
      final xy = batch.vertices.view;
      for (var i = 0; i < xy.length; i++) {
        xy[i] = PixelSpace.centre(xy[i]);
      }
    }
  }

  void _alignLines(LineBatch batch, PixelSpace pixels) {
    final xy = batch.vertices.view;
    if (xy.isEmpty) return;
    // Zero is the hairline sentinel, which the painter draws one pixel wide.
    final width = batch.key.strokeWidth <= 0 ? 1.0 : batch.key.strokeWidth;
    if (width > widestAligned) return;

    _resolve(xy, pixels, batch.key, width, horizontal: true);
    _resolve(xy, pixels, batch.key, width, horizontal: false);
  }

  /// Aligns the segments running along one axis.
  ///
  /// `horizontal` segments have a constant Y, so Y is the coordinate that
  /// moves and X gives the run they overlap on; vertical is the mirror image.
  void _resolve(
    Float32List xy,
    PixelSpace pixels,
    BatchKey key,
    double width, {
    required bool horizontal,
  }) {
    _starts.clear();
    for (var i = 0; i + 3 < xy.length; i += 4) {
      final along = (xy[i + 2] - xy[i]).abs();
      final across = (xy[i + 3] - xy[i + 1]).abs();
      if (horizontal) {
        if (across <= axisTolerance && across <= along) _starts.add(i);
      } else {
        if (along <= axisTolerance && along <= across) _starts.add(i);
      }
    }
    if (_starts.isEmpty) return;

    final crossOffset = horizontal ? 1 : 0;
    final alongOffset = horizontal ? 0 : 1;

    double crossOf(int start) =>
        (xy[start + crossOffset] + xy[start + 2 + crossOffset]) * 0.5;

    _starts.sort((a, b) => crossOf(a).compareTo(crossOf(b)));

    if (_cross.length < _starts.length) {
      _cross = Float32List(_starts.length);
      _assigned = Float32List(_starts.length);
    }

    // Merging is decided by the projected gap between two lines, never by
    // which pixel each one's `floor()` happens to land in. The latter is what
    // made a pair 0.8 px apart straddling a pixel edge read as two rows on one
    // frame and one row on the next.
    final mergeGap = math.max(1.0, width);

    // Anything past the top of the hysteresis band is certainly a split, so
    // the neighbour search can stop there. Stopping at one pen width instead
    // would mean a pair inside the band never reached the decision at all.
    final searchGap = mergeGap * splitAbove;

    for (var i = 0; i < _starts.length; i++) {
      final start = _starts[i];
      final cross = crossOf(start);
      final lo = math.min(xy[start + alongOffset], xy[start + 2 + alongOffset]);
      final hi = math.max(xy[start + alongOffset], xy[start + 2 + alongOffset]);
      _cross[i] = cross;

      var target = PixelSpace.strokeCentre(cross, width);
      for (var j = i - 1; j >= 0; j--) {
        final gap = cross - _cross[j];
        if (gap >= searchGap) break;
        final other = _starts[j];
        final otherLo = math.min(
          xy[other + alongOffset],
          xy[other + 2 + alongOffset],
        );
        final otherHi = math.max(
          xy[other + alongOffset],
          xy[other + 2 + alongOffset],
        );
        // Two parallels only compete for a pixel where they overlap. Rules on
        // opposite sides of a title block are not the same line.
        if (lo >= otherHi || otherLo >= hi) continue;
        if (!_merges(
          key: key,
          horizontal: horizontal,
          worldGap: pixels.scale > 0 ? gap / pixels.scale : gap,
          ratio: gap / mergeGap,
        )) {
          continue;
        }
        target = _assigned[j];
        break;
      }

      _assigned[i] = target;
      xy[start + crossOffset] = target;
      xy[start + 2 + crossOffset] = target;
    }
  }

  bool _merges({
    required BatchKey key,
    required bool horizontal,
    required double worldGap,
    required double ratio,
  }) {
    final pairKey = _pairKey(key, worldGap, horizontal);
    final merge = switch (ratio) {
      // Outside the band the answer is forced, but it is still recorded: that
      // is how the next build inside the band knows which side it came from.
      < mergeBelow => true,
      > splitAbove => false,
      _ => _previous[pairKey] ?? ratio < 1,
    };
    _current[pairKey] = merge;
    return merge;
  }

  /// Identifies a pair of parallels by how far apart they are in the drawing.
  ///
  /// Not by where they sit. The vertex buffers are single precision, so
  /// inverting the projection recovers a position with an error that grows
  /// with the screen origin and shrinks with the zoom — at one zoom level the
  /// key would simply miss. A gap survives the round trip because the origin
  /// cancels in the subtraction.
  ///
  /// Two unrelated pairs with the same drawing gap share an entry, which costs
  /// nothing: at a given zoom they have the same ratio and would have reached
  /// the same answer anyway.
  int _pairKey(BatchKey key, double worldGap, bool horizontal) =>
      Object.hash(key, _quantise(worldGap), horizontal);

  /// Four significant digits: coarse enough to absorb the single-precision
  /// noise in a re-projected gap, fine enough to keep a 2 mm seam and a 2.1 mm
  /// one apart.
  static int _quantise(double value) {
    if (!value.isFinite || value <= 0) return 0;
    var unit = 1e-12;
    while (unit * 1e4 < value) {
      unit *= 10;
    }
    return (value / unit).round();
  }
}
