import 'dart:math' as math;

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
}
