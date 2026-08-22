import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const viewport = PaperViewport(
    paperBounds: Bounds2(0, 0, 100, 80),
    modelCenter: Vec2(10, 4),
    scale: 2,
  );

  test('VPLAYER freeze is case-insensitive', () {
    final frozen = viewport.copyWith(frozenLayers: const ['Walls', 'DIM']);
    expect(frozen.hidesLayer('walls'), isTrue);
    expect(frozen.hidesLayer('0'), isFalse);
    expect(viewport.hidesLayer('Walls'), isFalse);
  });

  test('model and paper transforms invert each other', () {
    const paper = Vec2(50, 40);
    final model = viewport.paperToModel()!.transform(paper);
    expect(model.x, closeTo(10, 1e-12));
    expect(model.y, closeTo(4, 1e-12));
    final back = viewport.modelToPaper().transform(const Vec2(10, 4));
    expect(back.x, closeTo(50, 1e-12));
    expect(back.y, closeTo(40, 1e-12));
    expect(
      viewport.copyWith(scale: 0).paperToModel(),
      isNull,
    );
  });

  test('the model window is the paper rectangle mapped through scale', () {
    expect(viewport.modelWindow, const Bounds2(-15, -16, 35, 24));
    expect(viewport.copyWith(scale: 0).modelWindow, const Bounds2.empty());
  });

  test('edge grips resize one side and a zero-area drag is ignored', () {
    expect(
      viewport.withGrip(4, const Vec2(50, -10)).paperBounds,
      const Bounds2(0, -10, 100, 80),
    );
    expect(
      viewport.withGrip(5, const Vec2(120, 40)).paperBounds,
      const Bounds2(0, 0, 120, 80),
    );
    expect(
      viewport.withGrip(6, const Vec2(50, 90)).paperBounds,
      const Bounds2(0, 0, 100, 90),
    );
    expect(
      viewport.withGrip(7, const Vec2(-10, 40)).paperBounds,
      const Bounds2(-10, 0, 100, 80),
    );
    expect(viewport.withGrip(4, const Vec2(50, 80)), viewport);
    expect(viewport.withGrip(99, const Vec2(1, 1)), viewport);
  });

  test('JSON keeps off, lock and frozen layers', () {
    final original = viewport.copyWith(
      isOn: false,
      locked: true,
      layer: 'VP',
      frozenLayers: const ['A'],
      rotation: math.pi / 2,
    );
    final restored = PaperViewport.fromJson(original.toJson());
    expect(restored.isOn, isFalse);
    expect(restored.locked, isTrue);
    expect(restored.layer, 'VP');
    expect(restored.frozenLayers, ['A']);
    expect(restored.rotation, closeTo(math.pi / 2, 1e-12));
    expect(PaperViewport.fromJson(const {}).paperBounds, const Bounds2(0, 0, 100, 80));
  });

  test('a model-space double-click zooms extents when not maximized', () {
    expect(
      canvasDoubleClick(
        layout: const Layout(
          name: 'Model',
          blockName: '*Model_Space',
          isModelSpace: true,
        ),
        point: const Vec2.zero(),
      ).id,
      'view.zoomExtents',
    );
  });
}
