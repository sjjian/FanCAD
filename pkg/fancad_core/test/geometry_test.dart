import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Mat3', () {
    test('composes translation after rotation in the expected order', () {
      final matrix = Mat3.translation(10, 0).multiplied(Mat3.rotation(math.pi / 2));
      final moved = matrix.transform(const Vec2(1, 0));
      expect(moved.x, closeTo(10, 1e-12));
      expect(moved.y, closeTo(1, 1e-12));
    });

    test('reports rotation, mean scale and handedness', () {
      final matrix = Mat3.rotation(math.pi / 3).multiplied(Mat3.scaling(2, 2));
      expect(matrix.rotation, closeTo(math.pi / 3, 1e-12));
      expect(matrix.meanScale, closeTo(2, 1e-12));
      expect(matrix.determinant, greaterThan(0));
      expect(Mat3.scaling(-1, 1).determinant, lessThan(0));
    });

    test('align with one pair is a translation', () {
      final matrix = Mat3.align(const Vec2(1, 2), const Vec2(4, 6));
      expect(matrix.transform(const Vec2(1, 2)), const Vec2(4, 6));
      expect(matrix.transform(const Vec2(2, 2)), const Vec2(5, 6));
    });

    test('align with two pairs rotates about the first destination', () {
      final matrix = Mat3.align(
        const Vec2(0, 0),
        const Vec2(0, 0),
        source2: const Vec2(10, 0),
        dest2: const Vec2(0, 10),
      );
      final moved = matrix.transform(const Vec2(10, 0));
      expect(moved.x, closeTo(0, 1e-12));
      expect(moved.y, closeTo(10, 1e-12));
    });

    test('align scale matches the two segment lengths', () {
      final matrix = Mat3.align(
        const Vec2(0, 0),
        const Vec2(0, 0),
        source2: const Vec2(10, 0),
        dest2: const Vec2(0, 5),
        scale: true,
      );
      final moved = matrix.transform(const Vec2(10, 0));
      expect(moved.x, closeTo(0, 1e-12));
      expect(moved.y, closeTo(5, 1e-12));
    });

    test('inverse round trips a point', () {
      final matrix = Mat3.translation(4, -7)
          .multiplied(Mat3.rotation(0.4))
          .multiplied(Mat3.scaling(3, 1.5));
      const point = Vec2(2.5, -1.25);
      final back = matrix.inverted()!.transform(matrix.transform(point));
      expect(back.x, closeTo(point.x, 1e-9));
      expect(back.y, closeTo(point.y, 1e-9));
    });
  });

  group('Bounds2', () {
    test('union of an empty box is the other box', () {
      const box = Bounds2(0, 0, 10, 5);
      expect(const Bounds2.empty().union(box), box);
    });

    test('detects intersection and containment', () {
      const outer = Bounds2(0, 0, 10, 10);
      expect(outer.intersects(const Bounds2(5, 5, 15, 15)), isTrue);
      expect(outer.intersects(const Bounds2(11, 11, 12, 12)), isFalse);
      expect(outer.containsBox(const Bounds2(2, 2, 3, 3)), isTrue);
      expect(outer.containsPoint(5, 5), isTrue);
    });
  });

  group('Flatten', () {
    test('a circle is discretised within tolerance', () {
      const radius = 100.0;
      const tolerance = 0.01;
      final points = Flatten.circle(
        center: const Vec2.zero(),
        radius: radius,
        tolerance: tolerance,
      );
      expect(points.length, greaterThanOrEqualTo(8));
      // Every chord midpoint must stay inside the tolerance band.
      for (var i = 0; i + 3 < points.length; i += 2) {
        final midX = (points[i] + points[i + 2]) / 2;
        final midY = (points[i + 1] + points[i + 3]) / 2;
        final sagitta = radius - math.sqrt(midX * midX + midY * midY);
        expect(sagitta, lessThan(tolerance * 1.5));
      }
    });

    test('a 90 degree bulge produces a quarter arc', () {
      final quarter = Flatten.bulgeArc(
        const Vec2(10, 0),
        const Vec2(0, 10),
        math.tan(math.pi / 8),
      );
      expect(quarter, isNotNull);
      expect(quarter!.center.x, closeTo(0, 1e-9));
      expect(quarter.center.y, closeTo(0, 1e-9));
      expect(quarter.radius, closeTo(10, 1e-9));

      final vertices = Float64List.fromList([
        0, 0, math.tan(math.pi / 8),
        10, 10, 0,
      ]);
      final points = Flatten.polylineWithBulges(
        vertices: vertices,
        closed: false,
        tolerance: 1e-4,
      );
      expect(points.first, closeTo(0, 1e-9));
      expect(points[points.length - 2], closeTo(10, 1e-6));
      expect(points.last, closeTo(10, 1e-6));
      // The arc bulges away from the chord, so some point must sit off it.
      var maxDeviation = 0.0;
      for (var i = 0; i < points.length; i += 2) {
        final deviation = (points[i] - points[i + 1]).abs();
        maxDeviation = math.max(maxDeviation, deviation);
      }
      expect(maxDeviation, greaterThan(1));
    });

    test('a wide open stroke is a strip around the centreline', () {
      final stroke = Flatten.wideStroke(
        Float64List.fromList([0, 0, 10, 0]),
        2,
        closed: false,
      );

      expect(stroke, isNotNull);
      expect(stroke!.hole, isNull);
      for (var i = 1; i < stroke.outer.length; i += 2) {
        expect(stroke.outer[i].abs(), closeTo(1, 1e-9));
      }
    });

    test('a wide closed ring keeps a hole in the middle', () {
      final stroke = Flatten.wideStroke(
        Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
        2,
        closed: true,
      );

      expect(stroke, isNotNull);
      expect(stroke!.hole, isNotNull);
      expect(Bounds2.fromXY(stroke.outer).width, closeTo(12, 1e-6));
      expect(Bounds2.fromXY(stroke.hole!).width, closeTo(8, 1e-6));
    });
  });

  group('SpatialIndex', () {
    test('finds only the entities inside the query box', () {
      final index = SpatialIndex();
      final entries = <int, Bounds2>{
        for (var i = 0; i < 500; i++)
          i: Bounds2(i * 10, 0, i * 10 + 5, 5),
      };
      index.bulkLoad(entries);
      final hits = index.search(const Bounds2(95, 0, 125, 5)).toList()..sort();
      expect(hits, [9, 10, 11, 12]);
    });

    test('reflects incremental inserts and removals', () {
      final index = SpatialIndex()
        ..bulkLoad({1: const Bounds2(0, 0, 1, 1)})
        ..insert(2, const Bounds2(5, 5, 6, 6));
      expect(index.search(const Bounds2(4, 4, 7, 7)), contains(2));
      index.remove(2);
      expect(index.search(const Bounds2(4, 4, 7, 7)), isEmpty);
    });

    test('window search requires full containment', () {
      final index = SpatialIndex()
        ..bulkLoad({
          1: const Bounds2(0, 0, 2, 2),
          2: const Bounds2(1, 1, 9, 9),
        });
      expect(
        index.searchContained(const Bounds2(0, 0, 4, 4)),
        [1],
      );
    });

    test('point search expands the query by the snap tolerance', () {
      final index = SpatialIndex()
        ..bulkLoad({1: const Bounds2(10, 10, 11, 11)});
      expect(index.searchPoint(10.5, 10.5, 1), contains(1));
      expect(index.searchPoint(0, 0, 1), isEmpty);
    });

    test('update moves an id and empty boxes never hit a window', () {
      final index = SpatialIndex()
        ..insert(1, const Bounds2(0, 0, 1, 1))
        ..update(1, const Bounds2(20, 20, 21, 21))
        ..insert(2, const Bounds2.empty());
      expect(index.contains(1), isTrue);
      expect(index.boundsOf(1), const Bounds2(20, 20, 21, 21));
      expect(index.search(const Bounds2(19, 19, 22, 22)), [1]);
      expect(index.search(const Bounds2(-1, -1, 2, 2)), isEmpty);
      expect(index.ids.toSet(), {1, 2});
      expect(index.length, 2);
      index.clear();
      expect(index.isEmpty, isTrue);
    });

    test('bounds ignore removed packed entries until rebuild', () {
      final index = SpatialIndex(nodeCapacity: 4);
      for (var i = 0; i < 20; i++) {
        index.insert(i, Bounds2(i * 2, 0, i * 2 + 1, 1));
      }
      index.rebuild();
      expect(index.bounds.isNotEmpty, isTrue);
      index.remove(0);
      expect(index.contains(0), isFalse);
      expect(index.search(const Bounds2(-1, -1, 1.5, 1.5)), isEmpty);
    });
  });

  group('entity geometry', () {
    test('arc bounds are exact, not the full circle', () {
      final arc = ArcEntity(
        id: 1,
        center: const Vec2.zero(),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      final bounds = arc.computeBounds();
      expect(bounds.minX, closeTo(0, 1e-9));
      expect(bounds.minY, closeTo(0, 1e-9));
      expect(bounds.maxX, closeTo(10, 1e-9));
      expect(bounds.maxY, closeTo(10, 1e-9));
    });

    test('a donut emits a filled ring instead of a thin centreline', () {
      final donut = Construct.donut(
        center: const Vec2.zero(),
        innerRadius: 3,
        outerRadius: 5,
      )!;
      final sink = PolylineSink();
      donut.emit(
        const EmitContext(tolerance: 0.1),
        sink,
      );
      expect(sink.fills, isNotEmpty);
      expect(sink.fills.first.length, greaterThan(8));
    });

    test('a non-uniform scale turns a circle into an ellipse', () {
      final circle = CircleEntity(
        id: 1,
        center: const Vec2.zero(),
        radius: 5,
      );
      final scaled = circle.transformed(Mat3.scaling(2, 1));
      expect(scaled, isA<EllipseEntity>());
      expect((scaled as EllipseEntity).ratio, closeTo(0.5, 1e-12));
    });

    test('MTEXT formatting codes are stripped for display', () {
      expect(
        stripMTextFormatting(r'{\fArial|b1;Bold}\Pnext'),
        'Bold\nnext',
      );
    });

    test('every entity kind survives a JSON round trip', () {
      final entities = <CadEntity>[
        LineEntity(id: 1, start: const Vec2(0, 0), end: const Vec2(1, 1)),
        PolylineEntity.fromPoints(
          id: 2,
          points: const [Vec2(0, 0), Vec2(1, 0), Vec2(1, 1)],
          closed: true,
        ),
        CircleEntity(id: 3, center: const Vec2(1, 2), radius: 3),
        ArcEntity(
          id: 4,
          center: const Vec2.zero(),
          radius: 2,
          startAngle: 0.1,
          endAngle: 1.2,
        ),
        EllipseEntity(
          id: 5,
          center: const Vec2.zero(),
          majorAxis: const Vec2(4, 0),
          ratio: 0.5,
        ),
        SplineEntity(
          id: 6,
          controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 1]),
          knots: const [0, 0, 0, 1, 1, 1],
          degree: 2,
        ),
        PointEntity(id: 7, position: const Vec2(9, 9)),
        TextEntity(id: 8, position: const Vec2.zero(), content: 'hi'),
        MTextEntity(id: 9, position: const Vec2.zero(), content: 'a\\Pb'),
        InsertEntity(id: 10, blockName: 'B', position: const Vec2(1, 1)),
        HatchEntity(
          id: 11,
          loops: [
            HatchLoop(vertices: Float64List.fromList([0, 0, 1, 0, 1, 1])),
          ],
        ),
        DimensionEntity(
          id: 12,
          definitionPoints: const [Vec2.zero(), Vec2(10, 0)],
          measurement: 10,
        ),
        LeaderEntity(id: 13, vertices: Float64List.fromList([0, 0, 5, 5])),
        SolidEntity(
          id: 14,
          corners: const [Vec2.zero(), Vec2(1, 0), Vec2(1, 1)],
        ),
        RayEntity(
          id: 15,
          origin: const Vec2.zero(),
          direction: const Vec2(1, 0),
        ),
        XLineEntity(
          id: 16,
          origin: const Vec2.zero(),
          direction: const Vec2(0, 1),
        ),
        ImageEntity(
          id: 17,
          reference: 'a.png',
          origin: const Vec2.zero(),
          uVector: const Vec2(1, 0),
          vVector: const Vec2(0, 1),
        ),
        const AttdefEntity(
          id: 19,
          position: Vec2(1, 2),
          tag: 'NO',
          defaultValue: 'A-00',
        ),
        const AttribEntity(
          id: 20,
          position: Vec2(1, 2),
          tag: 'NO',
          value: 'A-01',
        ),
        UnknownEntity(id: 18, originalType: 'ACAD_PROXY'),
      ];

      for (final entity in entities) {
        final restored = CadEntity.fromJson(entity.toJson());
        expect(restored.kind, entity.kind, reason: '${entity.kind}');
        expect(restored.id, entity.id);
        expect(
          restored.toJson().toString(),
          entity.toJson().toString(),
          reason: 'JSON is not stable for ${entity.kind}',
        );
      }
    });
  });

  group('LineWeight', () {
    test('parses millimetres, hundredths and sentinels', () {
      expect(LineWeight.tryParse('0.25'), 25);
      expect(LineWeight.tryParse('25'), 25);
      expect(LineWeight.tryParse('0.25mm'), 25);
      expect(LineWeight.tryParse('ByLayer'), LineWeight.byLayer);
      expect(LineWeight.tryParse('hairline'), LineWeight.zero);
    });

    test('rejects a weight thicker than the DXF maximum', () {
      expect(LineWeight.tryParse('300'), isNull);
      expect(LineWeight.tryParse('5mm'), isNull);
      expect(LineWeight.tryParse('nope'), isNull);
    });
  });

  group('Vec2', () {
    test('arithmetic, length and angles stay consistent', () {
      const a = Vec2(3, 4);
      const b = Vec2(1, -1);
      expect(a + b, const Vec2(4, 3));
      expect(a - b, const Vec2(2, 5));
      expect(a * 2, const Vec2(6, 8));
      expect(a / 2, const Vec2(1.5, 2));
      expect(-a, const Vec2(-3, -4));
      expect(a.length, closeTo(5, 1e-12));
      expect(a.lengthSquared, 25);
      expect(a.distanceTo(const Vec2.zero()), closeTo(5, 1e-12));
      expect(a.dot(const Vec2(4, -3)), 0);
      expect(const Vec2(1, 0).cross(const Vec2(0, 1)), 1);
      expect(const Vec2(1, 0).perpendicular, const Vec2(0, 1));
      expect(const Vec2(1, 0).angle, closeTo(0, 1e-12));
    });

    test('polar, normalize, rotate and lerp cover the remaining ops', () {
      final polar = Vec2.polar(math.pi / 2, 2);
      expect(polar.x, closeTo(0, 1e-12));
      expect(polar.y, closeTo(2, 1e-12));
      expect(const Vec2.zero().normalized(), const Vec2.zero());
      expect(const Vec2(0, 4).normalized(), const Vec2(0, 1));
      final turned = const Vec2(1, 0).rotated(math.pi / 2);
      expect(turned.x, closeTo(0, 1e-12));
      expect(turned.y, closeTo(1, 1e-12));
      expect(const Vec2(0, 0).lerp(const Vec2(10, 4), 0.25), const Vec2(2.5, 1));
      expect(const Vec2(1, 2).toVec3(3), const Vec3(1, 2, 3));
      expect(const Vec2(1, 2).isFinite, isTrue);
      expect(const Vec2(1, double.nan).isFinite, isFalse);
      expect(const Vec2(1, 2), const Vec2(1, 2));
      expect({const Vec2(1, 2)}.contains(const Vec2(1, 2)), isTrue);
      expect(const Vec2(1, 2).toString(), contains('1.0000'));
    });
  });

  group('Vec3', () {
    test('adds, scales and projects onto the drawing plane', () {
      const a = Vec3(1, 2, 3);
      expect(a + const Vec3(1, 1, 1), const Vec3(2, 3, 4));
      expect(a - const Vec3(1, 0, 1), const Vec3(0, 2, 2));
      expect(a * 2, const Vec3(2, 4, 6));
      expect(a.xy, const Vec2(1, 2));
      expect(a.length, closeTo(math.sqrt(14), 1e-12));
      expect(const Vec3.zero(), const Vec3(0, 0, 0));
      expect({a}.contains(const Vec3(1, 2, 3)), isTrue);
      expect(a.toString(), 'Vec3(1.0, 2.0, 3.0)');
    });
  });

  group('angles', () {
    test('normalize wraps into a half-open turn', () {
      expect(normalizeAngle(0), 0);
      expect(normalizeAngle(math.pi * 2), closeTo(0, 1e-12));
      expect(normalizeAngle(-math.pi / 2), closeTo(math.pi * 1.5, 1e-12));
    });

    test('angular sweep is always counter-clockwise and non-negative', () {
      expect(angularSweep(0, math.pi / 2), closeTo(math.pi / 2, 1e-12));
      expect(angularSweep(math.pi / 2, 0), closeTo(math.pi * 1.5, 1e-12));
      expect(angularSweep(0, 0), 0);
    });
  });

  group('Bounds2 extras', () {
    test('factories and metrics treat empty as the fold identity', () {
      expect(Bounds2.fromPoints(const []), const Bounds2.empty());
      expect(
        Bounds2.fromPoints(const [Vec2(2, 5), Vec2(-1, 1)]),
        const Bounds2(-1, 1, 2, 5),
      );
      expect(
        Bounds2.fromCorners(const Vec2(4, 1), const Vec2(0, 3)),
        const Bounds2(0, 1, 4, 3),
      );
      expect(Bounds2.fromXY(Float64List(0)), const Bounds2.empty());
      const empty = Bounds2.empty();
      expect(empty.width, 0);
      expect(empty.height, 0);
      expect(empty.area, 0);
      expect(empty.inflated(2), empty);
      expect(empty.transformed(Mat3.translation(1, 1)), empty);
      expect(empty.containsBox(const Bounds2.empty()), isTrue);
      expect(empty.toString(), 'Bounds2.empty');
    });

    test('union, inflate and transform keep the enclosing box', () {
      const box = Bounds2(0, 0, 10, 4);
      expect(box.union(const Bounds2.empty()), box);
      expect(box.inflated(1), const Bounds2(-1, -1, 11, 5));
      expect(box.center, const Vec2(5, 2));
      expect(box.min, const Vec2.zero());
      expect(box.max, const Vec2(10, 4));
      expect(box.diagonal, closeTo(math.sqrt(116), 1e-12));
      final rotated = box.transformed(Mat3.rotation(math.pi / 2));
      expect(rotated.minX, closeTo(-4, 1e-12));
      expect(rotated.maxY, closeTo(10, 1e-12));
      expect(box.enlargementFor(const Bounds2(8, -2, 12, 1)), greaterThan(0));
      expect(box, const Bounds2(0, 0, 10, 4));
      expect({box}.contains(const Bounds2(0, 0, 10, 4)), isTrue);
    });
  });

  group('Mat3 extras', () {
    test('rotation and scale about a centre leave that centre fixed', () {
      const pivot = Vec2(10, 4);
      final rotated = Mat3.rotationAbout(math.pi / 2, pivot);
      expect(rotated.transform(pivot).x, closeTo(10, 1e-12));
      expect(rotated.transform(pivot).y, closeTo(4, 1e-12));
      final scaled = Mat3.scalingAbout(2, 3, pivot);
      expect(scaled.transform(pivot), pivot);
      expect(scaled.transform(const Vec2(11, 4)), const Vec2(12, 4));
    });

    test('align with a collapsed second pair stays a translation', () {
      final matrix = Mat3.align(
        const Vec2(1, 1),
        const Vec2(4, 5),
        source2: const Vec2(1, 1),
        dest2: const Vec2(9, 9),
      );
      expect(matrix.transform(const Vec2(1, 1)), const Vec2(4, 5));
    });

    test('mirror flips a point across the given axis', () {
      final mirrored = Mat3.mirror(const Vec2.zero(), const Vec2(0, 1));
      final image = mirrored.transform(const Vec2(3, 2));
      expect(image.x, closeTo(-3, 1e-12));
      expect(image.y, closeTo(2, 1e-12));
    });

    test('identity, direction and inverse cover the remaining ops', () {
      const id = Mat3.identity();
      expect(id.isIdentity, isTrue);
      expect(id.transformDirection(const Vec2(2, 0)), const Vec2(2, 0));
      final out = <double>[0, 0];
      Mat3.translation(1, 2).transformXYInto(3, 4, out, 0);
      expect(out, [4.0, 6.0]);
      expect(const Mat3.scaling(1, 0).inverted(), isNull);
      expect(id, const Mat3.identity());
      expect({id}.contains(const Mat3.identity()), isTrue);
      expect(id.toString(), contains('Mat3'));
    });
  });

  group('Intersect', () {
    test('line and segment crossings honour parallelism and range', () {
      expect(
        Intersect.lineLine(
          const Vec2(0, 0),
          const Vec2(2, 0),
          const Vec2(1, -1),
          const Vec2(1, 1),
        ),
        const Vec2(1, 0),
      );
      expect(
        Intersect.lineLine(
          const Vec2(0, 0),
          const Vec2(1, 0),
          const Vec2(0, 1),
          const Vec2(1, 1),
        ),
        isNull,
      );
      expect(
        Intersect.segmentSegment(
          const Vec2(0, 0),
          const Vec2(2, 0),
          const Vec2(1, -1),
          const Vec2(1, 1),
        ),
        const Vec2(1, 0),
      );
      expect(
        Intersect.segmentSegment(
          const Vec2(0, 0),
          const Vec2(1, 0),
          const Vec2(2, -1),
          const Vec2(2, 1),
        ),
        isNull,
      );
    });

    test('circle intersections include tangent and empty cases', () {
      final two = Intersect.lineCircle(
        const Vec2(-2, 0),
        const Vec2(2, 0),
        const Vec2.zero(),
        1,
      );
      expect(two.length, 2);
      expect(two.map((p) => p.x).toList()..sort(), [-1.0, 1.0]);
      expect(
        Intersect.lineCircle(
          const Vec2(-2, 1),
          const Vec2(2, 1),
          const Vec2.zero(),
          1,
        ),
        [const Vec2(0, 1)],
      );
      expect(
        Intersect.lineCircle(
          const Vec2(0, 0),
          const Vec2(0, 0),
          const Vec2.zero(),
          1,
        ),
        isEmpty,
      );
      expect(
        Intersect.circleCircle(
          const Vec2.zero(),
          5,
          const Vec2(8, 0),
          5,
        ).length,
        2,
      );
      expect(
        Intersect.circleCircle(const Vec2.zero(), 5, const Vec2(10, 0), 5),
        [const Vec2(5, 0)],
      );
      expect(
        Intersect.circleCircle(const Vec2.zero(), 1, const Vec2.zero(), 2),
        isEmpty,
      );
      expect(
        Intersect.circleCircle(const Vec2.zero(), 1, const Vec2(10, 0), 1),
        isEmpty,
      );
    });

    test('closest-point helpers clamp to the segment and polyline', () {
      expect(
        Intersect.closestPointOnSegment(
          const Vec2(5, 3),
          const Vec2(0, 0),
          const Vec2(10, 0),
        ),
        const Vec2(5, 0),
      );
      expect(
        Intersect.closestPointOnSegment(
          const Vec2(-2, 1),
          const Vec2(0, 0),
          const Vec2(10, 0),
        ),
        const Vec2.zero(),
      );
      expect(
        Intersect.distanceToSegment(
          const Vec2(5, 4),
          const Vec2(0, 0),
          const Vec2(10, 0),
        ),
        4,
      );
      expect(
        Intersect.closestPointOnPolyline(const Vec2(1, 1), Float64List(0)),
        isNull,
      );
      final single = Intersect.closestPointOnPolyline(
        const Vec2(3, 4),
        Float64List.fromList([0, 0]),
      )!;
      expect(single.distance, closeTo(5, 1e-12));
      final hit = Intersect.closestPointOnPolyline(
        const Vec2(5, 1),
        Float64List.fromList([0, 0, 10, 0, 10, 10]),
      )!;
      expect(hit.point, const Vec2(5, 0));
      expect(hit.segmentIndex, 0);
    });

    test('polygon containment and window crossing use even-odd hits', () {
      final square = Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]);
      expect(Intersect.polygonContains(square, const Vec2(5, 5)), isTrue);
      expect(Intersect.polygonContains(square, const Vec2(15, 5)), isFalse);
      expect(
        Intersect.polygonContains(Float64List.fromList([0, 0, 1, 0]), const Vec2.zero()),
        isFalse,
      );
      expect(
        Intersect.polylineCrossesRect(
          Float64List.fromList([0, 0, 10, 10]),
          4,
          4,
          6,
          6,
        ),
        isTrue,
      );
      expect(
        Intersect.polylineCrossesRect(square, -1, -1, 11, 11, closed: true),
        isTrue,
      );
      expect(
        Intersect.polylineCrossesRect(
          Float64List.fromList([20, 20, 30, 20]),
          0,
          0,
          5,
          5,
        ),
        isFalse,
      );
      expect(
        Intersect.polylineCrossesRect(Float64List.fromList([2, 2]), 0, 0, 5, 5),
        isTrue,
      );
      expect(Intersect.polylineCrossesRect(Float64List(0), 0, 0, 1, 1), isFalse);
    });

    test('line-ellipse hits are the unit-circle hits mapped back', () {
      final axis = Intersect.lineEllipse(
        const Vec2(-4, 0),
        const Vec2(4, 0),
        const Vec2.zero(),
        const Vec2(2, 0),
        0.5,
      );
      expect(axis.length, 2);
      final xs = axis.map((p) => p.x).toList()..sort();
      expect(xs[0], closeTo(-2, 1e-9));
      expect(xs[1], closeTo(2, 1e-9));
      expect(axis.every((p) => p.y.abs() < 1e-9), isTrue);

      final chord = Intersect.lineEllipse(
        const Vec2(-4, 0.5),
        const Vec2(4, 0.5),
        const Vec2.zero(),
        const Vec2(2, 0),
        0.5,
      );
      expect(chord.length, 2);
      for (final hit in chord) {
        expect(hit.y, closeTo(0.5, 1e-9));
        expect(hit.x.abs(), closeTo(math.sqrt(3), 1e-8));
      }
      expect(
        Intersect.segmentEllipse(
          const Vec2(3, -1),
          const Vec2(3, 1),
          const Vec2.zero(),
          const Vec2(2, 0),
          0.5,
        ),
        isEmpty,
      );
    });

    test('line-spline refine lands on the curve, not just a chord', () {
      final controls = Float64List.fromList([0, 0, 1, 3, 3, 3, 4, 0]);
      const knots = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
      final hits = Intersect.lineSpline(
        const Vec2(-1, 1),
        const Vec2(5, 1),
        controls,
        knots: knots,
        degree: 3,
        tolerance: 0.4,
      );
      // y = 9t(1-t) = 1 on this clamped cubic.
      final roots = [
        (9 - math.sqrt(45)) / 18,
        (9 + math.sqrt(45)) / 18,
      ];
      final expected = [
        for (final t in roots)
          Flatten.bsplineEvaluate(
            controlPoints: controls,
            knots: knots,
            degree: 3,
            t: t,
          )!,
      ];
      expect(hits, hasLength(2));
      for (final hit in hits) {
        expect(hit.y, closeTo(1, 1e-9));
        expect(
          expected.map((point) => point.distanceTo(hit)).reduce(math.min),
          lessThan(1e-6),
        );
      }
    });

    test('circle-ellipse includes the two-circle case', () {
      final hits = Intersect.circleEllipse(
        const Vec2(1, 0),
        1,
        const Vec2.zero(),
        const Vec2(1, 0),
        1,
      );
      expect(hits.length, 2);
      for (final hit in hits) {
        expect(hit.x, closeTo(0.5, 1e-6));
        expect(hit.y.abs(), closeTo(math.sqrt(3) / 2, 1e-6));
      }
    });
  });

  group('Flatten extras', () {
    test('arc and ellipse sample the expected endpoints', () {
      expect(Flatten.arcSegmentCount(0, math.pi, 0.1), 1);
      expect(Flatten.arcSegmentCount(10, 0, 0.1), 1);
      expect(Flatten.arcSegmentCount(10, math.pi, 0), Flatten.minSegments);
      final quarter = Flatten.arc(
        center: const Vec2.zero(),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
        tolerance: 0.05,
      );
      expect(quarter[0], closeTo(10, 1e-9));
      expect(quarter[1], closeTo(0, 1e-9));
      expect(quarter[quarter.length - 2], closeTo(0, 1e-6));
      expect(quarter.last, closeTo(10, 1e-6));
      final oval = Flatten.ellipse(
        center: const Vec2.zero(),
        major: const Vec2(4, 0),
        ratio: 0.5,
        startParam: 0,
        endParam: math.pi * 2,
        tolerance: 0.1,
      );
      expect(oval.length, greaterThan(8));
      expect(oval[0], closeTo(4, 1e-9));
    });

    test('bulge helpers skip straight and degenerate segments', () {
      expect(
        Flatten.bulgeArc(const Vec2.zero(), const Vec2(1, 0), 0),
        isNull,
      );
      expect(
        Flatten.bulgeArc(const Vec2.zero(), const Vec2.zero(), 1),
        isNull,
      );
      expect(
        Flatten.polylineWithBulges(
          vertices: Float64List(0),
          closed: false,
          tolerance: 0.1,
        ),
        isEmpty,
      );
      expect(
        Flatten.polylineWithBulges(
          vertices: Float64List.fromList([1, 2, 0]),
          closed: false,
          tolerance: 0.1,
        ),
        [1.0, 2.0],
      );
      final clockwise = Flatten.polylineWithBulges(
        vertices: Float64List.fromList([
          10,
          0,
          -math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
        closed: false,
        tolerance: 1e-3,
      );
      expect(clockwise.first, closeTo(10, 1e-9));
      expect(clockwise.last, closeTo(10, 1e-6));
    });

    test('a clamped cubic NURBS evaluates the endpoints', () {
      final controls = Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]);
      const knots = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
      final samples = Flatten.bspline(
        controlPoints: controls,
        knots: knots,
        degree: 3,
        tolerance: 0.1,
      );
      expect(samples[0], closeTo(0, 1e-9));
      expect(samples[1], closeTo(0, 1e-9));
      expect(samples[samples.length - 2], closeTo(4, 1e-6));
      expect(samples.last, closeTo(0, 1e-6));
      expect(
        Flatten.bsplineEvaluate(
          controlPoints: controls,
          knots: knots,
          degree: 3,
          t: 0,
        ),
        const Vec2.zero(),
      );
      expect(
        Flatten.bspline(
          controlPoints: controls,
          knots: const [0, 1],
          degree: 3,
          tolerance: 0.1,
        ),
        controls,
      );
      expect(
        Flatten.bsplineBasis(
          knots: knots,
          count: 4,
          degree: 3,
          t: 0,
        ).first,
        closeTo(1, 1e-12),
      );
    });

    test('wideStroke refuses a zero-width or single-point path', () {
      expect(
        Flatten.wideStroke(Float64List.fromList([0, 0, 1, 0]), 0, closed: false),
        isNull,
      );
      expect(
        Flatten.wideStroke(Float64List.fromList([0, 0]), 2, closed: false),
        isNull,
      );
    });
  });
}
