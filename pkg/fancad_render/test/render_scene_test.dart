import 'dart:math' as math;
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(1000, 800);

  /// A square grid of identically styled lines, ten drawing units apart.
  ///
  /// Square rather than a long strip so that fitting it to a landscape viewport
  /// leaves the lines several pixels long, which is what keeps them out of the
  /// renderer's collapse-to-a-pixel path.
  CadDocument gridDocument(int count, {String layer = '0'}) {
    final document = CadDocument()
      ..putLayer(LayerDef(name: layer, color: const CadColor.indexed(2)));
    final columns = math.sqrt(count).ceil();
    final entities = <CadEntity>[
      for (var i = 0; i < count; i++)
        LineEntity(
          id: i + 1,
          props: EntityProps(layer: layer),
          start: Vec2((i % columns) * 10, (i ~/ columns) * 10),
          end: Vec2((i % columns) * 10 + 8, (i ~/ columns) * 10 + 8),
        ),
    ];
    for (final entity in entities) {
      document.registerImportedEntity(entity);
    }
    document
      ..putBlock(
        BlockRecord(
          name: document.modelSpaceBlockName,
          entityIds: [for (final entity in entities) entity.id],
          isLayoutBlock: true,
        ),
      )
      ..reindex();
    return document;
  }

  test('a small pan can reuse the scene by translating it', () {
    final document = gridDocument(500);
    const view = CadViewport(center: Vec2(100, 0), scale: 2, size: size);
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);

    final nudged = view.panned(const Offset(20, 10));
    expect(scene.covers(nudged), isTrue);
    final placement = scene.placementFor(nudged);
    expect(placement.isTranslation, isTrue);
    expect(placement.offset.dx, closeTo(20, 1e-9));
    expect(placement.offset.dy, closeTo(10, 1e-9));
  });

  test('a zoom is not a translation of the same scene', () {
    final document = gridDocument(50);
    const view = CadViewport(center: Vec2.zero(), scale: 2, size: size);
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.placementFor(view.copyWith(scale: 4)).isTranslation, isFalse);
  });

  test('a pan beyond the overscan cannot reuse the scene', () {
    final document = gridDocument(500);
    const view = CadViewport(center: Vec2(100, 0), scale: 2, size: size);
    final scene = SceneBuilder(palette: AciPalette.dark).build(document, view);
    expect(scene.covers(view.panned(const Offset(5000, 0))), isFalse);
  });

  group('placementFor', () {
    const placed = Size(400, 300);

    CadDocument grid() {
      final document = CadDocument();
      for (var i = 0; i < 20; i++) {
        document.addEntity(
          LineEntity(
            id: i,
            start: Vec2(-100, i * 10 - 100),
            end: Vec2(100, i * 10 - 100),
          ),
        );
      }
      return document;
    }

    test('a pan is a whole number of physical pixels', () {
      const view = CadViewport(
        center: Vec2.zero(),
        scale: 2.5,
        size: placed,
        devicePixelRatio: 2,
      );
      final scene = SceneBuilder(
        palette: AciPalette.dark,
      ).build(grid(), view.pixelLocked());

      // Fractional drags, because a trackpad never delivers whole pixels.
      for (final drag in const [
        Offset(11.4, -3.9),
        Offset(-0.2, 0.7),
        Offset(23.51, 17.49),
      ]) {
        final panned = scene.viewport.panned(drag).pixelLocked();
        final placement = scene.placementFor(panned);
        expect(placement.isTranslation, isTrue);
        expect(
          placement.offset.dx,
          closeTo(placement.offset.dx.roundToDouble(), 1e-6),
        );
        expect(
          placement.offset.dy,
          closeTo(placement.offset.dy.roundToDouble(), 1e-6),
        );
      }
    });

    test('a zoom reports the factor the camera moved by', () {
      const view = CadViewport(center: Vec2.zero(), scale: 2, size: placed);
      final scene = SceneBuilder(palette: AciPalette.dark).build(grid(), view);

      final placement = scene.placementFor(view.copyWith(scale: 3));
      expect(placement.isTranslation, isFalse);
      expect(placement.scale, closeTo(1.5, 1e-12));
    });

    test('the placement puts a drawing point where the new camera would', () {
      const view = CadViewport(
        center: Vec2(4, -2),
        scale: 2,
        size: placed,
        devicePixelRatio: 2,
      );
      final scene = SceneBuilder(
        palette: AciPalette.dark,
      ).build(grid(), view.pixelLocked());
      final zoomed = view.zoomed(1.4, const Offset(120, 90)).pixelLocked();

      // This is why replaying a zoom is a level-of-detail trade and not a
      // guess: the transform is exact, so only the tessellation and the pen
      // width are stale, never where the geometry is.
      const probe = Vec2(17, -11);
      final placement = scene.placementFor(zoomed);
      final replayed =
          scene.viewport.pixels.xOf(probe.x) * placement.scale +
          placement.offset.dx;
      expect(replayed, closeTo(zoomed.pixels.xOf(probe.x), 1e-6));
    });
  });
}
