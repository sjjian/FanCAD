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

/// Line segments in physical pixels, sharing one colour and width.
class LineBatch {
  LineBatch(this.key);

  final BatchKey key;
  final Float32Buffer vertices = Float32Buffer();

  int get segmentCount => vertices.length ~/ 4;
  bool get isEmpty => vertices.isEmpty;

  /// Appends a polyline given as `[x, y, ...]` in physical pixels.
  ///
  /// Vertices stay where the projection put them. Stretching a sub-pixel
  /// stub to a 1 px tick would invent a notch that is not in the drawing.
  void addPolyline(Float32List screen, {bool closed = false}) {
    final count = screen.length ~/ 2;
    if (count < 2) return;
    for (var i = 0; i + 1 < count; i++) {
      vertices.add4(
        screen[i * 2],
        screen[i * 2 + 1],
        screen[(i + 1) * 2],
        screen[(i + 1) * 2 + 1],
      );
    }
    if (closed && count > 2) {
      vertices.add4(
        screen[(count - 1) * 2],
        screen[(count - 1) * 2 + 1],
        screen[0],
        screen[1],
      );
    }
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
