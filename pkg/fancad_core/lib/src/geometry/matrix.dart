import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'vector.dart';

/// A 2D affine transform stored as the upper 2x3 block of a 3x3 matrix.
///
/// Layout follows the mathematical convention:
/// ```
/// | a c e |
/// | b d f |
/// | 0 0 1 |
/// ```
@immutable
class Mat3 {
  const Mat3(this.a, this.b, this.c, this.d, this.e, this.f);

  const Mat3.identity() : a = 1, b = 0, c = 0, d = 1, e = 0, f = 0;

  const Mat3.translation(double tx, double ty)
    : a = 1,
      b = 0,
      c = 0,
      d = 1,
      e = tx,
      f = ty;

  const Mat3.scaling(double sx, double sy)
    : a = sx,
      b = 0,
      c = 0,
      d = sy,
      e = 0,
      f = 0;

  factory Mat3.rotation(double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Mat3(cos, sin, -sin, cos, 0, 0);
  }

  /// Rotation about an arbitrary [center].
  factory Mat3.rotationAbout(double radians, Vec2 center) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Mat3(
      cos,
      sin,
      -sin,
      cos,
      center.x - center.x * cos + center.y * sin,
      center.y - center.x * sin - center.y * cos,
    );
  }

  /// Uniform or non-uniform scaling about an arbitrary [center].
  factory Mat3.scalingAbout(double sx, double sy, Vec2 center) => Mat3(
    sx,
    0,
    0,
    sy,
    center.x * (1 - sx),
    center.y * (1 - sy),
  );

  /// Maps [source1] onto [dest1].
  ///
  /// A second pair rotates about [dest1] so [source2] lies on the ray from
  /// [dest1] through [dest2]. [scale] then matches the two segment lengths.
  /// One pair is a translation; that is the ALIGN that only needs a move.
  factory Mat3.align(
    Vec2 source1,
    Vec2 dest1, {
    Vec2? source2,
    Vec2? dest2,
    bool scale = false,
  }) {
    final translated = Mat3.translation(
      dest1.x - source1.x,
      dest1.y - source1.y,
    );
    if (source2 == null || dest2 == null) return translated;
    final from = source2 - source1;
    final to = dest2 - dest1;
    if (from.lengthSquared < 1e-20 || to.lengthSquared < 1e-20) {
      return translated;
    }
    final rotated = Mat3.rotationAbout(
      to.angle - from.angle,
      dest1,
    ).multiplied(translated);
    if (!scale) return rotated;
    final factor = to.length / from.length;
    return Mat3.scalingAbout(factor, factor, dest1).multiplied(rotated);
  }

  /// OCS→WCS for a planar entity. [extrusion] is DXF group 210 / DWG
  /// `extrusion`. Stored document coordinates stay in WCS; importers bake
  /// this at the boundary.
  ///
  /// AutoCAD arbitrary axis: if |Nx| and |Ny| are both below 1/64, Ax is
  /// Wy × N, otherwise Wz × N. Ay is N × Ax. The 2D map is
  /// `WCS = OCS_x · Ax + OCS_y · Ay`. `(0,0,1)` is the identity; `(0,0,-1)`
  /// flips X.
  factory Mat3.ocs(Vec3 extrusion) {
    var nx = extrusion.x;
    var ny = extrusion.y;
    var nz = extrusion.z;
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-20) {
      nx = 0;
      ny = 0;
      nz = 1;
    } else {
      nx /= len;
      ny /= len;
      nz /= len;
    }
    const threshold = 1 / 64;
    final double axx;
    final double axy;
    final double axz;
    if (nx.abs() < threshold && ny.abs() < threshold) {
      // Wy × N = (Nz, 0, -Nx)
      axx = nz;
      axy = 0;
      axz = -nx;
    } else {
      // Wz × N = (-Ny, Nx, 0)
      axx = -ny;
      axy = nx;
      axz = 0;
    }
    final axLen = math.sqrt(axx * axx + axy * axy + axz * axz);
    final inv = axLen < 1e-20 ? 1.0 : 1.0 / axLen;
    final axX = axx * inv;
    final axY = axy * inv;
    final axZ = axz * inv;
    // Ay = N × Ax
    final ayX = ny * axZ - nz * axY;
    final ayY = nz * axX - nx * axZ;
    return Mat3(axX, axY, ayX, ayY, 0, 0);
  }

  /// INSERT in OCS: `ocs * T(ins) * R(θ) * S`. Importers decompose
  /// [insertParts] into WCS position / scale / rotation.
  factory Mat3.ocsInsert(
    Vec2 insertion,
    Vec2 scale,
    double rotation,
    Vec3 extrusion,
  ) => Mat3.ocs(extrusion).multiplied(
    Mat3.translation(insertion.x, insertion.y)
        .multiplied(Mat3.rotation(rotation))
        .multiplied(Mat3.scaling(scale.x, scale.y)),
  );

  /// Mirror across the line through [origin] with direction [direction].
  factory Mat3.mirror(Vec2 origin, Vec2 direction) {
    final d = direction.normalized();
    final xx = d.x * d.x - d.y * d.y;
    final xy = 2 * d.x * d.y;
    // Reflect about a line through the origin, then re-anchor.
    final m = Mat3(xx, xy, xy, -xx, 0, 0);
    return Mat3.translation(origin.x, origin.y)
        .multiplied(m)
        .multiplied(Mat3.translation(-origin.x, -origin.y));
  }

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  bool get isIdentity =>
      a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  double get determinant => a * d - b * c;

  /// The average linear scale factor. Used to pick discretization tolerance
  /// for curves inside scaled block references.
  double get meanScale {
    final sx = math.sqrt(a * a + b * b);
    final sy = math.sqrt(c * c + d * d);
    return (sx + sy) / 2;
  }

  /// The rotation angle of the transform's X axis.
  double get rotation => math.atan2(b, a);

  /// `T * R * S` parameters so an INSERT transform reconstructs this.
  ({Vec2 position, Vec2 scale, double rotation}) get insertParts {
    final angle = rotation;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return (
      position: Vec2(e, f),
      scale: Vec2(a * cos + b * sin, -c * sin + d * cos),
      rotation: angle,
    );
  }

  Vec2 transform(Vec2 p) => Vec2(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Transforms a direction, ignoring translation.
  Vec2 transformDirection(Vec2 v) => Vec2(a * v.x + c * v.y, b * v.x + d * v.y);

  void transformXYInto(double x, double y, List<double> out, int index) {
    out[index] = a * x + c * y + e;
    out[index + 1] = b * x + d * y + f;
  }

  /// `this * other`, i.e. [other] is applied first.
  Mat3 multiplied(Mat3 other) => Mat3(
    a * other.a + c * other.b,
    b * other.a + d * other.b,
    a * other.c + c * other.d,
    b * other.c + d * other.d,
    a * other.e + c * other.f + e,
    b * other.e + d * other.f + f,
  );

  Mat3? inverted() {
    final det = determinant;
    if (det == 0 || !det.isFinite) return null;
    final invDet = 1 / det;
    return Mat3(
      d * invDet,
      -b * invDet,
      -c * invDet,
      a * invDet,
      (c * f - d * e) * invDet,
      (b * e - a * f) * invDet,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Mat3 &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  String toString() => 'Mat3([$a $c $e] [$b $d $f])';
}
