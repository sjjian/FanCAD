import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

/// Tests for the analytic constructions behind the editing commands.
///
/// These are worth testing directly rather than through the commands: every one
/// is a closed-form geometry result with a right answer, and a sign error in any
/// of them produces geometry that looks plausible but is wrong.
void main() {
  LineEntity line(double x1, double y1, double x2, double y2) => LineEntity(
    id: 1,
    start: Vec2(x1, y1),
    end: Vec2(x2, y2),
  );

  group('arcThrough', () {
    test('finds the circumscribed arc of three points', () {
      final arc = Construct.arcThrough(
        const Vec2(1, 0),
        const Vec2(0, 1),
        const Vec2(-1, 0),
      );

      expect(arc, isNotNull);
      expect(arc!.center.x, closeTo(0, 1e-9));
      expect(arc.center.y, closeTo(0, 1e-9));
      expect(arc.radius, closeTo(1, 1e-9));
      // Counter-clockwise from 0 to pi passes through (0, 1) as required.
      expect(arc.sweep, closeTo(math.pi, 1e-9));
    });

    test('reverses the sweep when the middle point is on the other side', () {
      final arc = Construct.arcThrough(
        const Vec2(1, 0),
        const Vec2(0, -1),
        const Vec2(-1, 0),
      );

      expect(arc, isNotNull);
      expect(arc!.sweep, closeTo(math.pi, 1e-9));
      // The arc must actually contain the via point, which means starting at pi.
      expect(arc.startAngle, closeTo(math.pi, 1e-9));
    });

    test('returns null for collinear points', () {
      expect(
        Construct.arcThrough(
          const Vec2(0, 0),
          const Vec2(1, 1),
          const Vec2(2, 2),
        ),
        isNull,
      );
    });
  });

  group('circleThrough', () {
    test('finds the circumcircle of three points', () {
      final circle = Construct.circleThrough(
        const Vec2(1, 0),
        const Vec2(0, 1),
        const Vec2(-1, 0),
      );

      expect(circle, isNotNull);
      expect(circle!.center.x, closeTo(0, 1e-9));
      expect(circle.center.y, closeTo(0, 1e-9));
      expect(circle.radius, closeTo(1, 1e-9));
    });

    test('returns null for collinear points', () {
      expect(
        Construct.circleThrough(
          const Vec2(0, 0),
          const Vec2(1, 1),
          const Vec2(2, 2),
        ),
        isNull,
      );
    });
  });

  group('circleTangentRadius', () {
    test('sits in the picked quadrant of two crossing lines', () {
      final circle = Construct.circleTangentRadius(
        line(0, 10, 0, 0),
        line(0, 0, 10, 0),
        2,
        const Vec2(0, 5),
        const Vec2(5, 0),
      );

      expect(circle, isNotNull);
      expect(circle!.center.x, closeTo(2, 1e-9));
      expect(circle.center.y, closeTo(2, 1e-9));
      expect(circle.radius, closeTo(2, 1e-9));
    });

    test('refuses a non-positive radius', () {
      expect(
        Construct.circleTangentRadius(
          line(0, 10, 0, 0),
          line(0, 0, 10, 0),
          0,
          const Vec2(0, 5),
          const Vec2(5, 0),
        ),
        isNull,
      );
    });

    test('finds an external tangent to a line and a circle', () {
      final circle = Construct.circleTangentRadius(
        line(-10, 0, 10, 0),
        const CircleEntity(id: 2, center: Vec2(0, 5), radius: 3),
        1,
        const Vec2(0, 1),
        const Vec2(0, 10),
      );

      expect(circle, isNotNull);
      expect(circle!.center.x, closeTo(0, 1e-9));
      expect(circle.center.y, closeTo(1, 1e-9));
    });
  });

  group('ellipse', () {
    test('stores the shorter radius as a ratio', () {
      final ellipse = Construct.ellipse(
        center: const Vec2(0, 0),
        axisEnd: const Vec2(10, 0),
        otherRadius: 4,
      );

      expect(ellipse, isNotNull);
      expect(ellipse!.majorAxis.x, closeTo(10, 1e-9));
      expect(ellipse.ratio, closeTo(0.4, 1e-9));
    });

    test('swaps axes when the other radius is longer', () {
      final ellipse = Construct.ellipse(
        center: const Vec2(0, 0),
        axisEnd: const Vec2(6, 0),
        otherRadius: 10,
      );

      expect(ellipse, isNotNull);
      expect(ellipse!.majorAxis.length, closeTo(10, 1e-9));
      expect(ellipse.ratio, closeTo(0.6, 1e-9));
    });

    test('returns null for a degenerate axis', () {
      expect(
        Construct.ellipse(
          center: const Vec2(1, 1),
          axisEnd: const Vec2(1, 1),
          otherRadius: 5,
        ),
        isNull,
      );
    });
  });

  group('splineFromControls', () {
    test('four points become a cubic Bezier span', () {
      final spline = Construct.splineFromControls(const [
        Vec2(0, 0),
        Vec2(1, 2),
        Vec2(3, 2),
        Vec2(4, 0),
      ]);

      expect(spline, isNotNull);
      expect(spline!.degree, 3);
      expect(spline.controlPointCount, 4);
      expect(spline.knots, [0, 0, 0, 0, 1, 1, 1, 1]);
    });

    test('five points insert one interior knot', () {
      final spline = Construct.splineFromControls(const [
        Vec2(0, 0),
        Vec2(1, 1),
        Vec2(2, 0),
        Vec2(3, 1),
        Vec2(4, 0),
      ]);

      expect(spline!.knots, [0, 0, 0, 0, 0.5, 1, 1, 1, 1]);
    });

    test('two points drop to a degree-1 span', () {
      final spline = Construct.splineFromControls(const [
        Vec2(0, 0),
        Vec2(10, 0),
      ]);

      expect(spline!.degree, 1);
      expect(spline.knots, [0, 0, 1, 1]);
    });
  });

  group('donut', () {
    test('stores a wide circular polyline on the average radius', () {
      final donut = Construct.donut(
        center: const Vec2(0, 0),
        innerRadius: 3,
        outerRadius: 5,
      );

      expect(donut, isNotNull);
      expect(donut!.closed, isTrue);
      expect(donut.constantWidth, closeTo(2, 1e-9));
      expect(donut.vertexCount, 2);
      expect(donut.vertexAt(0).x, closeTo(-4, 1e-9));
      expect(donut.vertexAt(1).x, closeTo(4, 1e-9));
      expect(donut.bulgeAt(0), closeTo(1, 1e-9));
    });

    test('swaps inverted radii and treats a zero inner as a disk', () {
      final disk = Construct.donut(
        center: const Vec2(1, 1),
        innerRadius: 10,
        outerRadius: 0,
      );

      expect(disk!.constantWidth, closeTo(10, 1e-9));
      expect(disk.vertexAt(0).distanceTo(const Vec2(1, 1)), closeTo(5, 1e-9));
    });

    test('returns null when both radii vanish', () {
      expect(
        Construct.donut(
          center: const Vec2.zero(),
          innerRadius: 0,
          outerRadius: 0,
        ),
        isNull,
      );
    });
  });

  group('polygon', () {
    test('inscribes vertices on the circle', () {
      final hexagon = Construct.polygon(
        center: const Vec2(0, 0),
        radius: 10,
        sides: 6,
      );

      expect(hexagon.vertexCount, 6);
      expect(hexagon.closed, isTrue);
      for (var i = 0; i < 6; i++) {
        expect(hexagon.vertexAt(i).length, closeTo(10, 1e-9));
      }
    });

    test('circumscribes by growing the vertex radius', () {
      final square = Construct.polygon(
        center: const Vec2(0, 0),
        radius: 10,
        sides: 4,
        circumscribed: true,
      );

      // The edge midpoints, not the vertices, must sit on the circle.
      final midpoint = square.vertexAt(0).lerp(square.vertexAt(1), 0.5);
      expect(midpoint.length, closeTo(10, 1e-9));
    });

    test('clamps degenerate side counts to a triangle', () {
      final polygon = Construct.polygon(
        center: const Vec2(0, 0),
        radius: 1,
        sides: 1,
      );
      expect(polygon.vertexCount, 3);
    });
  });

  group('offset', () {
    test('offsets a line to the side of the pick point', () {
      final source = line(0, 0, 10, 0);

      final above = Construct.offset(source, 2, const Vec2(5, 5));
      expect(above, isA<LineEntity>());
      expect((above! as LineEntity).start.y, closeTo(2, 1e-9));

      final below = Construct.offset(source, 2, const Vec2(5, -5));
      expect((below! as LineEntity).start.y, closeTo(-2, 1e-9));
    });

    test('offsets a circle outwards or inwards by the pick side', () {
      const source = CircleEntity(
        id: 1,
        center: Vec2(0, 0),
        radius: 10,
      );

      final outer = Construct.offset(source, 2, const Vec2(20, 0));
      expect((outer! as CircleEntity).radius, closeTo(12, 1e-9));

      final inner = Construct.offset(source, 2, const Vec2(1, 0));
      expect((inner! as CircleEntity).radius, closeTo(8, 1e-9));
    });

    test('refuses an inward circle offset that would collapse it', () {
      const source = CircleEntity(id: 1, center: Vec2(0, 0), radius: 5);
      expect(Construct.offset(source, 5, const Vec2(0, 0)), isNull);
      expect(Construct.offset(source, 9, const Vec2(0, 0)), isNull);
    });

    test('mitres a rectangle offset into another rectangle', () {
      final source = Construct.rectangle(
        const Vec2(0, 0),
        const Vec2(10, 10),
      )!;

      final offset = Construct.offset(source, 1, const Vec2(20, 5));
      expect(offset, isA<PolylineEntity>());
      final result = offset! as PolylineEntity;
      expect(result.closed, isTrue);
      expect(result.vertexCount, 4);

      // A mitred outward offset of a rectangle is the rectangle grown by the
      // distance on every side; a round join would not give exact corners.
      final box = Bounds2.fromPoints([
        for (var i = 0; i < result.vertexCount; i++) result.vertexAt(i),
      ]);
      expect(box.minX, closeTo(-1, 1e-9));
      expect(box.minY, closeTo(-1, 1e-9));
      expect(box.maxX, closeTo(11, 1e-9));
      expect(box.maxY, closeTo(11, 1e-9));
    });

    test('returns null for types it cannot offset', () {
      const text = TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'x',
      );
      expect(Construct.offset(text, 1, const Vec2(1, 1)), isNull);
    });
  });

  group('trimLine', () {
    test('removes the picked end back to the crossing', () {
      final source = line(0, 0, 10, 0);

      final trimmed = Construct.trimLine(
        source,
        [const Vec2(4, 0)],
        const Vec2(8, 0),
      );

      expect(trimmed, isNotNull);
      expect(trimmed!.start.x, closeTo(0, 1e-9));
      expect(trimmed.end.x, closeTo(4, 1e-9));
    });

    test('removes the other end when the pick is on it', () {
      final trimmed = Construct.trimLine(
        line(0, 0, 10, 0),
        [const Vec2(4, 0)],
        const Vec2(1, 0),
      );

      expect(trimmed!.start.x, closeTo(4, 1e-9));
      expect(trimmed.end.x, closeTo(10, 1e-9));
    });

    test('keeps the longer remnant when trimming out of the middle', () {
      // Two cuts with the pick between them would properly yield two lines.
      // Keeping the longer piece is the documented compromise; what matters is
      // that it is the longer one.
      final trimmed = Construct.trimLine(
        line(0, 0, 10, 0),
        [const Vec2(2, 0), const Vec2(4, 0)],
        const Vec2(3, 0),
      );

      expect(trimmed, isNotNull);
      expect(trimmed!.start.x, closeTo(4, 1e-9));
      expect(trimmed.end.x, closeTo(10, 1e-9));
    });

    test('returns null when there is nothing to cut against', () {
      expect(
        Construct.trimLine(line(0, 0, 10, 0), const [], const Vec2(5, 0)),
        isNull,
      );
    });
  });

  group('trimPolyline', () {
    final elbow = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
    );

    test('removes the picked tail back to the crossing', () {
      final trimmed = Construct.trimPolyline(
        elbow,
        const [Vec2(5, 0)],
        const Vec2(8, 0),
      );

      expect(trimmed, isNotNull);
      expect(trimmed!.vertexCount, 2);
      expect(trimmed.vertexAt(1).x, closeTo(5, 1e-9));
    });

    test('keeps the far side when the pick is on the start remnant', () {
      final trimmed = Construct.trimPolyline(
        elbow,
        const [Vec2(5, 0)],
        const Vec2(1, 0),
      );

      expect(trimmed!.vertexAt(0).x, closeTo(5, 1e-9));
      expect(trimmed.vertexAt(trimmed.vertexCount - 1), const Vec2(10, 10));
    });

    test('trims past a corner to a crossing on the second segment', () {
      final trimmed = Construct.trimPolyline(
        elbow,
        const [Vec2(10, 5)],
        const Vec2(10, 8),
      );

      expect(trimmed!.vertexCount, 3);
      expect(trimmed.vertexAt(2).y, closeTo(5, 1e-9));
    });
  });

  group('trimArc', () {
    final semicircle = ArcEntity(
      id: 1,
      center: const Vec2(0, 0),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi,
    );

    test('removes the picked end back to the crossing', () {
      final trimmed = Construct.trimArc(
        semicircle,
        const [Vec2(0, 10)],
        const Vec2(8, 6),
      );

      expect(trimmed, isNotNull);
      expect(trimmed!.startAngle, closeTo(math.pi / 2, 1e-9));
      expect(trimmed.endAngle, closeTo(math.pi, 1e-9));
    });

    test('removes the other end when the pick is on it', () {
      final trimmed = Construct.trimArc(
        semicircle,
        const [Vec2(0, 10)],
        const Vec2(-8, 6),
      );

      expect(trimmed!.startAngle, closeTo(0, 1e-9));
      expect(trimmed.endAngle, closeTo(math.pi / 2, 1e-9));
    });

    test('returns null when there is nothing to cut against', () {
      expect(
        Construct.trimArc(semicircle, const [], const Vec2(0, 10)),
        isNull,
      );
    });
  });

  group('extendLine', () {
    test('lengthens forward to meet a boundary segment', () {
      final extended = Construct.extendLine(line(0, 0, 5, 0), [
        line(10, -5, 10, 5),
      ]);

      expect(extended, isNotNull);
      expect(extended!.start.x, closeTo(0, 1e-9));
      expect(extended.end.x, closeTo(10, 1e-9));
    });

    test('lengthens backwards when the boundary is behind the start', () {
      final extended = Construct.extendLine(line(5, 0, 10, 0), [
        line(0, -5, 0, 5),
      ]);

      expect(extended!.start.x, closeTo(0, 1e-9));
      expect(extended.end.x, closeTo(10, 1e-9));
    });

    test('ignores a boundary the extension would miss', () {
      // The infinite line crosses x = 10, but not within the edge's extent.
      expect(
        Construct.extendLine(line(0, 0, 5, 0), [line(10, 20, 10, 30)]),
        isNull,
      );
    });

    test('stops at the nearest of several boundaries', () {
      final extended = Construct.extendLine(line(0, 0, 1, 0), [
        line(20, -5, 20, 5),
        line(8, -5, 8, 5),
      ]);

      expect(extended!.end.x, closeTo(8, 1e-9));
    });

    test('extends to a circle', () {
      final extended = Construct.extendLine(line(0, 0, 1, 0), [
        const CircleEntity(id: 2, center: Vec2(0, 0), radius: 6),
      ]);

      expect(extended!.end.x, closeTo(6, 1e-9));
    });

    test('extends to a polyline boundary', () {
      final wall = PolylineEntity.fromPoints(
        id: 2,
        points: const [Vec2(10, -5), Vec2(10, 5)],
      );
      final extended = Construct.extendLine(line(0, 0, 5, 0), [wall]);

      expect(extended!.end.x, closeTo(10, 1e-9));
    });
  });

  group('extendPolyline', () {
    test('grows the last segment to meet a boundary', () {
      final elbow = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 5)],
      );
      final extended = Construct.extendPolyline(elbow, [
        line(5, 10, 15, 10),
      ]);

      expect(extended, isNotNull);
      expect(extended!.vertexAt(2).y, closeTo(10, 1e-9));
      expect(extended.vertexAt(1), const Vec2(10, 0));
    });

    test('grows the first segment when that end is nearer the pick', () {
      final elbow = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(5, 0), Vec2(10, 0), Vec2(10, 10)],
      );
      final extended = Construct.extendPolyline(
        elbow,
        [line(0, -5, 0, 5)],
        const Vec2(5, 0),
      );

      expect(extended!.vertexAt(0).x, closeTo(0, 1e-9));
      expect(extended.vertexAt(2), const Vec2(10, 10));
    });

    test('refuses a closed polyline', () {
      expect(
        Construct.extendPolyline(
          Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!,
          [line(20, -5, 20, 5)],
        ),
        isNull,
      );
    });
  });

  group('extendArc', () {
    const quarter = ArcEntity(
      id: 1,
      center: Vec2(0, 0),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );

    test('grows the end until it meets a boundary', () {
      final extended = Construct.extendArc(quarter, [
        line(-15, 0, -5, 0),
      ]);

      expect(extended, isNotNull);
      expect(extended!.startAngle, closeTo(0, 1e-9));
      expect(extended.endAngle, closeTo(math.pi, 1e-9));
    });

    test('grows the start when that end is nearer the pick', () {
      final extended = Construct.extendArc(
        quarter,
        [line(-5, -10, 5, -10)],
        const Vec2(10, 0),
      );

      expect(extended!.startAngle, closeTo(-math.pi / 2, 1e-9));
      expect(extended.endAngle, closeTo(math.pi / 2, 1e-9));
    });

    test('stops at the nearest boundary in that direction', () {
      final extended = Construct.extendArc(quarter, [
        line(-15, 0, -5, 0),
        line(-8, 20, -8, 5),
      ]);

      expect(extended!.startAngle, closeTo(0, 1e-9));
      expect(extended.endAngle, closeTo(math.atan2(6, -8), 1e-9));
    });

    test('ignores a boundary the circle would miss', () {
      expect(
        Construct.extendArc(quarter, [line(-10, 20, -10, 15)]),
        isNull,
      );
    });
  });

  group('filletLines', () {
    test('rounds an L-corner with a quarter-circle', () {
      final result = Construct.filletLines(
        line(0, 10, 0, 0),
        line(0, 0, 10, 0),
        2,
        const Vec2(0, 5),
        const Vec2(5, 0),
      );

      expect(result, isNotNull);
      expect(result!.first.start.x, closeTo(0, 1e-9));
      expect(result.first.start.y, closeTo(2, 1e-9));
      expect(result.first.end, const Vec2(0, 10));
      expect(result.second.start.x, closeTo(2, 1e-9));
      expect(result.second.start.y, closeTo(0, 1e-9));
      expect(result.second.end, const Vec2(10, 0));
      expect(result.arc, isNotNull);
      expect(result.arc!.center.x, closeTo(2, 1e-9));
      expect(result.arc!.center.y, closeTo(2, 1e-9));
      expect(result.arc!.radius, closeTo(2, 1e-9));
      expect(result.arc!.sweep, closeTo(math.pi / 2, 1e-9));
    });

    test('extends short arms to the tangent points', () {
      final result = Construct.filletLines(
        line(0, 10, 0, 5),
        line(5, 0, 10, 0),
        2,
        const Vec2(0, 8),
        const Vec2(8, 0),
      );

      expect(result, isNotNull);
      expect(result!.first.start.y, closeTo(2, 1e-9));
      expect(result.second.start.x, closeTo(2, 1e-9));
      expect(result.arc!.center.x, closeTo(2, 1e-9));
    });

    test('a zero radius trims to a sharp corner', () {
      final result = Construct.filletLines(
        line(0, 10, 0, 2),
        line(2, 0, 10, 0),
        0,
        const Vec2(0, 6),
        const Vec2(6, 0),
      );

      expect(result, isNotNull);
      expect(result!.arc, isNull);
      expect(result.first.start, const Vec2(0, 0));
      expect(result.second.start, const Vec2(0, 0));
    });

    test('pick points choose which quadrant of a crossing', () {
      final result = Construct.filletLines(
        line(-10, 0, 10, 0),
        line(0, -10, 0, 10),
        2,
        const Vec2(5, 0),
        const Vec2(0, 5),
      );

      expect(result, isNotNull);
      expect(result!.arc!.center.x, closeTo(2, 1e-9));
      expect(result.arc!.center.y, closeTo(2, 1e-9));
      expect(result.first.end.x, closeTo(10, 1e-9));
      expect(result.second.end.y, closeTo(10, 1e-9));
    });

    test('returns null for parallel lines', () {
      expect(
        Construct.filletLines(
          line(0, 0, 10, 0),
          line(0, 2, 10, 2),
          1,
          const Vec2(5, 0),
          const Vec2(5, 2),
        ),
        isNull,
      );
    });
  });

  group('filletPolylineVertex', () {
    test('replaces a square corner with a bulge arc', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final filleted = Construct.filletPolylineVertex(
        square,
        const Vec2(0, 0),
        2,
      );

      expect(filleted, isNotNull);
      expect(filleted!.vertexCount, 5);
      expect(filleted.closed, isTrue);
      expect(filleted.vertexAt(0).x, closeTo(0, 1e-9));
      expect(filleted.vertexAt(0).y, closeTo(2, 1e-9));
      expect(filleted.vertexAt(1).x, closeTo(2, 1e-9));
      expect(filleted.vertexAt(1).y, closeTo(0, 1e-9));
      expect(filleted.bulgeAt(0), closeTo(math.tan(math.pi / 8), 1e-9));
      expect(
        [
          for (var i = 0; i < filleted.vertexCount; i++) filleted.vertexAt(i),
        ],
        isNot(contains(const Vec2(0, 0))),
      );
    });

    test('refuses a radius longer than the adjoining sides', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(4, 4))!;
      expect(
        Construct.filletPolylineVertex(square, const Vec2(0, 0), 5),
        isNull,
      );
    });
  });

  group('filletPolyline', () {
    test('rounds every corner of a square', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final filleted = Construct.filletPolyline(square, 2);

      expect(filleted, isNotNull);
      expect(filleted!.vertexCount, 8);
      expect(filleted.closed, isTrue);
      expect(
        [
          for (var i = 0; i < filleted.vertexCount; i++) filleted.vertexAt(i),
        ],
        isNot(contains(const Vec2(0, 0))),
      );
      expect(
        [
          for (var i = 0; i < filleted.vertexCount; i++) filleted.vertexAt(i),
        ],
        isNot(contains(const Vec2(10, 10))),
      );
    });

    test('skips a corner whose sides are shorter than the radius', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [
          Vec2(0, 0),
          Vec2(10, 0),
          Vec2(10, 10),
          Vec2(11, 10),
        ],
      );
      final filleted = Construct.filletPolyline(polyline, 2);

      expect(filleted, isNotNull);
      expect(filleted!.vertexCount, 5);
      expect(filleted.vertexAt(3), const Vec2(10, 10));
    });
  });

  group('chamferLines', () {
    test('cuts an equal bevel on an L-corner', () {
      final result = Construct.chamferLines(
        line(0, 10, 0, 0),
        line(0, 0, 10, 0),
        2,
        2,
        const Vec2(0, 5),
        const Vec2(5, 0),
      );

      expect(result, isNotNull);
      expect(result!.first.start, const Vec2(0, 2));
      expect(result.first.end, const Vec2(0, 10));
      expect(result.second.start, const Vec2(2, 0));
      expect(result.second.end, const Vec2(10, 0));
      expect(result.cut, isNotNull);
      expect(result.cut!.start, const Vec2(0, 2));
      expect(result.cut!.end, const Vec2(2, 0));
    });

    test('allows unequal distances', () {
      final result = Construct.chamferLines(
        line(0, 10, 0, 0),
        line(0, 0, 10, 0),
        3,
        1,
        const Vec2(0, 5),
        const Vec2(5, 0),
      );

      expect(result!.first.start, const Vec2(0, 3));
      expect(result.second.start, const Vec2(1, 0));
      expect(result.cut!.end, const Vec2(1, 0));
    });

    test('zero distances make a sharp corner', () {
      final result = Construct.chamferLines(
        line(0, 10, 0, 2),
        line(2, 0, 10, 0),
        0,
        0,
        const Vec2(0, 6),
        const Vec2(6, 0),
      );

      expect(result, isNotNull);
      expect(result!.cut, isNull);
      expect(result.first.start, const Vec2(0, 0));
      expect(result.second.start, const Vec2(0, 0));
    });
  });

  group('chamferPolylineVertex', () {
    test('replaces a square corner with a straight cut', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final chamfered = Construct.chamferPolylineVertex(
        square,
        const Vec2(0, 0),
        dist1: 2,
      );

      expect(chamfered, isNotNull);
      expect(chamfered!.vertexCount, 5);
      expect(chamfered.vertexAt(0).x, closeTo(0, 1e-9));
      expect(chamfered.vertexAt(0).y, closeTo(2, 1e-9));
      expect(chamfered.vertexAt(1).x, closeTo(2, 1e-9));
      expect(chamfered.vertexAt(1).y, closeTo(0, 1e-9));
      expect(chamfered.bulgeAt(0), 0);
    });

    test('refuses distances longer than the adjoining sides', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(4, 4))!;
      expect(
        Construct.chamferPolylineVertex(
          square,
          const Vec2(0, 0),
          dist1: 5,
        ),
        isNull,
      );
    });
  });

  group('chamferPolyline', () {
    test('bevels every corner of a square', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final chamfered = Construct.chamferPolyline(square, dist1: 2);

      expect(chamfered, isNotNull);
      expect(chamfered!.vertexCount, 8);
      expect(chamfered.closed, isTrue);
      expect(
        [
          for (var i = 0; i < chamfered.vertexCount; i++) chamfered.vertexAt(i),
        ],
        isNot(contains(const Vec2(0, 0))),
      );
      expect(
        [
          for (var i = 0; i < chamfered.vertexCount; i++) chamfered.vertexAt(i),
        ],
        isNot(contains(const Vec2(10, 10))),
      );
    });

    test('skips a corner whose sides are shorter than the distance', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [
          Vec2(0, 0),
          Vec2(10, 0),
          Vec2(10, 10),
          Vec2(11, 10),
        ],
      );
      final chamfered = Construct.chamferPolyline(polyline, dist1: 2);

      expect(chamfered, isNotNull);
      expect(chamfered!.vertexCount, 5);
      expect(chamfered.vertexAt(3), const Vec2(10, 10));
    });
  });

  group('breakLine', () {
    test('splits a line at one interior point', () {
      final pieces = Construct.breakLine(
        line(0, 0, 10, 0),
        const Vec2(4, 0),
      );

      expect(pieces, isNotNull);
      expect(pieces, hasLength(2));
      expect(pieces![0].end.x, closeTo(4, 1e-9));
      expect(pieces[1].start.x, closeTo(4, 1e-9));
      expect(pieces[1].end.x, closeTo(10, 1e-9));
    });

    test('removes the span between two points', () {
      final pieces = Construct.breakLine(
        line(0, 0, 10, 0),
        const Vec2(2, 0),
        const Vec2(8, 0),
      );

      expect(pieces, hasLength(2));
      expect(pieces![0].end.x, closeTo(2, 1e-9));
      expect(pieces[1].start.x, closeTo(8, 1e-9));
    });

    test('erases the line when both ends are the break points', () {
      final pieces = Construct.breakLine(
        line(0, 0, 10, 0),
        const Vec2(0, 0),
        const Vec2(10, 0),
      );

      expect(pieces, isEmpty);
    });

    test('returns null when a single point is an endpoint', () {
      expect(
        Construct.breakLine(line(0, 0, 10, 0), const Vec2(0, 0)),
        isNull,
      );
    });
  });

  group('breakPolyline', () {
    test('splits an open polyline at an interior vertex', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
      );

      final pieces = Construct.breakPolyline(polyline, const Vec2(10, 0));

      expect(pieces, hasLength(2));
      expect(pieces![0].vertexAt(0), const Vec2(0, 0));
      expect(pieces[0].vertexAt(1), const Vec2(10, 0));
      expect(pieces[1].vertexAt(0), const Vec2(10, 0));
      expect(pieces[1].vertexAt(1), const Vec2(10, 10));
    });

    test('opens a closed polyline at one point', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final pieces = Construct.breakPolyline(square, const Vec2(5, 0));

      expect(pieces, hasLength(1));
      expect(pieces!.first.closed, isFalse);
      expect(pieces.first.vertexAt(0).x, closeTo(5, 1e-9));
      expect(pieces.first.vertexAt(0).y, closeTo(0, 1e-9));
      expect(
        pieces.first.vertexAt(pieces.first.vertexCount - 1).x,
        closeTo(5, 1e-9),
      );
    });

    test('drops the span between two points on an open polyline', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [
          Vec2(0, 0),
          Vec2(10, 0),
          Vec2(10, 10),
          Vec2(20, 10),
        ],
      );

      final pieces = Construct.breakPolyline(
        polyline,
        const Vec2(10, 0),
        const Vec2(10, 10),
      );

      expect(pieces, hasLength(2));
      expect(pieces![0].vertexAt(1), const Vec2(10, 0));
      expect(pieces[1].vertexAt(0), const Vec2(10, 10));
      expect(pieces[1].vertexAt(1), const Vec2(20, 10));
    });
  });

  group('breakArc', () {
    const semicircle = ArcEntity(
      id: 1,
      center: Vec2(0, 0),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi,
    );

    test('splits an arc at an interior point', () {
      final pieces = Construct.breakArc(semicircle, const Vec2(0, 10));

      expect(pieces, hasLength(2));
      expect(pieces![0].endAngle, closeTo(math.pi / 2, 1e-9));
      expect(pieces[1].startAngle, closeTo(math.pi / 2, 1e-9));
      expect(pieces[1].endAngle, closeTo(math.pi, 1e-9));
    });

    test('returns null when the point is an endpoint', () {
      expect(Construct.breakArc(semicircle, const Vec2(10, 0)), isNull);
    });

    test('drops the span between two points', () {
      final pieces = Construct.breakArc(
        semicircle,
        const Vec2(0, 10),
        const Vec2(-10, 0),
      );

      expect(pieces, hasLength(1));
      expect(pieces!.first.endAngle, closeTo(math.pi / 2, 1e-9));
    });
  });

  group('breakCircle', () {
    test('keeps the counter-clockwise remnant between two points', () {
      const circle = CircleEntity(id: 1, center: Vec2(0, 0), radius: 10);
      final pieces = Construct.breakCircle(
        circle,
        const Vec2(10, 0),
        const Vec2(0, 10),
      );

      expect(pieces, hasLength(1));
      expect(pieces!.first.startAngle, closeTo(math.pi / 2, 1e-9));
      expect(pieces.first.sweep, closeTo(math.pi * 1.5, 1e-9));
    });

    test('refuses a single point', () {
      expect(
        Construct.breakCircle(
          const CircleEntity(id: 1, center: Vec2(0, 0), radius: 10),
          const Vec2(10, 0),
        ),
        isNull,
      );
    });
  });

  group('joinEntities', () {
    test('joins a line onto an open polyline', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
      );
      final joined = Construct.joinEntities([
        polyline,
        line(10, 10, 20, 10),
      ]);

      expect(joined, isNotNull);
      expect(joined!.vertexCount, 4);
      expect(joined.vertexAt(3), const Vec2(20, 10));
    });

    test('reverses a piece that meets the other way around', () {
      final joined = Construct.joinEntities([
        line(0, 0, 10, 0),
        line(20, 0, 10, 0),
      ]);

      expect(joined, isNotNull);
      expect(joined!.vertexCount, 3);
      expect(joined.vertexAt(2), const Vec2(20, 0));
    });

    test('closes a loop without duplicating the start', () {
      final joined = Construct.joinEntities([
        line(0, 0, 10, 0),
        line(10, 0, 10, 10),
        line(10, 10, 0, 0),
      ]);

      expect(joined, isNotNull);
      expect(joined!.closed, isTrue);
      expect(joined.vertexCount, 3);
    });

    test('refuses objects that do not form one chain', () {
      expect(
        Construct.joinEntities([
          line(0, 0, 10, 0),
          line(50, 50, 60, 50),
        ]),
        isNull,
      );
    });

    test('joins a line onto an arc as a bulged polyline', () {
      final arc = ArcEntity(
        id: 2,
        center: const Vec2(0, 0),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      final joined = Construct.joinEntities([
        line(0, 0, 10, 0),
        arc,
      ]);

      expect(joined, isNotNull);
      expect(joined!.vertexCount, 3);
      expect(joined.vertexAt(2).x, closeTo(0, 1e-9));
      expect(joined.vertexAt(2).y, closeTo(10, 1e-9));
      expect(joined.bulgeAt(1), closeTo(math.tan(math.pi / 8), 1e-9));
    });

    test('closes two semicircles without duplicating the start', () {
      final joined = Construct.joinEntities([
        const ArcEntity(
          id: 1,
          center: Vec2(0, 0),
          radius: 10,
          startAngle: 0,
          endAngle: math.pi,
        ),
        const ArcEntity(
          id: 2,
          center: Vec2(0, 0),
          radius: 10,
          startAngle: math.pi,
          endAngle: math.pi * 2,
        ),
      ]);

      expect(joined, isNotNull);
      expect(joined!.closed, isTrue);
      expect(joined.vertexCount, 2);
      expect(joined.bulgeAt(0), closeTo(1, 1e-9));
      expect(joined.bulgeAt(1), closeTo(1, 1e-9));
    });
  });

  group('reverse', () {
    test('swaps the ends of a line', () {
      final reversed = Construct.reverse(line(0, 0, 10, 5)) as LineEntity;

      expect(reversed.start, const Vec2(10, 5));
      expect(reversed.end, const Vec2(0, 0));
    });

    test('reverses polyline vertices and negates bulges', () {
      final source = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          0, 0, 1,
          10, 0, 0,
          10, 10, 0,
        ]),
      );
      final reversed = Construct.reverse(source) as PolylineEntity;

      expect(reversed.vertexAt(0), const Vec2(10, 10));
      expect(reversed.vertexAt(2), const Vec2(0, 0));
      expect(reversed.bulgeAt(1), closeTo(-1, 1e-9));
      expect(reversed.bulgeAt(2), 0);
    });
  });

  group('divideLine', () {
    test('places interior points only', () {
      final points = Construct.divideLine(line(0, 0, 12, 0), 3);

      expect(points, hasLength(2));
      expect(points[0].x, closeTo(4, 1e-9));
      expect(points[1].x, closeTo(8, 1e-9));
    });

    test('returns nothing for fewer than two segments', () {
      expect(Construct.divideLine(line(0, 0, 10, 0), 1), isEmpty);
    });
  });

  group('dividePolyline', () {
    test('places interior points along an open polyline', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
      );

      final points = Construct.dividePolyline(polyline, 4);

      expect(points, hasLength(3));
      expect(points[0].x, closeTo(5, 1e-9));
      expect(points[1], const Vec2(10, 0));
      expect(points[2].y, closeTo(5, 1e-9));
    });

    test('walks a closed polyline around the loop', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;

      final points = Construct.dividePolyline(square, 8);

      expect(points, hasLength(8));
      expect(points[0], const Vec2(0, 0));
      expect(points[1].x, closeTo(5, 1e-9));
      expect(points[2], const Vec2(10, 0));
      expect(points[4], const Vec2(10, 10));
    });
  });

  group('divideArc', () {
    test('places interior points along a quarter circle', () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2(0, 0),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
      );

      final points = Construct.divideArc(arc, 2);

      expect(points, hasLength(1));
      expect(points.first.x, closeTo(10 * math.cos(math.pi / 4), 1e-9));
      expect(points.first.y, closeTo(10 * math.sin(math.pi / 4), 1e-9));
    });
  });

  group('divideCircle', () {
    test('places a point at every equal angle', () {
      const circle = CircleEntity(id: 1, center: Vec2(0, 0), radius: 5);
      final points = Construct.divideCircle(circle, 4);

      expect(points, hasLength(4));
      expect(points[0], const Vec2(5, 0));
      expect(points[1].x, closeTo(0, 1e-9));
      expect(points[1].y, closeTo(5, 1e-9));
      expect(points[2].x, closeTo(-5, 1e-9));
    });
  });

  group('measureLine', () {
    test('spaces points from the nearer end', () {
      final points = Construct.measureLine(
        line(0, 0, 10, 0),
        3,
        const Vec2(0, 0),
      );

      expect(points, hasLength(3));
      expect(points[0].x, closeTo(3, 1e-9));
      expect(points[1].x, closeTo(6, 1e-9));
      expect(points[2].x, closeTo(9, 1e-9));
    });

    test('starts from the opposite end when that is nearer the pick', () {
      final points = Construct.measureLine(
        line(0, 0, 10, 0),
        4,
        const Vec2(10, 0),
      );

      expect(points, hasLength(2));
      expect(points[0].x, closeTo(6, 1e-9));
      expect(points[1].x, closeTo(2, 1e-9));
    });

    test('skips a line shorter than the spacing', () {
      expect(
        Construct.measureLine(line(0, 0, 10, 0), 10, const Vec2(0, 0)),
        isEmpty,
      );
    });
  });

  group('measurePolyline', () {
    final elbow = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
    );

    test('spaces points from the nearer end around the corner', () {
      final points = Construct.measurePolyline(elbow, 6, const Vec2(0, 0));

      expect(points, hasLength(3));
      expect(points[0].x, closeTo(6, 1e-9));
      expect(points[1].x, closeTo(10, 1e-9));
      expect(points[1].y, closeTo(2, 1e-9));
      expect(points[2].y, closeTo(8, 1e-9));
    });

    test('starts from the opposite end when that is nearer the pick', () {
      final points = Construct.measurePolyline(elbow, 6, const Vec2(10, 10));

      expect(points, hasLength(3));
      expect(points[0].y, closeTo(4, 1e-9));
      expect(points[1].x, closeTo(8, 1e-9));
      expect(points[2].x, closeTo(2, 1e-9));
    });

    test('walks a closed polyline from the start vertex', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final points = Construct.measurePolyline(square, 15, const Vec2(0, 0));

      expect(points, hasLength(2));
      expect(points[0], const Vec2(10, 5));
      expect(points[1], const Vec2(0, 10));
    });
  });

  group('measureArc', () {
    test('spaces points from the start of a quarter circle', () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2(0, 0),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      final points = Construct.measureArc(arc, 5, const Vec2(10, 0));

      expect(points, hasLength(3));
      expect(points.first.x, closeTo(10 * math.cos(0.5), 1e-9));
      expect(points.first.y, closeTo(10 * math.sin(0.5), 1e-9));
    });
  });

  group('measureCircle', () {
    test('spaces points around the circumference from the pick', () {
      const circle = CircleEntity(id: 1, center: Vec2(0, 0), radius: 5);
      final points = Construct.measureCircle(circle, 5, const Vec2(5, 0));

      expect(points, hasLength(6));
      expect(points.first.x, closeTo(5 * math.cos(1), 1e-9));
      expect(points.first.y, closeTo(5 * math.sin(1), 1e-9));
    });
  });

  group('lengthenLine', () {
    test('sets a new total length on the picked end', () {
      final longer = Construct.lengthenLine(
        line(0, 0, 10, 0),
        const Vec2(10, 0),
        total: 15,
      );

      expect(longer, isNotNull);
      expect(longer!.start, const Vec2(0, 0));
      expect(longer.end.x, closeTo(15, 1e-9));
    });

    test('a negative delta shortens the nearer end', () {
      final shorter = Construct.lengthenLine(
        line(0, 0, 10, 0),
        const Vec2(0, 0),
        delta: -3,
      );

      expect(shorter!.start.x, closeTo(3, 1e-9));
      expect(shorter.end, const Vec2(10, 0));
    });

    test('refuses a non-positive result', () {
      expect(
        Construct.lengthenLine(
          line(0, 0, 10, 0),
          const Vec2(10, 0),
          total: 0,
        ),
        isNull,
      );
    });
  });

  group('lengthenPolyline', () {
    final elbow = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
    );

    test('extends the last segment when the pick is at the free end', () {
      final longer = Construct.lengthenPolyline(
        elbow,
        const Vec2(10, 10),
        total: 25,
      );

      expect(longer, isNotNull);
      expect(longer!.vertexCount, 3);
      expect(longer.vertexAt(2).x, closeTo(10, 1e-9));
      expect(longer.vertexAt(2).y, closeTo(15, 1e-9));
    });

    test('shortens the last segment without dropping vertices', () {
      final shorter = Construct.lengthenPolyline(
        elbow,
        const Vec2(10, 10),
        total: 15,
      );

      expect(shorter!.vertexAt(2).y, closeTo(5, 1e-9));
    });

    test('drops vertices when shortening past a corner', () {
      final shorter = Construct.lengthenPolyline(
        elbow,
        const Vec2(10, 10),
        total: 8,
      );

      expect(shorter!.vertexCount, 2);
      expect(shorter.vertexAt(1).x, closeTo(8, 1e-9));
    });

    test('a negative delta shortens the nearer end', () {
      final shorter = Construct.lengthenPolyline(
        elbow,
        const Vec2(0, 0),
        delta: -3,
      );

      expect(shorter!.vertexAt(0).x, closeTo(3, 1e-9));
      expect(shorter.vertexAt(2), const Vec2(10, 10));
    });

    test('refuses a closed polyline', () {
      expect(
        Construct.lengthenPolyline(
          Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!,
          const Vec2(0, 0),
          total: 50,
        ),
        isNull,
      );
    });
  });

  group('lengthenArc', () {
    const quarter = ArcEntity(
      id: 1,
      center: Vec2(0, 0),
      radius: 10,
      startAngle: 0,
      endAngle: math.pi / 2,
    );

    test('extends the free end to a new total length', () {
      final longer = Construct.lengthenArc(
        quarter,
        const Vec2(0, 10),
        total: 10 * math.pi,
      );

      expect(longer, isNotNull);
      expect(longer!.startAngle, closeTo(0, 1e-9));
      expect(longer.endAngle, closeTo(math.pi, 1e-9));
    });

    test('a negative delta shortens the nearer end', () {
      final shorter = Construct.lengthenArc(
        quarter,
        const Vec2(10, 0),
        delta: -5,
      );

      expect(shorter!.endAngle, closeTo(math.pi / 2, 1e-9));
      expect(shorter.sweep, closeTo((5 * math.pi - 5) / 10, 1e-9));
    });

    test('refuses a sweep that would close the circle', () {
      expect(
        Construct.lengthenArc(quarter, const Vec2(0, 10), total: 20 * math.pi),
        isNull,
      );
    });
  });

  group('stretch', () {
    const window = Bounds2(-1, -1, 1, 1);
    const delta = Vec2(0, 4);

    test('moves only the endpoint inside the window', () {
      final stretched = Construct.stretch(line(-8, 0, 0, 0), window, delta);

      expect(stretched, isA<LineEntity>());
      final result = stretched! as LineEntity;
      expect(result.start, const Vec2(-8, 0));
      expect(result.end, const Vec2(0, 4));
    });

    test('translates a line whose both ends are captured', () {
      final stretched =
          Construct.stretch(line(0, 0, 0.5, 0), window, delta)! as LineEntity;

      expect(stretched.start, const Vec2(0, 4));
      expect(stretched.end, const Vec2(0.5, 4));
    });

    test('ignores a line that only crosses the window', () {
      expect(
        Construct.stretch(line(-8, 0, 8, 0), window, delta),
        isNull,
      );
    });

    test('moves a polyline vertex without dragging the rest', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(-4, 0), Vec2(0, 0), Vec2(4, 0)],
      );

      final stretched =
          Construct.stretch(polyline, window, delta)! as PolylineEntity;

      expect(stretched.vertexAt(0), const Vec2(-4, 0));
      expect(stretched.vertexAt(1), const Vec2(0, 4));
      expect(stretched.vertexAt(2), const Vec2(4, 0));
    });

    test('moves a circle only when the centre is in the window', () {
      const inside = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      const outside = CircleEntity(id: 2, center: Vec2(8, 0), radius: 5);

      expect(
        (Construct.stretch(inside, window, delta)! as CircleEntity).center,
        const Vec2(0, 4),
      );
      expect(Construct.stretch(outside, window, delta), isNull);
    });
  });

  group('measurements', () {
    test('reports the length of each supported type', () {
      expect(Construct.lengthOf(line(0, 0, 3, 4)), closeTo(5, 1e-9));
      expect(
        Construct.lengthOf(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 2),
        ),
        closeTo(4 * math.pi, 1e-9),
      );
      expect(
        Construct.lengthOf(
          ArcEntity(
            id: 1,
            center: const Vec2(0, 0),
            radius: 2,
            startAngle: 0,
            endAngle: math.pi,
          ),
        ),
        closeTo(2 * math.pi, 1e-9),
      );
    });

    test('measures a closed polyline perimeter and area', () {
      final square = Construct.rectangle(
        const Vec2(0, 0),
        const Vec2(4, 3),
      )!;

      expect(Construct.lengthOf(square), closeTo(14, 1e-9));
      expect(Construct.areaOf(square).abs(), closeTo(12, 1e-9));
    });

    test('reports zero area for open geometry', () {
      expect(Construct.areaOf(line(0, 0, 10, 0)), 0);
    });
  });

  group('overkill', () {
    test('flags a line drawn again in the opposite direction', () {
      final first = line(0, 0, 10, 0);
      final copy = LineEntity(
        id: 2,
        start: const Vec2(10, 0),
        end: const Vec2(0, 0),
      );
      final other = LineEntity(
        id: 3,
        start: const Vec2(0, 0),
        end: const Vec2(10, 1),
      );

      expect(Construct.overkillIds([first, copy, other]), [2]);
    });

    test('flags a second circle on the same centre and radius', () {
      const a = CircleEntity(id: 1, center: Vec2.zero(), radius: 3);
      const b = CircleEntity(id: 2, center: Vec2.zero(), radius: 3);
      const c = CircleEntity(id: 3, center: Vec2.zero(), radius: 4);

      expect(Construct.overkillIds([a, b, c]), [2]);
    });
  });
}
