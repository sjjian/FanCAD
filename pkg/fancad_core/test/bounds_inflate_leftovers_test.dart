import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
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
}
