import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range spline grip cannot invent a control', () {
    final spline = SplineEntity(
      id: 1,
      controlPoints: Float64List.fromList([0, 0, 2, 2, 4, 0]),
      knots: const [0, 0, 0, 1, 1, 1],
      degree: 2,
    );
    expect(spline.withGrip(-1, const Vec2(1, 1)), same(spline));
    expect(spline.withGrip(99, const Vec2(1, 1)), same(spline));
  });

  test('an empty spline cannot invent an offset', () {
    final spline = SplineEntity(id: 1, controlPoints: Float64List(0));
    expect(spline.offsetBy(2, const Vec2(1, 1)), isNull);
    expect(spline.pathLength, 0);
  });

  test('a fit-only spline still emits a centreline', () {
    final spline = SplineEntity(
      id: 1,
      controlPoints: Float64List(0),
      fitPoints: Float64List.fromList([0, 0, 2, 3, 5, 1, 8, 0]),
    );
    final sink = PolylineSink();
    spline.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.polylines.first.length, greaterThan(4));
    expect(spline.pathLength, greaterThan(0));
  });

  test('a spline with no controls and no fit points still emits nothing', () {
    final spline = SplineEntity(id: 1, controlPoints: Float64List(0));
    final sink = PolylineSink();
    spline.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });

  test('reversing a spline keeps the fit points and swaps the ends', () {
    const fits = [Vec2.zero(), Vec2(2, 3), Vec2(5, 1), Vec2(8, 0)];
    final spline = Construct.splineFromFit(fits)!;
    final reversed = spline.reversed();
    expect(reversed, isA<SplineEntity>());
    final next = reversed as SplineEntity;
    expect(next.fitPointCount, fits.length);
    expect(next.fitPointBuffer[0], closeTo(fits.last.x, 1e-9));
    expect(next.fitPointBuffer[1], closeTo(fits.last.y, 1e-9));
    expect(
      next.fitPointBuffer[next.fitPointBuffer.length - 2],
      closeTo(fits.first.x, 1e-9),
    );
    expect(
      next.fitPointBuffer[next.fitPointBuffer.length - 1],
      closeTo(fits.first.y, 1e-9),
    );
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: next.controlPoints,
        knots: next.knots,
        degree: next.degree,
        t: 0,
      )!.distanceTo(fits.last),
      lessThan(1e-6),
    );
    expect(
      Flatten.bsplineEvaluate(
        controlPoints: next.controlPoints,
        knots: next.knots,
        degree: next.degree,
        t: 1,
      )!.distanceTo(fits.first),
      lessThan(1e-6),
    );
  });

  test('a window miss cannot invent a spline stretch', () {
    final spline = SplineEntity(
      id: 1,
      controlPoints: Float64List.fromList([0, 0, 2, 2, 4, 0]),
      knots: const [0, 0, 0, 1, 1, 1],
      degree: 2,
    );
    expect(
      spline.stretchBy(const Bounds2(100, 100, 101, 101), const Vec2(0, 2)),
      isNull,
    );
  });
}
