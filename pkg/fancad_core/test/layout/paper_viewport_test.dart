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

  test('a centre grip moves the window and keeps the model view', () {
    const framed = PaperViewport(
      paperBounds: Bounds2(10, 10, 200, 150),
      modelCenter: Vec2(40, 0),
      scale: 0.5,
    );
    expect(framed.grips(), hasLength(9));
    expect(framed.grips()[8], const Vec2(105, 80));

    final grown = framed.withGrip(2, const Vec2(220, 170));
    expect(grown.paperBounds, const Bounds2(10, 10, 220, 170));
    expect(grown.modelCenter, const Vec2(40, 0));
    expect(grown.scale, 0.5);

    final moved = framed.withGrip(8, const Vec2(115, 90));
    expect(moved.paperBounds, const Bounds2(20, 20, 210, 160));
    expect(moved.modelCenter, const Vec2(40, 0));
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
