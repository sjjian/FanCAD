import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

RegionGeometry _square() => RegionGeometry.fromLoops([
  RegionLoop(const [
    RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
    RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
    RegionLine(start: Vec2(10, 10), end: Vec2(0, 10)),
    RegionLine(start: Vec2(0, 10), end: Vec2(0, 0)),
  ]),
]);

void main() {
  const fillet = RegionFillet();

  test('filleting one square corner replaces it with an exact arc', () {
    final result = fillet.vertex(_square(), const Vec2(10, 2), 2);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    expect(result.signedArea, closeTo(96 + math.pi, 1e-9));
    final curves = result.components.single.outer.curves;
    expect(curves, hasLength(5));
    final arc = curves.whereType<RegionConicArc>().single;
    expect(arc.u.length, closeTo(2, 1e-9));
    expect(arc.center.distanceTo(const Vec2(8, 2)), lessThan(1e-9));
  });

  test('filleting every corner rounds all four', () {
    final result = fillet.all(_square(), 2);
    expect(result, isNotNull);
    expect(result!.signedArea, closeTo(84 + 4 * math.pi, 1e-9));
    expect(
      result.components.single.outer.curves.whereType<RegionConicArc>(),
      hasLength(4),
    );
    expect(result.components.single.outer.curves, hasLength(8));
  });

  test('a radius larger than the edges is rejected', () {
    expect(fillet.vertex(_square(), const Vec2(10, 0), 20), isNull);
    expect(fillet.all(_square(), 20), isNull);
  });

  test('a line/arc corner gets a tangent fillet', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
        RegionConicArc(
          center: Vec2(12, 0),
          u: Vec2(2, 0),
          v: Vec2(0, 2),
          startParameter: math.pi,
          sweep: -math.pi / 2,
        ),
        RegionLine(start: Vec2(12, 2), end: Vec2(20, 2)),
        RegionLine(start: Vec2(20, 2), end: Vec2(20, -10)),
        RegionLine(start: Vec2(20, -10), end: Vec2(0, -10)),
        RegionLine(start: Vec2(0, -10), end: Vec2(0, 0)),
      ]),
    ]);
    final source = geometry.normalized();
    final result = fillet.vertex(source, const Vec2(10, 0), 1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    final curves = result.components.single.outer.curves;
    expect(curves, hasLength(7));
    final arc = curves.whereType<RegionConicArc>().firstWhere(
      (candidate) => (candidate.u.length - 1).abs() < 1e-9,
    );
    expect(arc.center.x, closeTo(12 - math.sqrt(8), 1e-6));
    expect(arc.center.y, closeTo(1, 1e-6));
    expect(result.signedArea, greaterThan(source.signedArea));
    for (var i = 0; i < curves.length; i++) {
      expect(
        curves[i].end.distanceTo(curves[(i + 1) % curves.length].start),
        lessThan(1e-6),
      );
    }
  });

  test('an arc/arc corner gets a tangent fillet', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionConicArc(
          center: Vec2(0, 0),
          u: Vec2(10, 0),
          v: Vec2(0, 10),
          startParameter: -math.pi / 2,
          sweep: math.pi / 2,
        ),
        RegionConicArc(
          center: Vec2(10, -10),
          u: Vec2(10, 0),
          v: Vec2(0, 10),
          startParameter: math.pi / 2,
          sweep: math.pi / 2,
        ),
      ]),
    ]);
    final result = fillet.vertex(geometry, const Vec2(10, 0), 1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    final curves = result.components.single.outer.curves;
    expect(curves, hasLength(3));
    expect(
      curves.whereType<RegionConicArc>().map((arc) => arc.u.length),
      contains(closeTo(1, 1e-9)),
    );
    expect(result.signedArea, lessThan(geometry.signedArea));
    for (var i = 0; i < curves.length; i++) {
      expect(
        curves[i].end.distanceTo(curves[(i + 1) % curves.length].start),
        lessThan(1e-6),
      );
    }
  });

  test('fillet all handles mixed line/arc and line/line corners', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
        RegionConicArc(
          center: Vec2(12, 0),
          u: Vec2(2, 0),
          v: Vec2(0, 2),
          startParameter: math.pi,
          sweep: -math.pi / 2,
        ),
        RegionLine(start: Vec2(12, 2), end: Vec2(20, 2)),
        RegionLine(start: Vec2(20, 2), end: Vec2(20, -10)),
        RegionLine(start: Vec2(20, -10), end: Vec2(0, -10)),
        RegionLine(start: Vec2(0, -10), end: Vec2(0, 0)),
      ]),
    ]);
    final result = fillet.all(geometry.normalized(), 0.5);
    expect(result, isNotNull);
    expect(
      result!.components.single.outer.curves.whereType<RegionConicArc>().length,
      greaterThan(2),
    );
    expect(result.approximated, isFalse);
  });

  test('an ellipse corner is filleted without flattening the ellipse', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionLine(start: Vec2(10, -10), end: Vec2(10, 0)),
        RegionConicArc(
          center: Vec2(10, 5),
          u: Vec2(0, -5),
          v: Vec2(-10, 0),
          startParameter: 0,
          sweep: math.pi / 2,
        ),
        RegionLine(start: Vec2(0, 5), end: Vec2(10, 5)),
        RegionLine(start: Vec2(10, 5), end: Vec2(10, -10)),
      ]),
    ]);
    final source = geometry.normalized();
    final result = fillet.vertex(source, const Vec2(10, 0), 1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    final curves = result.components.single.outer.curves;
    expect(
      curves.whereType<RegionConicArc>().map((arc) => arc.u.length),
      contains(closeTo(1, 1e-6)),
    );
    expect(curves.whereType<RegionConicArc>().length, 2);
    for (var i = 0; i < curves.length; i++) {
      expect(
        curves[i].end.distanceTo(curves[(i + 1) % curves.length].start),
        lessThan(1e-5),
      );
    }
  });

  test('a spline corner is filleted without flattening the spline', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop([
        const RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
        RegionSpline(
          controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
          knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          weights: const [],
          degree: 3,
          closed: false,
        ),
        const RegionLine(start: Vec2(10, 2), end: Vec2(0, 2)),
        const RegionLine(start: Vec2(0, 2), end: Vec2(0, 0)),
      ]),
    ]);
    final result = fillet.vertex(geometry, const Vec2(10, 0), 1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    final curves = result.components.single.outer.curves;
    expect(
      curves.whereType<RegionConicArc>().map((arc) => arc.u.length),
      contains(closeTo(1, 1e-6)),
    );
    final trimmedSpline = curves.whereType<RegionSpline>().single;
    expect(trimmedSpline.isFullRange, isFalse);
    expect(curves.whereType<RegionPolyline>(), isEmpty);
    for (var i = 0; i < curves.length; i++) {
      expect(
        curves[i].end.distanceTo(curves[(i + 1) % curves.length].start),
        lessThan(1e-4),
      );
    }
    final all = fillet.all(geometry, 0.5);
    expect(all, isNotNull);
    expect(all!.approximated, isFalse);
  });

  test('a closed circle can join an outer path at a seam fillet', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionConicArc(
          center: Vec2(0, 0),
          u: Vec2(5, 0),
          v: Vec2(0, 5),
          startParameter: 0,
          sweep: math.pi * 2,
        ),
        RegionLine(start: Vec2(5, 0), end: Vec2(10, 0)),
        RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
        RegionLine(start: Vec2(10, 10), end: Vec2(5, 10)),
        RegionLine(start: Vec2(5, 10), end: Vec2(5, 0)),
      ]),
    ]);
    final result = fillet.vertex(geometry, const Vec2(5, 0), 1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    final curves = result.components.single.outer.curves;
    expect(
      curves.whereType<RegionConicArc>().map((arc) => arc.u.length),
      contains(closeTo(1, 1e-6)),
    );
    for (var i = 0; i < curves.length; i++) {
      expect(
        curves[i].end.distanceTo(curves[(i + 1) % curves.length].start),
        lessThan(1e-5),
      );
    }
  });

  test('a straight polyline region can be filleted', () {
    final geometry = RegionGeometry.fromLoops([
      RegionLoop([
        RegionPolyline(Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10])),
      ]),
    ]);
    final result = fillet.vertex(geometry, const Vec2(10, 0), 1);
    expect(result, isNotNull);
    expect(result!.signedArea, closeTo(100 - (1 - math.pi / 4), 1e-9));
    expect(result.components.single.outer.curves, hasLength(5));
  });
}
