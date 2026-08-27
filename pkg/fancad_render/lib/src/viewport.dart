import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

/// The mapping between drawing coordinates and device pixels.
///
/// CAD conventions differ from screen conventions in two ways that matter: the
/// Y axis points up, and the zoom range is enormous — a site plan and a weld
/// detail can live in the same file. Both are handled here so that no drawing
/// or hit-testing code has to think about either again.
@immutable
class CadViewport {
  const CadViewport({
    required this.center,
    required this.scale,
    required this.size,
    this.devicePixelRatio = 1,
  });

  /// A viewport showing [bounds] fitted into [size], with a margin.
  factory CadViewport.fit(
    Bounds2 bounds,
    Size size, {
    double margin = 0.05,
    double devicePixelRatio = 1,
  }) {
    if (bounds.isEmpty || size.isEmpty) {
      return CadViewport(
        center: const Vec2.zero(),
        scale: 1,
        size: size,
        devicePixelRatio: devicePixelRatio,
      );
    }
    final usableWidth = size.width * (1 - margin * 2);
    final usableHeight = size.height * (1 - margin * 2);
    // A zero-extent drawing (a single point) would divide by zero.
    final width = math.max(bounds.width, 1e-9);
    final height = math.max(bounds.height, 1e-9);
    final scale = math.min(usableWidth / width, usableHeight / height);
    return CadViewport(
      center: bounds.center,
      scale: scale.clamp(minScale, maxScale),
      size: size,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Device pixels per drawing unit at the extremes. The range spans fourteen
  /// orders of magnitude, which is enough for a millimetre detail inside a
  /// kilometre-scale site plan without the transform losing precision.
  static const double minScale = 1e-7;
  static const double maxScale = 1e7;

  /// The drawing point at the centre of the widget.
  final Vec2 center;

  /// Device-independent pixels per drawing unit.
  final double scale;

  /// The widget size in logical pixels.
  final Size size;

  final double devicePixelRatio;

  bool get isUsable => size.width > 0 && size.height > 0 && scale > 0;

  /// The drawing area currently visible.
  Bounds2 get visibleBounds {
    if (!isUsable) return const Bounds2.empty();
    final halfWidth = size.width / 2 / scale;
    final halfHeight = size.height / 2 / scale;
    return Bounds2(
      center.x - halfWidth,
      center.y - halfHeight,
      center.x + halfWidth,
      center.y + halfHeight,
    );
  }

  /// The visible area grown by [factor], used to keep geometry just off screen
  /// in the batch so that a small pan does not force a rebuild.
  Bounds2 paddedBounds([double factor = 0.25]) {
    final box = visibleBounds;
    if (box.isEmpty) return box;
    return box.inflated(math.max(box.width, box.height) * factor);
  }

  /// The world-to-screen transform, in logical pixels.
  ///
  /// The Y flip lives here, which is why every sink downstream can treat its
  /// output as screen coordinates without a second thought.
  Mat3 get worldToScreen => Mat3(
    scale,
    0,
    0,
    -scale,
    size.width / 2 - center.x * scale,
    size.height / 2 + center.y * scale,
  );

  Mat3 get screenToWorld => Mat3(
    1 / scale,
    0,
    0,
    -1 / scale,
    center.x - size.width / 2 / scale,
    center.y + size.height / 2 / scale,
  );

  Offset toScreen(Vec2 world) => Offset(
    (world.x - center.x) * scale + size.width / 2,
    size.height / 2 - (world.y - center.y) * scale,
  );

  Vec2 toWorld(Offset screen) => Vec2(
    (screen.dx - size.width / 2) / scale + center.x,
    center.y - (screen.dy - size.height / 2) / scale,
  );

  /// A drawing-unit length that corresponds to [pixels] on screen. Used for
  /// pick radii and snap tolerances, which are naturally expressed in pixels.
  double pixelsToWorld(double pixels) => pixels / scale;

  /// The chord tolerance to tessellate curves at: half a device pixel, so
  /// refining further cannot change what is rasterised.
  double get tolerance => 0.5 / (scale * devicePixelRatio);

  CadViewport copyWith({
    Vec2? center,
    double? scale,
    Size? size,
    double? devicePixelRatio,
  }) => CadViewport(
    center: center ?? this.center,
    scale: (scale ?? this.scale).clamp(minScale, maxScale),
    size: size ?? this.size,
    devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
  );

  /// Pans by a screen-space delta.
  CadViewport panned(Offset screenDelta) => copyWith(
    center: Vec2(
      center.x - screenDelta.dx / scale,
      center.y + screenDelta.dy / scale,
    ),
  );

  /// Zooms by [factor], keeping the drawing point under [anchor] fixed.
  ///
  /// Anchoring on the cursor rather than the centre is what makes wheel zoom
  /// feel like a map instead of a slider.
  CadViewport zoomed(double factor, Offset anchor) {
    final target = (scale * factor).clamp(minScale, maxScale);
    if (target == scale) return this;
    final anchorWorld = toWorld(anchor);
    // Solve for the centre that keeps anchorWorld under the same pixel.
    final offsetX = anchor.dx - size.width / 2;
    final offsetY = anchor.dy - size.height / 2;
    return copyWith(
      center: Vec2(
        anchorWorld.x - offsetX / target,
        anchorWorld.y + offsetY / target,
      ),
      scale: target,
    );
  }

  /// Zooms about the centre of the widget.
  CadViewport zoomedAtCenter(double factor) =>
      zoomed(factor, Offset(size.width / 2, size.height / 2));

  @override
  bool operator ==(Object other) =>
      other is CadViewport &&
      other.center == center &&
      other.scale == scale &&
      other.size == size &&
      other.devicePixelRatio == devicePixelRatio;

  @override
  int get hashCode => Object.hash(center, scale, size, devicePixelRatio);

  @override
  String toString() =>
      'CadViewport(center: $center, scale: ${scale.toStringAsPrecision(4)}, '
      'size: ${size.width.round()}x${size.height.round()})';
}

/// World-unit spacing of the reference grid at the current zoom.
///
/// Matches the painted grid so snap and display stay on the same intersections.
double referenceGridStep(CadViewport viewport) =>
    niceGridStep(viewport.pixelsToWorld(12));

/// The smallest 1, 2 or 5 times a power of ten that is at least [value].
///
/// Grid spacing has to be a number a person can do arithmetic with, which is
/// why it snaps to this sequence rather than to the raw pixel target.
double niceGridStep(double value) {
  if (!value.isFinite || value <= 0) return 1;
  final exponent = (math.log(value) / math.ln10).floor();
  final decade = math.pow(10, exponent).toDouble();
  for (final multiple in const [1.0, 2.0, 5.0]) {
    if (decade * multiple >= value) return decade * multiple;
  }
  return decade * 10;
}

/// Maps one trackpad pinch step to a zoom factor. Faster pinches travel further.
///
/// [rawRatio] is this event's scale over the previous one. [dt] is the time
/// since that previous event; a missing or zero interval stays 1:1 so the
/// first sample of a gesture does not jump.
double trackpadPinchFactor(double rawRatio, Duration? dt) {
  if (!rawRatio.isFinite || rawRatio <= 0) return 1;
  if (rawRatio == 1) return 1;
  if (dt == null || dt <= Duration.zero) return rawRatio;

  var seconds = dt.inMicroseconds / 1e6;
  seconds = seconds.clamp(4 / 1000, 80 / 1000);
  final speed = math.log(rawRatio).abs() / seconds;
  const slow = 0.4;
  const fast = 3.0;
  const minGain = 1.0;
  const maxGain = 2.2;
  final t = ((speed - slow) / (fast - slow)).clamp(0.0, 1.0);
  final smooth = t * t * (3 - 2 * t);
  final gain = minGain + (maxGain - minGain) * smooth;
  return math.pow(rawRatio, gain).toDouble();
}
