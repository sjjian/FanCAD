import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty query cannot invent hits', () {
    final index = SpatialIndex()..insert(1, const Bounds2(0, 0, 1, 1));
    expect(index.search(const Bounds2.empty()), isEmpty);
    expect(index.searchContained(const Bounds2.empty()), isEmpty);
    expect(index.isNotEmpty, isTrue);
    expect(index.bounds, const Bounds2(0, 0, 1, 1));
  });

  test('removing an unknown id cannot invent a tombstone', () {
    final index = SpatialIndex();
    index.remove(99);
    expect(index.contains(99), isFalse);
    expect(index.length, 0);
    expect(index.bounds.isEmpty, isTrue);
  });

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
