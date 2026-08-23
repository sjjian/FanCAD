import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty freeze list cannot invent a hidden layer', () {
    const viewport = PaperViewport(
      paperBounds: Bounds2(0, 0, 100, 80),
      modelCenter: Vec2.zero(),
    );
    expect(viewport.hidesLayer('WALLS'), isFalse);
    expect(
      const PaperViewport(
        paperBounds: Bounds2(0, 0, 100, 80),
        modelCenter: Vec2.zero(),
        frozenLayers: ['walls'],
      ).hidesLayer('WALLS'),
      isTrue,
    );
  });
}
