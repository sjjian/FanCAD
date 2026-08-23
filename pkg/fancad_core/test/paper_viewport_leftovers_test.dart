import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const viewport = PaperViewport(
    paperBounds: Bounds2(0, 0, 100, 80),
    modelCenter: Vec2(10, 4),
    scale: 2,
  );

  test('a collapsed corner drag cannot invent a zero-area window', () {
    expect(viewport.withGrip(0, const Vec2(100, 80)), viewport);
    expect(viewport.withGrip(1, const Vec2(0, 80)), viewport);
    expect(viewport.withGrip(2, const Vec2(0, 0)), viewport);
    expect(viewport.withGrip(3, const Vec2(100, 0)), viewport);
  });

  test('corner grips resize two sides and keep the model view', () {
    expect(
      viewport.withGrip(0, const Vec2(-10, -8)).paperBounds,
      const Bounds2(-10, -8, 100, 80),
    );
    expect(
      viewport.withGrip(2, const Vec2(120, 90)).paperBounds,
      const Bounds2(0, 0, 120, 90),
    );
    expect(
      viewport.withGrip(0, const Vec2(-10, -8)).modelCenter,
      viewport.modelCenter,
    );
    expect(viewport.withGrip(0, const Vec2(-10, -8)).scale, viewport.scale);
  });

  test(
    'blank frozen names and a missing centre cannot invent viewport data',
    () {
      final restored = PaperViewport.fromJson(const {
        'frozen': ['', '  ', 'DIM', 4],
        'paper': [1, 2],
      });
      expect(restored.frozenLayers, ['DIM']);
      expect(restored.paperBounds, const Bounds2(0, 0, 100, 80));
      expect(restored.modelCenter, const Vec2.zero());

      expect(
        PaperViewport.fromJson(const {'frozen': 'DIM'}).frozenLayers,
        isEmpty,
      );
    },
  );
}
