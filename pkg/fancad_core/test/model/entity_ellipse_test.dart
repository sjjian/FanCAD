import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an inward offset that collapses the axes cannot invent an ellipse', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(ellipse.offsetBy(4, const Vec2.zero()), isNull);
  });

  test('reversing a full ellipse cannot invent a start', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(ellipse.reversed(), isNull);
  });

  test('a window miss cannot invent an ellipse stretch', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(
      ellipse.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(2, 0)),
      isNull,
    );
  });

  test('a full ellipse boxes its axes without flattening', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
    );
    expect(ellipse.computeBounds(), const Bounds2(-4, -2, 4, 2));
  });

  test('an elliptical arc boxes the endpoints and the extrema it covers', () {
    const quarter = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(4, 0),
      ratio: 0.5,
      startParam: 0,
      endParam: 1.5707963267948966,
    );
    final box = quarter.computeBounds();
    expect(box.minX, closeTo(0, 1e-9));
    expect(box.minY, closeTo(0, 1e-9));
    expect(box.maxX, closeTo(4, 1e-9));
    expect(box.maxY, closeTo(2, 1e-9));
  });

  test('+Z extrusion leaves ellipse parameters alone', () {
    final params = EllipseEntity.paramsForExtrusion(
      const Vec2(0, 10),
      const Vec3(0, 0, 1),
      0.3,
      2.2,
    );
    expect(params.$1, closeTo(0.3, 1e-12));
    expect(params.$2, closeTo(2.2, 1e-12));
  });

  test('a -Z extrusion fillet traces the outer quadrant', () {
    // FL25-1 ellipse #3491: AutoCAD stores 5π/4..7π/4 with extrusion -Z,
    // which is the inner corner in FanCAD's CCW minor. After bake the
    // quarter runs east-south, matching the adjacent polyline ends.
    const major = Vec2(-4.975, -4.975);
    const center = Vec2(4328.3061, 3148.7434);
    final params = EllipseEntity.paramsForExtrusion(
      major,
      const Vec3(0, 0, -1),
      5 * math.pi / 4,
      7 * math.pi / 4,
    );
    expect(params.$1, closeTo(math.pi / 4, 1e-9));
    expect(params.$2, closeTo(3 * math.pi / 4, 1e-9));
    final ellipse = EllipseEntity(
      id: 3491,
      center: center,
      majorAxis: major,
      ratio: 1,
      startParam: params.$1,
      endParam: params.$2,
    );
    expect(ellipse.startPoint.x, closeTo(center.x, 1e-6));
    expect(ellipse.startPoint.y, lessThan(center.y));
    expect(ellipse.endPoint.y, closeTo(center.y, 1e-6));
    expect(ellipse.endPoint.x, greaterThan(center.x));
  });

  test('an ellipse emits a closed flattened stroke', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(10, 0),
      ratio: 0.5,
    );
    final sink = PolylineSink();
    ellipse.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.closedFlags.first, isTrue);
    expect(ellipse.withId(9).id, 9);
    expect(
      ellipse.transformed(const Mat3.translation(2, 0)).center,
      const Vec2(2, 0),
    );
  });

  test('ellipse grips stretch the axes and a half ellipse stays open', () {
    const ellipse = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(10, 0),
      ratio: 0.5,
      startParam: 0,
      endParam: 0,
    );
    expect(ellipse.isFullEllipse, isTrue);
    const fromDefaults = EllipseEntity(
      id: 2,
      center: Vec2.zero(),
      majorAxis: Vec2(10, 0),
      ratio: 0.5,
    );
    expect(fromDefaults.endParam, math.pi * 2);
    expect(fromDefaults.isFullEllipse, isTrue);
    expect(ellipse.grips(), const [
      Vec2.zero(),
      Vec2(10, 0),
      Vec2(-10, 0),
      Vec2(0, 5),
      Vec2(0, -5),
    ]);
    expect(
      ellipse.withGrip(0, const Vec2(2, 1)).center,
      const Vec2(2, 1),
    );
    expect(
      ellipse.withGrip(1, const Vec2(20, 0)).majorAxis,
      const Vec2(20, 0),
    );
    expect(
      ellipse.withGrip(2, const Vec2(-8, 0)).majorAxis,
      const Vec2(8, 0),
    );
    expect(
      ellipse.withGrip(3, const Vec2(0, 10)).ratio,
      closeTo(1, 1e-9),
    );

    const arc = EllipseEntity(
      id: 1,
      center: Vec2.zero(),
      majorAxis: Vec2(10, 0),
      ratio: 0.5,
      startParam: 0,
      endParam: math.pi,
    );
    expect(arc.isFullEllipse, isFalse);
    final half = PolylineSink();
    arc.emit(const EmitContext(tolerance: 0.1), half);
    expect(half.closedFlags.single, isFalse);

    const oval = EllipseEntity(
      id: 3,
      center: Vec2.zero(),
      majorAxis: Vec2(10, 0),
      ratio: 0.5,
    );
    final stretched = oval.transformed(const Mat3.scaling(1, 4));
    expect(stretched.ratio, closeTo(0.5, 1e-9));
    expect(stretched.majorLength, closeTo(20, 1e-9));
    final same = oval.transformed(const Mat3.identity());
    expect(same.majorAxis.x, closeTo(10, 1e-9));
    expect(same.ratio, closeTo(0.5, 1e-9));
  });
}
