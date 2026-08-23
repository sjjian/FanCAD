import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished mirror direction cannot invent a flip', () {
    final matrix = Mat3.mirror(const Vec2.zero(), const Vec2.zero());
    final image = matrix.transform(const Vec2(3, 2));
    expect(image.x.isFinite, isTrue);
    expect(image.y.isFinite, isTrue);
    expect(image, const Vec2.zero());
  });
}
