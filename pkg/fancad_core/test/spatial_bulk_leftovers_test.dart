import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a bulk load of empty boxes cannot invent window hits', () {
    final index = SpatialIndex()
      ..bulkLoad({
        1: const Bounds2.empty(),
        2: const Bounds2.empty(),
      });
    expect(index.length, 2);
    expect(index.search(const Bounds2(-10, -10, 10, 10)), isEmpty);
    expect(index.searchPoint(0, 0, 1), isEmpty);
  });

  test('a NaN box cannot hide neighbours from a window query', () {
    final index = SpatialIndex()
      ..bulkLoad({
        1: const Bounds2(0, 0, 1, 1),
        2: const Bounds2(0, double.nan, 1, 1),
        3: const Bounds2(10, 10, 11, 11),
      });
    expect(index.search(const Bounds2(-1, -1, 2, 2)), [1]);
    expect(index.search(const Bounds2(9, 9, 12, 12)), [3]);
  });
}
