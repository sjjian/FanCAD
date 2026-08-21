import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'matrix.dart';
import 'vector.dart';

/// An axis-aligned bounding box in model space.
///
/// An empty box is represented by inverted extents so that [union] and
/// [expandToInclude] behave correctly as fold identities.
@immutable
class Bounds2 {
  const Bounds2(this.minX, this.minY, this.maxX, this.maxY);

  const Bounds2.empty()
    : minX = double.infinity,
      minY = double.infinity,
      maxX = double.negativeInfinity,
      maxY = double.negativeInfinity;

  factory Bounds2.fromPoints(Iterable<Vec2> points) {
    var box = const Bounds2.empty();
    for (final p in points) {
      box = box.expandToInclude(p.x, p.y);
    }
    return box;
  }

  factory Bounds2.fromCorners(Vec2 a, Vec2 b) => Bounds2(
    math.min(a.x, b.x),
    math.min(a.y, b.y),
    math.max(a.x, b.x),
    math.max(a.y, b.y),
  );

  /// Builds a box over an interleaved `[x0, y0, x1, y1, ...]` buffer.
  factory Bounds2.fromXY(Float64List xy) {
    if (xy.isEmpty) return const Bounds2.empty();
    var minX = xy[0], minY = xy[1], maxX = xy[0], maxY = xy[1];
    for (var i = 2; i < xy.length; i += 2) {
      final x = xy[i];
      final y = xy[i + 1];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    return Bounds2(minX, minY, maxX, maxY);
  }

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  bool get isEmpty => maxX < minX || maxY < minY;
  bool get isNotEmpty => !isEmpty;

  double get width => isEmpty ? 0 : maxX - minX;
  double get height => isEmpty ? 0 : maxY - minY;
  double get area => width * height;
  double get diagonal => math.sqrt(width * width + height * height);

  Vec2 get center => Vec2((minX + maxX) / 2, (minY + maxY) / 2);
  Vec2 get min => Vec2(minX, minY);
  Vec2 get max => Vec2(maxX, maxY);

  Bounds2 expandToInclude(double x, double y) => Bounds2(
    math.min(minX, x),
    math.min(minY, y),
    math.max(maxX, x),
    math.max(maxY, y),
  );

  Bounds2 union(Bounds2 other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    return Bounds2(
      math.min(minX, other.minX),
      math.min(minY, other.minY),
      math.max(maxX, other.maxX),
      math.max(maxY, other.maxY),
    );
  }

  Bounds2 inflated(double amount) => isEmpty
      ? this
      : Bounds2(
          minX - amount,
          minY - amount,
          maxX + amount,
          maxY + amount,
        );

  bool intersects(Bounds2 other) =>
      isNotEmpty &&
      other.isNotEmpty &&
      minX <= other.maxX &&
      other.minX <= maxX &&
      minY <= other.maxY &&
      other.minY <= maxY;

  bool containsBox(Bounds2 other) =>
      other.isEmpty ||
      (!isEmpty &&
          minX <= other.minX &&
          minY <= other.minY &&
          maxX >= other.maxX &&
          maxY >= other.maxY);

  bool containsPoint(double x, double y) =>
      !isEmpty && x >= minX && x <= maxX && y >= minY && y <= maxY;

  /// The box enclosing this box after applying [m].
  Bounds2 transformed(Mat3 m) {
    if (isEmpty) return this;
    var out = const Bounds2.empty();
    for (final corner in [
      Vec2(minX, minY),
      Vec2(maxX, minY),
      Vec2(maxX, maxY),
      Vec2(minX, maxY),
    ]) {
      final p = m.transform(corner);
      out = out.expandToInclude(p.x, p.y);
    }
    return out;
  }

  /// The extra area required to grow this box so it also covers [other].
  /// Used by the R-tree split heuristic.
  double enlargementFor(Bounds2 other) => union(other).area - area;

  @override
  bool operator ==(Object other) =>
      other is Bounds2 &&
      other.minX == minX &&
      other.minY == minY &&
      other.maxX == maxX &&
      other.maxY == maxY;

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);

  @override
  String toString() => isEmpty
      ? 'Bounds2.empty'
      : 'Bounds2($minX, $minY .. $maxX, $maxY)';
}
