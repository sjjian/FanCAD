import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A point or direction in 2D model space.
///
/// CAD drawings routinely contain millions of coordinates, so this type stays
/// deliberately small: two doubles, no growable storage, const constructible.
@immutable
class Vec2 {
  const Vec2(this.x, this.y);

  const Vec2.zero() : x = 0, y = 0;

  factory Vec2.polar(double angle, double radius) =>
      Vec2(math.cos(angle) * radius, math.sin(angle) * radius);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;

  /// Angle from the positive X axis, in radians, in `(-pi, pi]`.
  double get angle => math.atan2(y, x);

  double distanceTo(Vec2 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double distanceSquaredTo(Vec2 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dx * dx + dy * dy;
  }

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// 2D cross product (z component of the 3D cross product).
  double cross(Vec2 other) => x * other.y - y * other.x;

  Vec2 normalized() {
    final len = length;
    if (len == 0) return const Vec2.zero();
    return Vec2(x / len, y / len);
  }

  /// Rotated 90 degrees counter-clockwise.
  Vec2 get perpendicular => Vec2(-y, x);

  Vec2 rotated(double radians, [Vec2 about = const Vec2.zero()]) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    final dx = x - about.x;
    final dy = y - about.y;
    return Vec2(about.x + dx * c - dy * s, about.y + dx * s + dy * c);
  }

  Vec2 lerp(Vec2 other, double t) =>
      Vec2(x + (other.x - x) * t, y + (other.y - y) * t);

  Vec3 toVec3([double z = 0]) => Vec3(x, y, z);

  bool get isFinite => x.isFinite && y.isFinite;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'Vec2(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';
}

/// A 3D point. FanCAD is a 2D CAD application but DWG stores 3D coordinates
/// throughout, and elevation/extrusion must survive a load/save round trip.
@immutable
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  const Vec3.zero() : x = 0, y = 0, z = 0;

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  Vec2 get xy => Vec2(x, y);

  double get length => math.sqrt(x * x + y * y + z * z);

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// Normalizes an angle to `[0, 2*pi)`.
double normalizeAngle(double radians) {
  const twoPi = math.pi * 2;
  var a = radians % twoPi;
  if (a < 0) a += twoPi;
  return a;
}

/// The counter-clockwise sweep from [start] to [end], always in `[0, 2*pi)`.
double angularSweep(double start, double end) {
  final sweep = normalizeAngle(end) - normalizeAngle(start);
  return sweep < 0 ? sweep + math.pi * 2 : sweep;
}
