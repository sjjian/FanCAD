import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:fancad_test/fancad_test.dart';
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
      (
        name: 'fractional origin',
        camera: CadViewport(
          center: Vec2(0.3333, -1.777),
          scale: 3.5,
          size: Size(801, 601),
        ),
      ),
      (
        name: 'far origin at 2×',
        camera: CadViewport(
          center: Vec2(-12345.6789, 9876.54321),
          scale: 0.017,
          size: Size(1024, 768),
          devicePixelRatio: 2,
        ),
      ),
      (
        name: 'huge coordinates at 3×',
        camera: CadViewport(
          center: Vec2(1e6 + 0.4, -1e6 - 0.6),
          scale: 137.25,
          size: Size(1600, 900),
          devicePixelRatio: 3,
        ),
      ),
    ];

    eachCase(
      cameras,
      (row) {
        final pixels = row.camera.pixelLocked().pixels;
        expect(pixels.originX, closeTo(pixels.originX.roundToDouble(), 1e-6));
        expect(pixels.originY, closeTo(pixels.originY.roundToDouble(), 1e-6));
      },
      name: (row) =>
          'the screen origin lands on a whole physical pixel (${row.name})',
    );

    eachCase(
      cameras,
      (row) {
        final locked = row.camera.pixelLocked();
        final scale = row.camera.pixels.scale;
        expect(
          (locked.center.x - row.camera.center.x).abs() * scale,
          lessThan(0.5001),
        );
        expect(
          (locked.center.y - row.camera.center.y).abs() * scale,
          lessThan(0.5001),
        );
      },
      name: (row) =>
          'the camera moves by at most half a physical pixel (${row.name})',
    );

    eachCase(
      cameras,
      (row) {
        final once = row.camera.pixelLocked();
        expect(once.pixelLocked(), once);
      },
      name: (row) => 'locking twice is the same as locking once (${row.name})',
    );

    test('an unusable camera is left alone', () {
      const empty = CadViewport(
        center: Vec2(0.4, 0.4),
        scale: 1,
        size: Size.zero,
      );
      expect(empty.pixelLocked(), empty);
    });

    test('every camera the controller hands out is locked', () {
      final controller = ViewportController()..setSize(const Size(801, 601), 2);
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
}
