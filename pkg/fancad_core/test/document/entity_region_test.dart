import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  satReaderTest();
  const circle = RegionConicArc(
    center: Vec2.zero(),
    u: Vec2(10, 0),
    v: Vec2(0, 10),
    startParameter: 0,
    sweep: math.pi * 2,
  );

  test('a full conic reports the circle area and bounds', () {
    expect(circle.signedAreaContribution, closeTo(math.pi * 100, 1e-9));
    expect(circle.length, closeTo(math.pi * 20, 0.05));
    expect(circle.bounds.minX, closeTo(-10, 1e-9));
    expect(circle.bounds.maxY, closeTo(10, 1e-9));
    expect(circle.start, const Vec2(10, 0));
    expect(circle.end.x, closeTo(10, 1e-9));
  });

  test('an affine transform keeps a conic analytic', () {
    final ellipse = circle.transformed(Mat3.scaling(2, 3));
    expect(ellipse.signedAreaContribution, closeTo(math.pi * 100 * 6, 1e-9));
    expect(ellipse.bounds.width, closeTo(40, 1e-9));
    expect(ellipse.bounds.height, closeTo(60, 1e-9));
  });

  test('a component subtracts its holes', () {
    final outer = RegionLoop([
      const RegionLine(start: Vec2(-10, -10), end: Vec2(50, -10)),
      const RegionLine(start: Vec2(50, -10), end: Vec2(50, 40)),
      const RegionLine(start: Vec2(50, 40), end: Vec2(-10, 40)),
      const RegionLine(start: Vec2(-10, 40), end: Vec2(-10, -10)),
    ]);
    const holeCircle = RegionConicArc(
      center: Vec2(20, 15),
      u: Vec2(5, 0),
      v: Vec2(0, 5),
      startParameter: 0,
      sweep: math.pi * 2,
    );
    final hole = RegionLoop([holeCircle]);
    final component = RegionComponent(outer: outer, holes: [hole]).normalized();
    expect(component.outer.signedArea, closeTo(60 * 50, 1e-9));
    expect(component.signedArea, closeTo(60 * 50 - math.pi * 25, 1e-9));
  });

  test('loops group into components by containment', () {
    final outer = RegionLoop([
      const RegionLine(start: Vec2(0, 0), end: Vec2(100, 0)),
      const RegionLine(start: Vec2(100, 0), end: Vec2(100, 100)),
      const RegionLine(start: Vec2(100, 100), end: Vec2(0, 100)),
      const RegionLine(start: Vec2(0, 100), end: Vec2(0, 0)),
    ]);
    const holeCircle = RegionConicArc(
      center: Vec2(50, 50),
      u: Vec2(10, 0),
      v: Vec2(0, 10),
      startParameter: 0,
      sweep: math.pi * 2,
    );
    final hole = RegionLoop([holeCircle]);
    final island = RegionLoop([
      const RegionLine(start: Vec2(45, 45), end: Vec2(55, 45)),
      const RegionLine(start: Vec2(55, 45), end: Vec2(55, 55)),
      const RegionLine(start: Vec2(55, 55), end: Vec2(45, 55)),
      const RegionLine(start: Vec2(45, 55), end: Vec2(45, 45)),
    ]);
    final geometry = RegionGeometry.fromLoops([island, hole, outer]);
    expect(geometry.components, hasLength(2));
    final byArea = [...geometry.components]
      ..sort((a, b) => b.signedArea.compareTo(a.signedArea));
    expect(byArea.first.holes, hasLength(1));
    expect(byArea.first.signedArea, closeTo(10000 - math.pi * 100, 1e-9));
    expect(byArea.last.holes, isEmpty);
    expect(byArea.last.signedArea, closeTo(100, 1e-9));
  });

  test('region JSON keeps components and area', () {
    final region = RegionEntity(
      id: 7,
      components: [
        RegionComponent(
          outer: RegionLoop([
            const RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
            const RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
            const RegionLine(start: Vec2(10, 10), end: Vec2(0, 10)),
            const RegionLine(start: Vec2(0, 10), end: Vec2(0, 0)),
          ]),
          holes: [
            RegionLoop([
              const RegionConicArc(
                center: Vec2(5, 5),
                u: Vec2(2, 0),
                v: Vec2(0, 2),
                startParameter: 0,
                sweep: math.pi * 2,
              ),
            ]),
          ],
        ),
      ],
    );
    final restored = CadEntity.fromJson(region.toJson());
    expect(restored, isA<RegionEntity>());
    expect(
      (restored as RegionEntity).signedArea,
      closeTo(100 - math.pi * 4, 1e-9),
    );
  });

  test('region JSON keeps a trimmed spline range', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [],
      degree: 3,
      closed: false,
      rangeStart: 0.2,
      rangeEnd: 0.8,
    );
    final restored = RegionCurve.fromJson(spline.toJson());
    expect(restored, isA<RegionSpline>());
    final trimmed = restored as RegionSpline;
    expect(trimmed.rangeStart, 0.2);
    expect(trimmed.rangeEnd, 0.8);
    expect(trimmed.start.distanceTo(spline.start), lessThan(1e-9));
    expect(trimmed.end.distanceTo(spline.end), lessThan(1e-9));
  });

  test('reversing a spline keeps its NURBS form and range', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [],
      degree: 3,
      closed: false,
      rangeStart: 0.2,
      rangeEnd: 0.8,
    );
    final reversed = spline.reversed();
    expect(reversed, isA<RegionSpline>());
    final trimmed = reversed as RegionSpline;
    expect(trimmed.rangeStart, closeTo(0.2, 1e-12));
    expect(trimmed.rangeEnd, closeTo(0.8, 1e-12));
    expect(trimmed.start.distanceTo(spline.end), lessThan(1e-9));
    expect(trimmed.end.distanceTo(spline.start), lessThan(1e-9));
  });

  test('a trimmed spline becomes an exact standalone sub-spline', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [],
      degree: 3,
      closed: false,
      rangeStart: 0.2,
      rangeEnd: 0.8,
    );
    final sub = spline.asSpline();
    expect(sub, isNotNull);
    final originalMin = spline.knots[spline.degree];
    final originalMax = spline.knots[spline.controlPointCount];
    final subMin = sub!.knots[sub.degree];
    final subMax = sub.knots[sub.controlPoints.length ~/ 2];
    for (var i = 0; i <= 20; i++) {
      final fraction = 0.2 + 0.6 * i / 20;
      final original = Flatten.bsplineEvaluate(
        controlPoints: spline.controlPoints,
        knots: spline.knots,
        degree: spline.degree,
        t: originalMin + (originalMax - originalMin) * fraction,
        weights: spline.weights,
      );
      final actual = Flatten.bsplineEvaluate(
        controlPoints: sub.controlPoints,
        knots: sub.knots,
        degree: sub.degree,
        t: subMin + (subMax - subMin) * (i / 20),
        weights: sub.weights,
      );
      expect(original, isNotNull);
      expect(actual, isNotNull);
      expect(original!.distanceTo(actual!), lessThan(1e-8));
    }
    expect(
      Vec2(
        sub.controlPoints.first,
        sub.controlPoints[1],
      ).distanceTo(spline.start),
      lessThan(1e-9),
    );
    expect(
      Vec2(
        sub.controlPoints[sub.controlPoints.length - 2],
        sub.controlPoints.last,
      ).distanceTo(spline.end),
      lessThan(1e-9),
    );
  });

  test('exploding a trimmed spline keeps a real SPLINE entity', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [],
      degree: 3,
      closed: false,
      rangeStart: 0.2,
      rangeEnd: 0.8,
    );
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(outer: RegionLoop([spline])),
      ],
    );
    final pieces = region.explode(CadDocument());
    expect(pieces, hasLength(1));
    expect(pieces.single, isA<SplineEntity>());
    final exploded = pieces.single as SplineEntity;
    expect(
      Vec2(
        exploded.controlPoints.first,
        exploded.controlPoints[1],
      ).distanceTo(spline.start),
      lessThan(1e-9),
    );
    expect(
      Vec2(
        exploded.controlPoints[exploded.controlPoints.length - 2],
        exploded.controlPoints.last,
      ).distanceTo(spline.end),
      lessThan(1e-9),
    );
  });

  test('a trimmed rational spline keeps its weights', () {
    final spline = RegionSpline(
      controlPoints: Float64List.fromList([10, 0, 10, 2, 12, 2, 10, 2]),
      knots: const [0, 0, 0, 0, 1, 1, 1, 1],
      weights: const [1, 2, 1, 1],
      degree: 3,
      closed: false,
      rangeStart: 0.3,
      rangeEnd: 0.7,
    );
    final sub = spline.asSpline();
    expect(sub, isNotNull);
    expect(sub!.weights, hasLength(4));
    final originalMin = spline.knots[spline.degree];
    final originalMax = spline.knots[spline.controlPointCount];
    final subMin = sub.knots[sub.degree];
    final subMax = sub.knots[sub.controlPoints.length ~/ 2];
    for (var i = 0; i <= 10; i++) {
      final fraction = 0.3 + 0.4 * i / 10;
      final original = Flatten.bsplineEvaluate(
        controlPoints: spline.controlPoints,
        knots: spline.knots,
        degree: spline.degree,
        t: originalMin + (originalMax - originalMin) * fraction,
        weights: spline.weights,
      );
      final actual = Flatten.bsplineEvaluate(
        controlPoints: sub.controlPoints,
        knots: sub.knots,
        degree: sub.degree,
        t: subMin + (subMax - subMin) * (i / 10),
        weights: sub.weights,
      );
      expect(original, isNotNull);
      expect(actual, isNotNull);
      expect(original!.distanceTo(actual!), lessThan(1e-8));
    }
  });

  test('a mirrored region is re-normalised and stays exact', () {
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(
          outer: RegionLoop(const [
            RegionLine(start: Vec2(0, 0), end: Vec2(10, 0)),
            RegionLine(start: Vec2(10, 0), end: Vec2(10, 10)),
            RegionLine(start: Vec2(10, 10), end: Vec2(0, 10)),
            RegionLine(start: Vec2(0, 10), end: Vec2(0, 0)),
          ]),
        ),
      ],
    );
    final mirrored = region.transformed(Mat3.scaling(-1, 1));
    expect(mirrored.signedArea, closeTo(100, 1e-9));
    expect(mirrored.components.single.outer.signedArea, greaterThan(0));
    expect(mirrored.approximated, isFalse);
  });

  test('REGION object snaps include centres and quadrants', () {
    const circle = RegionConicArc(
      center: Vec2(0, 0),
      u: Vec2(10, 0),
      v: Vec2(0, 10),
      startParameter: 0,
      sweep: math.pi * 2,
    );
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(outer: RegionLoop([circle])),
      ],
    );
    final sink = _SnapCollector();
    region.emitObjectSnaps(sink);
    expect(sink.centers.single.distanceTo(Vec2.zero()), lessThan(1e-9));
    expect(sink.circles.single.$1.distanceTo(Vec2.zero()), lessThan(1e-9));
    expect(sink.circles.single.$2, closeTo(10, 1e-9));
    expect(
      sink.quadrants.map((point) => point.distanceTo(const Vec2(10, 0))),
      contains(lessThan(1e-9)),
    );
    expect(sink.quadrants, hasLength(4));
  });

  test('a partial conic only snaps to quadrants on its sweep', () {
    const arc = RegionConicArc(
      center: Vec2.zero(),
      u: Vec2(10, 0),
      v: Vec2(0, 5),
      startParameter: 0,
      sweep: math.pi / 2,
    );
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(outer: RegionLoop([arc])),
      ],
    );
    final sink = _SnapCollector();
    region.emitObjectSnaps(sink);
    expect(sink.quadrants, hasLength(2));
    expect(
      sink.quadrants.any((point) => point.distanceTo(const Vec2(10, 0)) < 1e-9),
      isTrue,
    );
    expect(
      sink.quadrants.any((point) => point.distanceTo(const Vec2(0, 5)) < 1e-9),
      isTrue,
    );
    expect(sink.endpoints, hasLength(2));
  });

  test('contains respects the outer loop and holes', () {
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(
          outer: RegionLoop(const [
            RegionLine(start: Vec2(0, 0), end: Vec2(100, 0)),
            RegionLine(start: Vec2(100, 0), end: Vec2(100, 100)),
            RegionLine(start: Vec2(100, 100), end: Vec2(0, 100)),
            RegionLine(start: Vec2(0, 100), end: Vec2(0, 0)),
          ]),
          holes: [
            RegionLoop([
              const RegionConicArc(
                center: Vec2(50, 50),
                u: Vec2(10, 0),
                v: Vec2(0, 10),
                startParameter: 0,
                sweep: math.pi * 2,
              ),
            ]),
          ],
        ),
      ],
    );
    expect(region.contains(const Vec2(10, 10)), isTrue);
    expect(region.contains(const Vec2(50, 50)), isFalse);
    expect(region.contains(const Vec2(200, 200)), isFalse);
  });

  test('emit draws every boundary as a closed polyline', () {
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(outer: RegionLoop([circle])),
      ],
    );
    final sink = PolylineSink();
    region.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.closedFlags.single, isTrue);
    expect(sink.fills, isEmpty);
  });

  test('moving a region keeps the shape and drops the source payload', () {
    final region = RegionEntity(
      id: 1,
      components: [
        RegionComponent(outer: RegionLoop([circle])),
      ],
      source: AcisPayload(
        format: 'sat',
        bytes: Uint8List.fromList('ACIS'.codeUnits),
      ),
    );
    final moved = region.transformed(Mat3.translation(100, 20));
    expect(moved.source, isNull);
    expect(moved.approximated, isFalse);
    expect(moved.signedArea, closeTo(region.signedArea, 1e-9));
    expect(moved.computeBounds().center.x, closeTo(100, 1e-9));
  });
}

class _SnapCollector implements ObjectSnapSink {
  final endpoints = <Vec2>[];
  final midpoints = <Vec2>[];
  final centers = <Vec2>[];
  final quadrants = <Vec2>[];
  final nodes = <Vec2>[];
  final segments = <(Vec2, Vec2)>[];
  final circles = <(Vec2, double)>[];

  @override
  void endpoint(Vec2 point) => endpoints.add(point);

  @override
  void midpoint(Vec2 point) => midpoints.add(point);

  @override
  void center(Vec2 point) => centers.add(point);

  @override
  void quadrant(Vec2 point) => quadrants.add(point);

  @override
  void node(Vec2 point) => nodes.add(point);

  @override
  void segment(Vec2 start, Vec2 end) => segments.add((start, end));

  @override
  void circle(Vec2 center, double radius) => circles.add((center, radius));
}

String _satSquare(List<Vec2> points) {
  final n = points.length;
  final middle =
      '700 0 1 0 \n'
      '8 FanCAD 8 ACIS 1.7.0 24 Thu Jan 01 00:00:00 1998 \n'
      '18 1e-6 1e-10 \n';
  final body = 0;
  final lump = 1;
  final shell = 2;
  final face = 3;
  final loop = 4;
  final co0 = 5;
  final ed0 = co0 + n;
  final v0 = ed0 + n;
  final p0 = v0 + n;
  final out = StringBuffer(middle);
  out.writeln('body \$-1 \$$lump \$-1 \$-1 #');
  out.writeln('lump \$-1 \$-1 \$$shell \$$body #');
  out.writeln('shell \$-1 \$-1 \$-1 \$$face \$-1 \$$lump #');
  out.writeln(
    'face \$-1 \$-1 \$$loop \$-1 \$$shell \$-1 \$-1 forward single #',
  );
  out.writeln('loop \$-1 \$-1 \$-1 \$$co0 \$$face #');
  for (var i = 0; i < n; i++) {
    final next = co0 + ((i + 1) % n);
    out.writeln(
      'coedge \$-1 \$-1 \$-1 \$$next \$-1 \$-1 \$${ed0 + i} forward #',
    );
  }
  for (var i = 0; i < n; i++) {
    final start = v0 + i;
    final end = v0 + ((i + 1) % n);
    out.writeln(
      'edge \$-1 \$-1 \$${co0 + i} \$$start \$$end \$-1 \$-1 \$${co0 + i} 0 1 #',
    );
  }
  for (var i = 0; i < n; i++) {
    out.writeln('vertex \$-1 \$-1 \$-1 \$${p0 + i} #');
  }
  for (var i = 0; i < n; i++) {
    out.writeln('point \$-1 \$-1 ${points[i].x} ${points[i].y} 0 #');
  }
  out.writeln('End-of-ACIS-data ');
  return out.toString();
}

void satReaderTest() {
  test('SAT reader rebuilds a square loop and its area', () {
    final geometry = const AcisSatReader().read(
      _satSquare(const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10), Vec2(0, 10)]),
    );
    expect(geometry, isNotNull);
    expect(geometry!.components, hasLength(1));
    expect(geometry.signedArea, closeTo(100, 1e-6));
    expect(geometry.bounds.width, closeTo(10, 1e-6));
  });
}
