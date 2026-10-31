import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

RegionLoop _squareLoop(Vec2 origin, double size) => RegionLoop([
  RegionLine(start: origin, end: origin + Vec2(size, 0)),
  RegionLine(start: origin + Vec2(size, 0), end: origin + Vec2(size, size)),
  RegionLine(start: origin + Vec2(size, size), end: origin + Vec2(0, size)),
  RegionLine(start: origin + Vec2(0, size), end: origin),
]);

RegionGeometry _square(double size, {List<RegionLoop> holes = const []}) =>
    RegionGeometry.fromLoops([_squareLoop(const Vec2(0, 0), size), ...holes]);

RegionLoop _circleLoop(double radius) => RegionLoop([
  RegionConicArc(
    center: const Vec2(0, 0),
    u: Vec2(radius, 0),
    v: Vec2(0, radius),
    startParameter: 0,
    sweep: math.pi * 2,
  ),
]);

void main() {
  const offset = RegionOffset();

  test('growing a square keeps straight edges exact', () {
    final result = offset.apply(_square(10), -1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    expect(result.components, hasLength(1));
    expect(result.signedArea, closeTo(144, 1e-9));
    expect(result.components.single.outer.curves, hasLength(4));
  });

  test('shrinking a square moves every edge inward', () {
    final result = offset.apply(_square(10), 1);
    expect(result, isNotNull);
    expect(result!.signedArea, closeTo(64, 1e-9));
    expect(result.approximated, isFalse);
  });

  test('a hole shrinks when the material grows', () {
    final geometry = RegionGeometry.fromLoops([
      _squareLoop(const Vec2(0, 0), 20),
      _squareLoop(const Vec2(8, 8), 4),
    ]);
    final result = offset.apply(geometry, -1);
    expect(result, isNotNull);
    expect(result!.components, hasLength(1));
    expect(result.components.single.holes, hasLength(1));
    expect(result.signedArea, closeTo(22 * 22 - 2 * 2, 1e-9));
  });

  test('a circle offsets to another exact circle', () {
    final circle = RegionGeometry.fromLoops([_circleLoop(10)]);
    final grown = offset.apply(circle, -2);
    expect(grown, isNotNull);
    expect(grown!.approximated, isFalse);
    expect(grown.signedArea, closeTo(math.pi * 144, 1e-9));
    final conic = grown.components.single.outer.curves.single as RegionConicArc;
    expect(conic.u.length, closeTo(12, 1e-9));

    final shrunk = offset.apply(circle, 3);
    expect(shrunk!.signedArea, closeTo(math.pi * 49, 1e-9));
    expect(shrunk.approximated, isFalse);
  });

  test('a circle that collapses leaves nothing', () {
    expect(offset.apply(RegionGeometry.fromLoops([_circleLoop(5)]), 6), isNull);
  });

  test('a line/arc stadium grows without flattening the caps', () {
    final stadium = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionLine(start: Vec2(0, 0), end: Vec2(20, 0)),
        RegionConicArc(
          center: Vec2(20, 5),
          u: Vec2(5, 0),
          v: Vec2(0, 5),
          startParameter: -math.pi / 2,
          sweep: math.pi,
        ),
        RegionLine(start: Vec2(20, 10), end: Vec2(0, 10)),
        RegionConicArc(
          center: Vec2(0, 5),
          u: Vec2(5, 0),
          v: Vec2(0, 5),
          startParameter: math.pi / 2,
          sweep: math.pi,
        ),
      ]),
    ]);
    final result = offset.apply(stadium, -1);
    expect(result, isNotNull);
    expect(result!.approximated, isFalse);
    expect(result.signedArea, closeTo(20 * 12 + math.pi * 36, 1e-6));
    expect(
      result.components.single.outer.curves.whereType<RegionConicArc>(),
      hasLength(2),
    );
  });

  test('offsetting a filleted region keeps its corner arcs', () {
    final filleted = const RegionFillet().all(_square(10), 1.5);
    expect(filleted, isNotNull);
    final grown = offset.apply(filleted!, -1);
    expect(grown, isNotNull);
    expect(grown!.approximated, isFalse);
    expect(
      grown.signedArea,
      closeTo(12 * 12 - (4 - math.pi) * 2.5 * 2.5, 1e-6),
    );

    final shrunk = offset.apply(filleted, 1);
    expect(shrunk, isNotNull);
    expect(shrunk!.approximated, isFalse);
    expect(shrunk.signedArea, closeTo(8 * 8 - (4 - math.pi) * 0.5 * 0.5, 1e-6));
  });

  test('a grown then filleted region still offsets exactly', () {
    final grown = offset.apply(_square(10), -1);
    expect(grown, isNotNull);
    final corner = const RegionFillet().vertex(grown!, const Vec2(11, 0), 2);
    expect(corner, isNotNull);
    final filleted = const RegionFillet().all(corner!, 1.5);
    expect(filleted, isNotNull);
    final shrunk = offset.apply(filleted!, 1);
    expect(shrunk, isNotNull);
    expect(shrunk!.approximated, isFalse);
    expect(
      shrunk.signedArea,
      closeTo(100 - (1 - math.pi / 4) * (1 + 3 * 0.25), 1e-6),
    );
  });

  test('an approximated input stays approximated after offsetting', () {
    final source = RegionGeometry(
      components: _square(10).components,
      approximated: true,
    );
    final result = offset.apply(source, 1);
    expect(result, isNotNull);
    expect(result!.approximated, isTrue);
  });

  test('an ellipse falls back to the polygon offset', () {
    final ellipse = RegionGeometry.fromLoops([
      RegionLoop(const [
        RegionConicArc(
          center: Vec2(0, 0),
          u: Vec2(10, 0),
          v: Vec2(0, 5),
          startParameter: 0,
          sweep: math.pi * 2,
        ),
      ]),
    ]);
    final result = offset.apply(ellipse, -1);
    expect(result, isNotNull);
    expect(result!.approximated, isTrue);
    expect(result.signedArea, greaterThan(ellipse.signedArea));
  });

  test('Construct.offset drops the stale ACIS source', () {
    final region = RegionEntity(
      id: 7,
      components: _square(10).components,
      source: AcisPayload(
        format: 'sat',
        bytes: Uint8List.fromList('old'.codeUnits),
      ),
    );
    final result = Construct.offset(region, 1, const Vec2(100, 100));
    expect(result, isA<RegionEntity>());
    final moved = result! as RegionEntity;
    expect(moved.source, isNull);
    expect(moved.signedArea, closeTo(144, 1e-9));
  });
}
