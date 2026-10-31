import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clipper2/clipper2.dart';

import '../document/entity.dart';

enum RegionOp { union, subtract, intersect, xor }

/// A 2D REGION boolean implementation.
///
/// The current backend flattens every curve to a polyline and uses Clipper2.
/// The result is therefore polygonal and [RegionGeometry.approximated] is set.
/// An exact line/conic arrangement can replace this class without changing the
/// entity or file format.
abstract interface class RegionBoolean {
  RegionGeometry apply(
    RegionOp op,
    List<RegionGeometry> operands, {
    double tolerance = 1e-3,
  });
}

/// Clipper2-backed polygon boolean.
class PolygonRegionBoolean implements RegionBoolean {
  const PolygonRegionBoolean();

  @override
  RegionGeometry apply(
    RegionOp op,
    List<RegionGeometry> operands, {
    double tolerance = 1e-3,
  }) {
    final geometry = [for (final operand in operands) operand.normalized()]
      ..removeWhere((operand) => operand.components.isEmpty);
    if (geometry.isEmpty) return const RegionGeometry(components: []);
    final scale = tolerance > 0 ? 1 / tolerance : 1000.0;
    final paths = [
      for (final operand in geometry) ...[
        for (final component in operand.components) ...[
          _path(component.outer, scale, tolerance),
          for (final hole in component.holes) _path(hole, scale, tolerance),
        ],
      ],
    ];
    final subject = [
      for (final component in geometry.first.components) ...[
        _path(component.outer, scale, tolerance),
        for (final hole in component.holes) _path(hole, scale, tolerance),
      ],
    ];
    final clip = [
      for (final operand in geometry.skip(1)) ...[
        for (final component in operand.components) ...[
          _path(component.outer, scale, tolerance),
          for (final hole in component.holes) _path(hole, scale, tolerance),
        ],
      ],
    ];
    Paths64 result;
    switch (op) {
      case RegionOp.union:
        result = Clipper.union(subject: paths, fillRule: FillRule.nonZero);
      case RegionOp.subtract:
        result = Clipper.difference(
          subject: subject,
          clip: clip,
          fillRule: FillRule.nonZero,
        );
      case RegionOp.intersect:
        result = Clipper.intersect(
          subject: subject,
          clip: clip,
          fillRule: FillRule.nonZero,
        );
      case RegionOp.xor:
        result = Clipper.xor(
          subject: subject,
          clip: clip,
          fillRule: FillRule.nonZero,
        );
    }
    final loops = <RegionLoop>[];
    for (final path in result) {
      if (path.length < 3) continue;
      final points = Float64List(path.length * 2);
      for (var i = 0; i < path.length; i++) {
        points[i * 2] = path[i].x / scale;
        points[i * 2 + 1] = path[i].y / scale;
      }
      loops.add(RegionLoop([RegionPolyline(points)]));
    }
    if (loops.isEmpty) return const RegionGeometry(components: []);
    return RegionGeometry.fromLoops(
      loops,
      approximated: true,
      tolerance: math.max(tolerance, 1e-9),
    );
  }

  Path64 _path(RegionLoop loop, double scale, double tolerance) => [
    for (final point in loop.samplePoints(tolerance))
      Point64.fromDouble(point.x, point.y, scale: scale),
  ];
}
