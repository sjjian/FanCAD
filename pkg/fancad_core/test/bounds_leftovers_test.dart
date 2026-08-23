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
}
