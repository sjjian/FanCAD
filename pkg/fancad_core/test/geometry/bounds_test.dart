import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty box cannot invent a size or a hit', () {
    const empty = Bounds2.empty();
    expect(Bounds2.fromPoints(const []), empty);
    expect(empty.width, 0);
    expect(empty.height, 0);
    expect(empty.area, 0);
    expect(empty.intersects(const Bounds2(0, 0, 1, 1)), isFalse);
    expect(empty.containsPoint(0, 0), isFalse);
    expect(empty.containsBox(const Bounds2(0, 0, 1, 1)), isFalse);
    expect(empty.containsBox(empty), isTrue);
    expect(empty.transformed(const Mat3.translation(4, 5)), empty);
    expect(empty.toString(), 'Bounds2.empty');
  });

  test('disjoint boxes cannot invent an intersection', () {
    const left = Bounds2(0, 0, 2, 2);
    const right = Bounds2(3, 0, 5, 2);
    expect(left.intersects(right), isFalse);
    expect(left.containsBox(right), isFalse);
    expect(left.containsPoint(3, 1), isFalse);
    expect(left.union(right), const Bounds2(0, 0, 5, 2));
  });

  test('inflating an empty box cannot invent extents', () {
    const empty = Bounds2.empty();
    expect(empty.inflated(10), empty);
    expect(empty.inflated(-4), empty);
  });

  test('NaN and empty boxes are not finite extents', () {
    expect(const Bounds2.empty().isFinite, isFalse);
    expect(const Bounds2(0, double.nan, 1, 1).isFinite, isFalse);
    expect(const Bounds2(0, 0, 10, 4).isFinite, isTrue);
  });

  test('robust union drops a world-coord outlier among many local boxes', () {
    final boxes = [
      for (var i = 0; i < 20; i++) Bounds2(i * 10, 0, i * 10 + 5, 2),
      const Bounds2(-5e7, -2e7, 6e7, 3e7),
    ];
    final union = Bounds2.robustUnion(boxes);
    expect(union.minX, closeTo(0, 20));
    expect(union.maxX, closeTo(195, 20));
    expect(union.maxY, lessThan(10));
  });

  test('robust union frames insert points when every box is huge', () {
    final boxes = [
      for (var i = 0; i < 20; i++)
        Bounds2(-1e8 + i * 10, 160000, 1e8 + i * 10, 160100),
    ];
    final union = Bounds2.robustUnion(boxes);
    expect(union.width, lessThan(1000));
    expect(union.center.y, closeTo(160050, 100));
  });

  test('a 5-percent tail of far centers cannot stretch Zoom Extents', () {
    final boxes = [
      for (var i = 0; i < 40; i++)
        Bounds2(100.0 * i, 160000, 100.0 * i + 20, 160020),
      for (var i = 0; i < 4; i++)
        Bounds2(100.0 * i, -400000, 100.0 * i + 20, -399980),
    ];
    final union = Bounds2.robustUnion(boxes);
    expect(union.minY, greaterThan(150000));
    expect(union.maxY, lessThan(170000));
    expect(union.minX, lessThan(150));
    expect(union.maxX, greaterThan(3000));
  });

  test('robust union keeps a single large outline on a small drawing', () {
    const outline = Bounds2(0, 0, 400000, 20000);
    expect(
      Bounds2.robustUnion([
        outline,
        const Bounds2(10, 10, 20, 20),
        const Bounds2(30, 10, 40, 20),
      ]),
      outline.union(const Bounds2(10, 10, 40, 20)),
    );
  });

  test('an empty xy buffer cannot invent a box', () {
    expect(Bounds2.fromXY(Float64List(0)).isEmpty, isTrue);
  });

  test('union of an empty box is the other box', () {
    const box = Bounds2(0, 0, 10, 5);
    expect(const Bounds2.empty().union(box), box);
  });

  test('detects intersection and containment', () {
    const outer = Bounds2(0, 0, 10, 10);
    expect(outer.intersects(const Bounds2(5, 5, 15, 15)), isTrue);
    expect(outer.intersects(const Bounds2(11, 11, 12, 12)), isFalse);
    expect(outer.containsBox(const Bounds2(2, 2, 3, 3)), isTrue);
    expect(outer.containsPoint(5, 5), isTrue);
  });

  test('factories and metrics keep the enclosing box', () {
    expect(
      Bounds2.fromPoints(const [Vec2(2, 5), Vec2(-1, 1)]),
      const Bounds2(-1, 1, 2, 5),
    );
    expect(
      Bounds2.fromCorners(const Vec2(4, 1), const Vec2(0, 3)),
      const Bounds2(0, 1, 4, 3),
    );
    const box = Bounds2(0, 0, 10, 4);
    expect(box.union(const Bounds2.empty()), box);
    expect(box.inflated(1), const Bounds2(-1, -1, 11, 5));
    expect(box.center, const Vec2(5, 2));
    expect(box.min, const Vec2.zero());
    expect(box.max, const Vec2(10, 4));
    expect(box.diagonal, closeTo(math.sqrt(116), 1e-12));
    final rotated = box.transformed(Mat3.rotation(math.pi / 2));
    expect(rotated.minX, closeTo(-4, 1e-12));
    expect(rotated.maxY, closeTo(10, 1e-12));
    expect(box.enlargementFor(const Bounds2(8, -2, 12, 1)), greaterThan(0));
    expect(box, const Bounds2(0, 0, 10, 4));
    expect({box}.contains(const Bounds2(0, 0, 10, 4)), isTrue);
  });
}
