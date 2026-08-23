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
}
