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
}
