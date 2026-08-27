import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  const context = EmitContext(tolerance: 0.1);

  test('arc grips change start, radius, end or the centre', () {
    const arc = ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );
    final grips = arc.grips();
    expect(grips, hasLength(4));
    expect(grips[0].distanceTo(const Vec2(10, 0)), closeTo(0, 1e-9));
    expect(grips[1].distanceTo(Vec2.polar(math.pi / 4, 10)), closeTo(0, 1e-9));
    expect(grips[2].distanceTo(const Vec2(0, 10)), closeTo(0, 1e-9));
    expect(grips[3], const Vec2.zero());

    expect((arc.withGrip(0, const Vec2(0, 10)) as ArcEntity).startAngle, closeTo(math.pi / 2, 1e-9));
    expect((arc.withGrip(2, const Vec2(10, 0)) as ArcEntity).endAngle, closeTo(0, 1e-9));
    expect((arc.withGrip(1, const Vec2(20, 0)) as ArcEntity).radius, closeTo(20, 1e-9));
    expect((arc.withGrip(3, const Vec2(1, 2)) as ArcEntity).center, const Vec2(1, 2));

    final silent = PolylineSink();
    const ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: 1,
    ).emit(context, silent);
    expect(silent.polylines, isEmpty);

    final rotated = arc.transformed(Mat3.rotation(math.pi / 2));
    expect(rotated.center, const Vec2.zero());
    expect(rotated.startAngle, closeTo(math.pi / 2, 1e-9));
    expect(rotated.endAngle, closeTo(math.pi, 1e-9));
  });

  test('ellipse grips stretch the axes and a full ellipse emits closed', () {
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
    final defaultSink = PolylineSink();
    fromDefaults.emit(context, defaultSink);
    expect(defaultSink.closedFlags.single, isTrue);
    expect(ellipse.grips(), const [
      Vec2.zero(),
      Vec2(10, 0),
      Vec2(-10, 0),
      Vec2(0, 5),
      Vec2(0, -5),
    ]);
    expect(
      (ellipse.withGrip(0, const Vec2(2, 1)) as EllipseEntity).center,
      const Vec2(2, 1),
    );
    expect(
      (ellipse.withGrip(1, const Vec2(20, 0)) as EllipseEntity).majorAxis,
      const Vec2(20, 0),
    );
    expect(
      (ellipse.withGrip(2, const Vec2(-8, 0)) as EllipseEntity).majorAxis,
      const Vec2(8, 0),
    );
    expect(
      (ellipse.withGrip(3, const Vec2(0, 10)) as EllipseEntity).ratio,
      closeTo(1, 1e-9),
    );

    final full = PolylineSink();
    ellipse.emit(context, full);
    expect(full.closedFlags.single, isTrue);

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
    arc.emit(context, half);
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

  test('a spline grip edits one control point and an empty curve is silent', () {
    final spline = SplineEntity(
      id: 1,
      controlPoints: Float64List.fromList([0, 0, 4, 2, 8, 0]),
      degree: 2,
    );
    expect(spline.grips(), const [Vec2.zero(), Vec2(4, 2), Vec2(8, 0)]);
    expect(spline.withGrip(1, const Vec2(4, 5)).grips()[1], const Vec2(4, 5));
    expect(spline.withGrip(9, const Vec2.zero()), spline);

    final empty = SplineEntity(id: 1, controlPoints: Float64List(0));
    final sink = PolylineSink();
    empty.emit(context, sink);
    expect(sink.polylines, isEmpty);
    spline.emit(context, sink);
    expect(sink.polylines, isNotEmpty);
  });
}
