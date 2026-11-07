import '../../geometry/matrix.dart';
import '../../geometry/vector.dart';

/// One family of parallel lines in an AutoCAD hatch pattern.
class HatchPatternLine {
  const HatchPatternLine({
    required this.angle,
    this.originX = 0,
    this.originY = 0,
    this.deltaX = 0,
    this.deltaY = 1,
    this.dashes = const [],
  });

  /// Line angle in radians.
  final double angle;
  final double originX;
  final double originY;

  /// Offset to the next parallel line, in the pattern's own axes.
  final double deltaX;
  final double deltaY;

  /// Dash lengths; empty means a continuous line.
  final List<double> dashes;

  /// A mirror puts the next line on the right of the reflected one. The
  /// generator steps by `|deltaY|` along the left normal, so the same family
  /// counted the other way round shifts by `-deltaX` per line.
  HatchPatternLine transformed(Mat3 matrix) {
    final origin = matrix.transform(Vec2(originX, originY));
    final scale = matrix.meanScale;
    final shift = matrix.determinant < 0 ? -1.0 : 1.0;
    return HatchPatternLine(
      angle: matrix.transformAngle(angle),
      originX: origin.x,
      originY: origin.y,
      deltaX: deltaX * scale * shift,
      deltaY: deltaY * scale,
      dashes: [for (final dash in dashes) dash * scale],
    );
  }
}
