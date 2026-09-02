import 'dart:ui' show Offset;

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

/// The mapping from drawing coordinates to physical device pixels.
///
/// Everything downstream of the batching sink works in this space: vertices,
/// line weights, alignment. The painter undoes the ratio once with a
/// `canvas.scale(1 / dpr)`, so no other code has to know about it.
///
/// Having one unambiguous unit is what makes a hairline one physical pixel on
/// a Retina display rather than two, and it removes the class of bugs where a
/// coordinate was compensated for the ratio but a stroke width was not.
@immutable
class PixelSpace {
  const PixelSpace({
    required this.scale,
    required this.originX,
    required this.originY,
    required this.dpr,
  });

  /// Physical pixels per drawing unit.
  final double scale;

  final double originX;
  final double originY;

  /// Physical pixels per logical pixel.
  final double dpr;

  double xOf(double worldX) => worldX * scale + originX;

  /// The Y flip: drawing coordinates go up, screen coordinates go down.
  double yOf(double worldY) => originY - worldY * scale;

  Offset offsetOf(Vec2 world) => Offset(xOf(world.x), yOf(world.y));

  double worldXOf(double pixelX) => (pixelX - originX) / scale;

  double worldYOf(double pixelY) => (originY - pixelY) / scale;

  /// A length given in logical pixels, in physical pixels.
  ///
  /// Used for the sizes a person picked by eye — a grip, a pick radius — which
  /// should stay the same apparent size on every display.
  double fromLogical(double logical) => logical * dpr;

  /// The centre of the physical pixel that [coordinate] falls in.
  ///
  /// The renderer's alignment primitive for hairlines and markers. A stroke
  /// one physical pixel wide centred here covers exactly one pixel column, so
  /// an ACI 3 hairline is a saturated green instead of a grey blend split
  /// across two columns.
  static double centre(double coordinate) => coordinate.floorToDouble() + 0.5;

  /// Where a stroke [width] physical pixels wide should be centred so that
  /// both of its edges land on pixel boundaries.
  ///
  /// The odd and even cases genuinely differ: a one-pixel pen wants a pixel
  /// centre, a two-pixel pen wants the boundary between two pixels. Putting a
  /// two-pixel pen on a centre would spread it over three columns at half
  /// coverage, which is the same washed-out look as no alignment at all.
  static double strokeCentre(double coordinate, double width) =>
      (coordinate - width / 2).roundToDouble() + width / 2;
}
