import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PixelSpace', () {
    test('centre is the middle of the pixel a coordinate falls in', () {
      expect(PixelSpace.centre(20), 20.5);
      expect(PixelSpace.centre(20.4), 20.5);
      expect(PixelSpace.centre(20.999), 20.5);
      expect(PixelSpace.centre(-0.2), -0.5);
    });

    test('an odd pen wants a pixel centre and an even pen a boundary', () {
      // Both edges of the stroke have to land on pixel boundaries. For a
      // one-pixel pen that means a centre; for a two-pixel pen it means the
      // seam between two pixels. Putting a two-pixel pen on a centre would
      // spread it over three columns at partial coverage.
      expect(PixelSpace.strokeCentre(20.3, 1), 20.5);
      expect(PixelSpace.strokeCentre(20.3, 2), 20.0);
      expect(PixelSpace.strokeCentre(20.3, 3), 20.5);
      expect(PixelSpace.strokeCentre(20.8, 2), 21.0);
    });

    test('the mapping agrees with the viewport and round trips', () {
      const view = CadViewport(
        center: Vec2(5, -3),
        scale: 2.5,
        size: Size(300, 200),
        devicePixelRatio: 2,
      );
      final pixels = view.pixels;

      expect(pixels.scale, closeTo(5, 1e-12));
      final logical = view.toScreen(const Vec2(11, 7));
      expect(pixels.xOf(11), closeTo(logical.dx * 2, 1e-9));
      expect(pixels.yOf(7), closeTo(logical.dy * 2, 1e-9));

      expect(pixels.worldXOf(pixels.xOf(11)), closeTo(11, 1e-9));
      expect(pixels.worldYOf(pixels.yOf(7)), closeTo(7, 1e-9));
    });
  });

  group('pixelLocked', () {
    /// Cameras chosen so the screen origin lands off the grid by a different
    /// fraction each time.
    const cameras = [
      CadViewport(
        center: Vec2(0.3333, -1.777),
        scale: 3.5,
        size: Size(801, 601),
      ),
      CadViewport(
        center: Vec2(-12345.6789, 9876.54321),
        scale: 0.017,
        size: Size(1024, 768),
        devicePixelRatio: 2,
      ),
      CadViewport(
        center: Vec2(1e6 + 0.4, -1e6 - 0.6),
        scale: 137.25,
        size: Size(1600, 900),
        devicePixelRatio: 3,
      ),
    ];

    test('the screen origin lands on a whole physical pixel', () {
      for (final camera in cameras) {
        final pixels = camera.pixelLocked().pixels;
        expect(pixels.originX, closeTo(pixels.originX.roundToDouble(), 1e-6));
        expect(pixels.originY, closeTo(pixels.originY.roundToDouble(), 1e-6));
      }
    });

    test('the camera moves by at most half a physical pixel', () {
      for (final camera in cameras) {
        final locked = camera.pixelLocked();
        final scale = camera.pixels.scale;
        expect((locked.center.x - camera.center.x).abs() * scale, lessThan(0.5001));
        expect((locked.center.y - camera.center.y).abs() * scale, lessThan(0.5001));
      }
    });

    test('locking twice is the same as locking once', () {
      for (final camera in cameras) {
        final once = camera.pixelLocked();
        expect(once.pixelLocked(), once);
      }
    });

    test('an unusable camera is left alone', () {
      const empty = CadViewport(
        center: Vec2(0.4, 0.4),
        scale: 1,
        size: Size.zero,
      );
      expect(empty.pixelLocked(), empty);
    });

    test('every camera the controller hands out is locked', () {
      final controller = ViewportController()
        ..setSize(const Size(801, 601), 2);
      addTearDown(controller.dispose);

      void expectLocked() {
        final pixels = controller.viewport.pixels;
        expect(pixels.originX, closeTo(pixels.originX.roundToDouble(), 1e-6));
        expect(pixels.originY, closeTo(pixels.originY.roundToDouble(), 1e-6));
      }

      expectLocked();
      controller.panBy(const Offset(13.37, -7.91));
      expectLocked();
      controller.zoomBy(1.1731, const Offset(311.5, 207.25));
      expectLocked();
      controller.zoomAtCenter(0.8317);
      expectLocked();
      controller.centerOn(const Vec2(0.123456, -0.987654));
      expectLocked();
    });
  });

  group('placementFor', () {
    const size = Size(400, 300);

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
        size: size,
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
        expect(placement.offset.dx, closeTo(placement.offset.dx.roundToDouble(), 1e-6));
        expect(placement.offset.dy, closeTo(placement.offset.dy.roundToDouble(), 1e-6));
      }
    });

    test('a zoom reports the factor the camera moved by', () {
      const view = CadViewport(center: Vec2.zero(), scale: 2, size: size);
      final scene = SceneBuilder(palette: AciPalette.dark).build(grid(), view);

      final placement = scene.placementFor(view.copyWith(scale: 3));
      expect(placement.isTranslation, isFalse);
      expect(placement.scale, closeTo(1.5, 1e-12));
    });

    test('the placement puts a drawing point where the new camera would', () {
      const view = CadViewport(
        center: Vec2(4, -2),
        scale: 2,
        size: size,
        devicePixelRatio: 2,
      );
      final scene = SceneBuilder(
        palette: AciPalette.dark,
      ).build(grid(), view.pixelLocked());
      final zoomed = view
          .zoomed(1.4, const Offset(120, 90))
          .pixelLocked();

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
