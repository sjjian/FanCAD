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
/// Line weight is quantised to a device pixel because a 0.18 mm and a 0.20 mm
/// pen are the same single-pixel line at most zoom levels, and merging them
/// removes a draw call for free.
@immutable
class BatchKey {
  const BatchKey(this.color, this.strokeWidth);

  final ui.Color color;
  final double strokeWidth;

  @override
  bool operator ==(Object other) =>
      other is BatchKey &&
      other.color == color &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(color, strokeWidth);

  @override
  String toString() =>
      'BatchKey(#${color.toARGB32().toRadixString(16)}, $strokeWidth)';
}

/// Screen-space line segments sharing one colour and width.
class LineBatch {
  LineBatch(this.key);

  final BatchKey key;
  final Float32Buffer vertices = Float32Buffer();

  int get segmentCount => vertices.length ~/ 4;
  bool get isEmpty => vertices.isEmpty;

  /// Appends a polyline given as screen-space `[x, y, ...]`.
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

/// Screen-space point markers sharing one colour and size.
class PointBatch {
  PointBatch(this.key);

  final BatchKey key;
  final Float32Buffer vertices = Float32Buffer();

  int get pointCount => vertices.length ~/ 2;
  bool get isEmpty => vertices.isEmpty;
}

/// Filled regions sharing one colour, accumulated into a single path.
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

/// A text run ready to paint, in screen space.
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
  });

  final String text;
  final ui.Offset origin;

  /// Cap height in device-independent pixels, already scaled by the viewport.
  final double pixelHeight;

  /// Clockwise screen rotation in radians, already Y-flipped.
  final double rotation;
  final ui.Color color;
  final int hAlign;
  final int vAlign;
  final double wrapWidth;
  final bool isMultiline;
}

/// An image placement ready to paint, in screen space.
@immutable
class ImageItem {
  const ImageItem({
    required this.reference,
    required this.origin,
    required this.uVector,
    required this.vVector,
  });

  final String reference;
  final ui.Offset origin;
  final ui.Offset uVector;
  final ui.Offset vVector;
}
