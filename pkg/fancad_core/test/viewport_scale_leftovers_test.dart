import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a zero viewport scale cannot invent a model window', () {
    const viewport = PaperViewport(
      paperBounds: Bounds2(0, 0, 100, 80),
      modelCenter: Vec2(10, 4),
      scale: 0,
    );
    expect(viewport.modelWindow.isEmpty, isTrue);
    expect(viewport.paperToModel(), isNull);
  });
}
