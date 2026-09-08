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

  test('finds only the entities inside the query box', () {
    final index = SpatialIndex();
    final entries = <int, Bounds2>{
      for (var i = 0; i < 500; i++)
        i: Bounds2(i * 10, 0, i * 10 + 5, 5),
    };
    index.bulkLoad(entries);
    final hits = index.search(const Bounds2(95, 0, 125, 5)).toList()..sort();
    expect(hits, [9, 10, 11, 12]);
  });

  test('reflects incremental inserts and removals', () {
    final index = SpatialIndex()
      ..bulkLoad({1: const Bounds2(0, 0, 1, 1)})
      ..insert(2, const Bounds2(5, 5, 6, 6));
    expect(index.search(const Bounds2(4, 4, 7, 7)), contains(2));
    index.remove(2);
    expect(index.search(const Bounds2(4, 4, 7, 7)), isEmpty);
  });

  test('window search requires full containment', () {
    final index = SpatialIndex()
      ..bulkLoad({
        1: const Bounds2(0, 0, 2, 2),
        2: const Bounds2(1, 1, 9, 9),
      });
    expect(
      index.searchContained(const Bounds2(0, 0, 4, 4)),
      [1],
    );
  });

  test('point search expands the query by the snap tolerance', () {
    final index = SpatialIndex()
      ..bulkLoad({1: const Bounds2(10, 10, 11, 11)});
    expect(index.searchPoint(10.5, 10.5, 1), contains(1));
    expect(index.searchPoint(0, 0, 1), isEmpty);
  });

  test('update moves an id and empty boxes never hit a window', () {
    final index = SpatialIndex()
      ..insert(1, const Bounds2(0, 0, 1, 1))
      ..update(1, const Bounds2(20, 20, 21, 21))
      ..insert(2, const Bounds2.empty());
    expect(index.contains(1), isTrue);
    expect(index.boundsOf(1), const Bounds2(20, 20, 21, 21));
    expect(index.search(const Bounds2(19, 19, 22, 22)), [1]);
    expect(index.search(const Bounds2(-1, -1, 2, 2)), isEmpty);
    expect(index.ids.toSet(), {1, 2});
    expect(index.length, 2);
    index.clear();
    expect(index.isEmpty, isTrue);
  });

  test('bounds ignore removed packed entries until rebuild', () {
    final index = SpatialIndex(nodeCapacity: 4);
    for (var i = 0; i < 20; i++) {
      index.insert(i, Bounds2(i * 2, 0, i * 2 + 1, 1));
    }
    index.rebuild();
    expect(index.bounds.isNotEmpty, isTrue);
    index.remove(0);
    expect(index.contains(0), isFalse);
    expect(index.search(const Bounds2(-1, -1, 1.5, 1.5)), isEmpty);
  });
}
