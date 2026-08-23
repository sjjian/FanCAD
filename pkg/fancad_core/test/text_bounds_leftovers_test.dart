import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty text cannot invent a width', () {
    const geometry = TextGeometry(
      text: '',
      origin: Vec2.zero(),
      height: 10,
      rotation: 0,
      styleName: 'Standard',
    );
    final box = geometry.estimatedBounds();
    expect(box.width, 0);
    expect(box.height, closeTo(12, 1e-9));
  });
}
