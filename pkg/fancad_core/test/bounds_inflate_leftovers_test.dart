import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('inflating an empty box cannot invent extents', () {
    const empty = Bounds2.empty();
    expect(empty.inflated(10), empty);
    expect(empty.inflated(-4), empty);
  });
}
