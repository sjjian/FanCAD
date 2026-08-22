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
}
