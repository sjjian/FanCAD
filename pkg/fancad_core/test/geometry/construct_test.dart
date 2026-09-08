import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

/// Tests for the analytic constructions behind the editing commands.
///
/// These are worth testing directly rather than through the commands: every one
/// is a closed-form geometry result with a right answer, and a sign error in any
/// of them produces geometry that looks plausible but is wrong.
void main() {
  LineEntity line(double x1, double y1, double x2, double y2) =>
      LineEntity(id: 1, start: Vec2(x1, y1), end: Vec2(x2, y2));

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

  group('linearDimension', () {
    test('measures width when the dim line is above the origins', () {
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 4),
        const Vec2(5, 8),
      );

      expect(dim, isNotNull);
      expect(dim!.measurement, closeTo(10, 1e-9));
      expect(dim.textPosition.y, closeTo(8, 1e-9));
    });

    test('measures height when the dim line is beside the origins', () {
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 4),
        const Vec2(14, 2),
      );

      expect(dim, isNotNull);
      expect(dim!.measurement, closeTo(4, 1e-9));
      expect(dim.textPosition.x, closeTo(14, 1e-9));
    });

    test('returns null when the chosen axis has no length', () {
      expect(
        Construct.linearDimension(
          const Vec2(3, 0),
          const Vec2(3, 8),
          const Vec2(3, 12),
        ),
        isNull,
      );
    });
  });

  group('alignedDimension', () {
    test('measures the true distance, not a projected axis', () {
      final dim = Construct.alignedDimension(
        const Vec2(0, 0),
        const Vec2(3, 4),
        const Vec2(1, 2),
      );

      expect(dim, isNotNull);
      expect(dim!.measurement, closeTo(5, 1e-9));
      expect(dim.dimensionType, 1);
    });

    test('returns null when the origins coincide', () {
      expect(
        Construct.alignedDimension(
          const Vec2(2, 2),
          const Vec2(2, 2),
          const Vec2(4, 4),
        ),
        isNull,
      );
    });
  });

  group('continueDimension', () {
    test('walks a horizontal chain on the same dimension line', () {
      final first = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
      )!;
      final next = Construct.continueDimension(first, const Vec2(18, 0));

      expect(next, isNotNull);
      expect(next!.measurement, closeTo(8, 1e-9));
      expect(next.definitionPoints[0], const Vec2(10, 0));
      expect(next.definitionPoints[1], const Vec2(18, 0));
      expect(next.textPosition.y, closeTo(4, 1e-9));
    });

    test('keeps a width chain from flipping to height', () {
      // The previous dim-line pick sits left of the new midpoint, which
      // would make a fresh DIMLINEAR read height. Continue must not.
      final first = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
      )!;
      final next = Construct.continueDimension(first, const Vec2(24, 0));

      expect(next, isNotNull);
      expect(next!.measurement, closeTo(14, 1e-9));
    });

    test('continues an associated dimension with the same sources', () {
      final first = Construct.linearDimension(
        const Vec2.zero(),
        const Vec2(10, 0),
        const Vec2(5, 4),
        sourceIds: const [7],
      )!;
      final next = Construct.continueDimension(first, const Vec2(24, 0));
      expect(next, isNotNull);
      expect(next!.sourceIds, [7]);
    });

    test('continues an aligned dimension along the same offset', () {
      final first = Construct.alignedDimension(
        const Vec2(0, 0),
        const Vec2(3, 4),
        const Vec2(-2, 2),
      )!;
      final next = Construct.continueDimension(first, const Vec2(6, 8));

      expect(next, isNotNull);
      expect(next!.measurement, closeTo(5, 1e-9));
      expect(next.dimensionType, 1);
      expect(next.definitionPoints[0], const Vec2(3, 4));
    });

    test('refuses a radius dimension', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      final radial = Construct.radiusDimension(circle, const Vec2(8, 0))!;
      expect(Construct.continueDimension(radial, const Vec2(12, 0)), isNull);
    });
  });

  group('baselineDimension', () {
    test('stacks from the first origin on a stepped dimension line', () {
      final first = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
      )!;
      final next = Construct.baselineDimension(
        first,
        const Vec2(18, 0),
        spacing: 8,
      );

      expect(next, isNotNull);
      expect(next!.measurement, closeTo(18, 1e-9));
      expect(next.definitionPoints[0], const Vec2(0, 0));
      expect(next.definitionPoints[1], const Vec2(18, 0));
      expect(next.textPosition.y, closeTo(12, 1e-9));
    });

    test('each stacked dim steps farther from the origins', () {
      final first = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(8, 0),
        const Vec2(4, 3),
      )!;
      final second = Construct.baselineDimension(
        first,
        const Vec2(14, 0),
        spacing: 5,
      )!;
      final third = Construct.baselineDimension(
        second,
        const Vec2(20, 0),
        spacing: 5,
      )!;

      expect(second.measurement, closeTo(14, 1e-9));
      expect(third.measurement, closeTo(20, 1e-9));
      expect(second.textPosition.y, closeTo(8, 1e-9));
      expect(third.textPosition.y, closeTo(13, 1e-9));
    });

    test('stacks an aligned dimension outward along the same side', () {
      final first = Construct.alignedDimension(
        const Vec2(0, 0),
        const Vec2(3, 4),
        const Vec2(-2, 2),
      )!;
      final next = Construct.baselineDimension(
        first,
        const Vec2(6, 8),
        spacing: 4,
      );

      expect(next, isNotNull);
      expect(next!.measurement, closeTo(10, 1e-9));
      expect(next.dimensionType, 1);
      expect(next.definitionPoints[0], const Vec2(0, 0));
      final firstOffset =
          (first.definitionPoints[2] - first.definitionPoints[0]).dot(
            (first.definitionPoints[1] - first.definitionPoints[0])
                .normalized()
                .perpendicular,
          );
      final nextOffset = (next.definitionPoints[2] - next.definitionPoints[0])
          .dot(
            (next.definitionPoints[1] - next.definitionPoints[0])
                .normalized()
                .perpendicular,
          );
      expect(nextOffset.abs(), closeTo(firstOffset.abs() + 4, 1e-9));
    });

    test('refuses a radius dimension', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      final radial = Construct.radiusDimension(circle, const Vec2(8, 0))!;
      expect(Construct.baselineDimension(radial, const Vec2(12, 0)), isNull);
    });
  });

  group('radiusDimension', () {
    test('reads the radius of a circle and prefixes R', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      final dim = Construct.radiusDimension(circle, const Vec2(8, 0));

      expect(dim, isNotNull);
      expect(dim!.measurement, closeTo(5, 1e-9));
      expect(dim.dimensionType, 4);
      expect(dim.displayText, 'R5.00');
      expect(dim.sourceIds, [1]);
    });

    test('accepts an arc and refuses a line', () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2.zero(),
        radius: 3,
        startAngle: 0,
        endAngle: 1,
      );
      expect(Construct.radiusDimension(arc, const Vec2(3, 0)), isNotNull);
      expect(
        Construct.radiusDimension(line(0, 0, 10, 0), const Vec2(5, 0)),
        isNull,
      );
    });
  });

  group('regenDimension', () {
    test('a linear dimension follows a moved line and keeps its offset', () {
      const source = LineEntity(id: 7, start: Vec2.zero(), end: Vec2(10, 0));
      final dim = Construct.linearDimension(
        source.start,
        source.end,
        const Vec2(5, 4),
        sourceIds: const [7],
      )!;
      expect(dim.measurement, closeTo(10, 1e-9));

      const moved = LineEntity(id: 7, start: Vec2(0, 2), end: Vec2(14, 2));
      final next = Construct.regenDimension(dim, [moved], sourcesMoved: true)!;
      expect(next.measurement, closeTo(14, 1e-9));
      expect(next.sourceIds, [7]);
      expect(next.definitionPoints[0], const Vec2(0, 2));
      expect(next.definitionPoints[1], const Vec2(14, 2));
      expect(next.definitionPoints[2].y, closeTo(6, 1e-9));
    });

    test('moving only the dimension keeps origins on the source', () {
      const source = LineEntity(id: 7, start: Vec2.zero(), end: Vec2(10, 0));
      final dim = Construct.linearDimension(
        source.start,
        source.end,
        const Vec2(5, 4),
        id: 8,
        sourceIds: const [7],
      )!;
      final dragged = dim.transformed(const Mat3.translation(0, 3));
      final next = Construct.regenDimension(dragged, const [
        source,
      ], sourcesMoved: false)!;
      expect(next.measurement, closeTo(10, 1e-9));
      expect(next.definitionPoints[0], const Vec2.zero());
      expect(next.definitionPoints[1], const Vec2(10, 0));
      expect(next.definitionPoints[2].y, closeTo(7, 1e-9));
    });

    test('a radius dimension rereads a stretched circle', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      final dim = Construct.radiusDimension(circle, const Vec2(8, 0))!;
      const grown = CircleEntity(id: 1, center: Vec2.zero(), radius: 8);
      final next = Construct.regenDimension(dim, const [grown])!;
      expect(next.measurement, closeTo(8, 1e-9));
      expect(next.displayText, 'R8.00');
      expect(next.sourceIds, [1]);
    });

    test('missing sources leave the last measurement in place', () {
      const dim = DimensionEntity(
        id: 2,
        definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
        measurement: 10,
        sourceIds: [99],
      );
      expect(Construct.regenDimension(dim, const []), same(dim));
    });
  });

  group('diameterDimension', () {
    test('reads twice the radius and prefixes Ø', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 5);
      final dim = Construct.diameterDimension(circle, const Vec2(8, 0));

      expect(dim, isNotNull);
      expect(dim!.measurement, closeTo(10, 1e-9));
      expect(dim.dimensionType, 3);
      expect(dim.displayText, 'Ø10.00');
    });
  });

  group('centerMark', () {
    test('crosses the centre and extends past the circumference', () {
      const circle = CircleEntity(id: 1, center: Vec2(10, 4), radius: 8);
      final marks = Construct.centerMark(circle, size: 2);

      expect(marks, isNotNull);
      expect(marks, hasLength(6));
      final through = marks!.where((line) {
        return line.start.distanceTo(circle.center) <= 2 + 1e-9 &&
            line.end.distanceTo(circle.center) <= 2 + 1e-9;
      });
      expect(through, hasLength(2));
      final farthest = marks
          .expand((line) => [line.start, line.end])
          .map((point) => point.distanceTo(circle.center))
          .reduce(math.max);
      expect(farthest, closeTo(10, 1e-9));
    });

    test('can draw only the centre cross', () {
      const circle = CircleEntity(id: 1, center: Vec2.zero(), radius: 6);
      final marks = Construct.centerMark(circle, size: 1.5, extend: false);

      expect(marks, hasLength(2));
      expect(
        marks!.every(
          (line) =>
              line.start.distanceTo(const Vec2.zero()) <= 1.5 + 1e-9 &&
              line.end.distanceTo(const Vec2.zero()) <= 1.5 + 1e-9,
        ),
        isTrue,
      );
    });

    test('accepts an arc and refuses a line', () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2.zero(),
        radius: 4,
        startAngle: 0,
        endAngle: 2,
      );
      expect(Construct.centerMark(arc, extend: false), hasLength(2));
      expect(Construct.centerMark(line(0, 0, 10, 0)), isNull);
    });
  });

  group('centerLine', () {
    test('sits midway between two parallel lines and overshoots both', () {
      final mark = Construct.centerLine(
        line(0, 0, 10, 0),
        line(2, 4, 12, 4),
        extension: 2,
      );

      expect(mark, isNotNull);
      expect(mark!.start.y, closeTo(2, 1e-9));
      expect(mark.end.y, closeTo(2, 1e-9));
      expect(mark.start.x, closeTo(-2, 1e-9));
      expect(mark.end.x, closeTo(14, 1e-9));
    });

    test('refuses lines that are not parallel', () {
      expect(
        Construct.centerLine(line(0, 0, 10, 0), line(0, 0, 0, 10)),
        isNull,
      );
    });

    test('runs through two circle centres and past both rims', () {
      const left = CircleEntity(id: 1, center: Vec2.zero(), radius: 2);
      const right = CircleEntity(id: 2, center: Vec2(10, 0), radius: 3);
      final mark = Construct.centerLine(left, right, extension: 1);

      expect(mark, isNotNull);
      expect(mark!.start, const Vec2(-3, 0));
      expect(mark.end, const Vec2(14, 0));
    });

    test('accepts an arc pair and refuses concentric circles', () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2.zero(),
        radius: 4,
        startAngle: 0,
        endAngle: 2,
      );
      const other = CircleEntity(id: 2, center: Vec2(6, 0), radius: 1);
      expect(Construct.centerLine(arc, other, extension: 0), isNotNull);
      expect(
        Construct.centerLine(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 2),
          const CircleEntity(id: 2, center: Vec2.zero(), radius: 5),
        ),
        isNull,
      );
    });
  });

  group('angularDimension', () {
    test('labels the sector that contains the dim-arc pick', () {
      final interior = Construct.angularDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(0, 10),
        const Vec2(4, 4),
      );
      expect(interior, isNotNull);
      expect(interior!.measurement, closeTo(90, 1e-9));
      expect(interior.displayText, '90.00°');

      final exterior = Construct.angularDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(0, 10),
        const Vec2(-4, -4),
      );
      expect(exterior, isNotNull);
      expect(exterior!.measurement, closeTo(270, 1e-9));
    });

    test('returns null when a ray collapses onto the vertex', () {
      expect(
        Construct.angularDimension(
          const Vec2(0, 0),
          const Vec2(0, 0),
          const Vec2(1, 0),
          const Vec2(1, 1),
        ),
        isNull,
      );
    });

    test(
      'a coincident vertex or collapsed sweep cannot invent an angular dim',
      () {
        expect(
          Construct.angularDimension(
            const Vec2.zero(),
            const Vec2.zero(),
            const Vec2(10, 0),
            const Vec2(4, 4),
          ),
          isNull,
        );
        expect(
          Construct.angularDimension(
            const Vec2.zero(),
            const Vec2(10, 0),
            const Vec2(10, 0),
            const Vec2(4, 4),
          ),
          isNull,
        );
        expect(
          Construct.angularDimension(
            const Vec2.zero(),
            const Vec2(10, 0),
            const Vec2(20, 0),
            const Vec2.zero(),
          ),
          isNull,
        );
      },
    );

    test('from two lines labels the sector that contains the dim-arc pick', () {
      final horizontal = line(-10, 0, 10, 0);
      final tilted = LineEntity(
        id: 2,
        start: const Vec2(0, 0),
        end: Vec2(math.cos(math.pi / 6) * 10, math.sin(math.pi / 6) * 10),
      );

      final acute = Construct.angularDimensionFromLines(
        horizontal,
        tilted,
        const Vec2(5, 1),
      );
      expect(acute, isNotNull);
      expect(acute!.measurement, closeTo(30, 1e-6));
      expect(acute.definitionPoints.first, const Vec2(0, 0));

      final obtuse = Construct.angularDimensionFromLines(
        horizontal,
        tilted,
        const Vec2(-5, 1),
      );
      expect(obtuse, isNotNull);
      expect(obtuse!.measurement, closeTo(150, 1e-6));
    });

    test('from two lines returns null when they are parallel', () {
      expect(
        Construct.angularDimensionFromLines(
          line(0, 0, 10, 0),
          line(0, 1, 10, 1),
          const Vec2(5, 0.5),
        ),
        isNull,
      );
    });

    test('a collapsed line cannot invent an angular dim', () {
      const left = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
      expect(
        Construct.angularDimensionFromLines(
          const LineEntity(id: 3, start: Vec2.zero(), end: Vec2.zero()),
          left,
          const Vec2(5, 2),
        ),
        isNull,
      );
    });

    test('from an arc labels the sweep or its complement', () {
      final quarter = ArcEntity(
        id: 1,
        center: const Vec2(0, 0),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      final interior = Construct.angularDimensionFromArc(
        quarter,
        const Vec2(4, 4),
      );
      expect(interior, isNotNull);
      expect(interior!.measurement, closeTo(90, 1e-9));
      expect(interior.definitionPoints.first, const Vec2(0, 0));

      final exterior = Construct.angularDimensionFromArc(
        quarter,
        const Vec2(-4, -4),
      );
      expect(exterior, isNotNull);
      expect(exterior!.measurement, closeTo(270, 1e-9));
    });

    test('a vanished or closed arc cannot invent an angular dim', () {
      expect(
        Construct.angularDimensionFromArc(
          const ArcEntity(
            id: 1,
            center: Vec2.zero(),
            radius: 0,
            startAngle: 0,
            endAngle: math.pi / 2,
          ),
          const Vec2(4, 4),
        ),
        isNull,
      );
      expect(
        Construct.angularDimensionFromArc(
          const ArcEntity(
            id: 2,
            center: Vec2.zero(),
            radius: 10,
            startAngle: 0,
            endAngle: 0,
          ),
          const Vec2(4, 4),
        ),
        isNull,
      );
    });
  });

  group('explodeDimension', () {
    test('breaks a linear dimension into extensions, a dim line and text', () {
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
      )!;
      final pieces = Construct.explodeDimension(dim);

      expect(pieces.whereType<LineEntity>(), hasLength(3));
      expect(pieces.whereType<SolidEntity>(), hasLength(2));
      final text = pieces.whereType<TextEntity>().single;
      expect(text.content, '10.00');
      expect(text.position, dim.textPosition);
    });

    test('hides text when the override is a single space', () {
      final dim = Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
      )!;
      final hidden = DimensionEntity(
        id: dim.id,
        props: dim.props,
        definitionPoints: dim.definitionPoints,
        textPosition: dim.textPosition,
        measurement: dim.measurement,
        overrideText: ' ',
        dimensionType: dim.dimensionType,
      );
      final pieces = Construct.explodeDimension(hidden);
      expect(pieces.whereType<TextEntity>(), isEmpty);
    });
  });

  group('leader', () {
    test('stores the vertices with the first point as the arrow tip', () {
      final created = Construct.leader(const [
        Vec2(0, 0),
        Vec2(10, 5),
        Vec2(14, 5),
      ]);

      expect(created, isNotNull);
      expect(created, hasLength(1));
      final leader = created!.single as LeaderEntity;
      expect(leader.hasArrowHead, isTrue);
      expect(leader.grips(), const [Vec2(0, 0), Vec2(10, 5), Vec2(14, 5)]);
    });

    test(
      'adds a horizontal landing and text when the last span is slanted',
      () {
        final created = Construct.leader(const [
          Vec2(0, 0),
          Vec2(10, 8),
        ], annotation: 'NOTE');

        expect(created, isNotNull);
        final leader = created!.whereType<LeaderEntity>().single;
        expect(leader.grips(), const [Vec2(0, 0), Vec2(10, 8), Vec2(12.5, 8)]);
        final text = created.whereType<TextEntity>().single;
        expect(text.content, 'NOTE');
        expect(text.hAlign, TextHAlign.left);
        expect(text.vAlign, TextVAlign.middle);
        expect(text.position.x, closeTo(12.5 + 2.5 * 0.15, 1e-9));
        expect(text.position.y, closeTo(8, 1e-9));
      },
    );

    test('keeps an already-level last span as the landing', () {
      final created = Construct.leader(const [
        Vec2(20, 4),
        Vec2(8, 10),
        Vec2(2, 10),
      ], annotation: 'SEE DETAIL');

      expect(created, isNotNull);
      final leader = created!.whereType<LeaderEntity>().single;
      expect(leader.grips(), const [Vec2(20, 4), Vec2(8, 10), Vec2(2, 10)]);
      final text = created.whereType<TextEntity>().single;
      expect(text.hAlign, TextHAlign.right);
      expect(text.position.x, closeTo(2 - 2.5 * 0.15, 1e-9));
    });

    test('returns null for fewer than two distinct points', () {
      expect(Construct.leader(const [Vec2(1, 1)]), isNull);
      expect(Construct.leader(const [Vec2(1, 1), Vec2(1, 1)]), isNull);
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

  group('splineFromFit', () {
    test('passes through every fit point', () {
      const fits = [Vec2(0, 0), Vec2(1, 2), Vec2(3, 1), Vec2(4, 0), Vec2(6, 1)];
      final spline = Construct.splineFromFit(fits);
      expect(spline, isNotNull);
      expect(spline!.degree, 3);
      expect(spline.fitPointBuffer.length, 10);

      final chords = [
        for (var i = 1; i < fits.length; i++)
          math.max(fits[i].distanceTo(fits[i - 1]), 1e-12),
      ];
      final total = chords.fold<double>(0, (sum, item) => sum + item);
      var along = 0.0;
      for (var i = 0; i < fits.length; i++) {
        final t = i == 0
            ? 0.0
            : i == fits.length - 1
            ? 1.0
            : (along += chords[i - 1]) / total;
        final at = Flatten.bsplineEvaluate(
          controlPoints: spline.controlPoints,
          knots: spline.knots,
          degree: spline.degree,
          t: t,
        );
        expect(at, isNotNull);
        expect(at!.x, closeTo(fits[i].x, 1e-8));
        expect(at.y, closeTo(fits[i].y, 1e-8));
      }
    });

    test('control-point mode does not interpolate the middle click', () {
      const fits = [Vec2(0, 0), Vec2(0, 4), Vec2(4, 4), Vec2(4, 0)];
      final pulled = Construct.splineFromControls(fits)!;
      final mid = Flatten.bsplineEvaluate(
        controlPoints: pulled.controlPoints,
        knots: pulled.knots,
        degree: pulled.degree,
        t: 1 / 3,
      );
      expect(mid, isNotNull);
      expect((mid! - fits[1]).length, greaterThan(0.2));
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

    test('offsets an ellipse by growing both axes', () {
      const source = EllipseEntity(
        id: 1,
        center: Vec2.zero(),
        majorAxis: Vec2(10, 0),
        ratio: 0.5,
      );
      final outer = Construct.offset(source, 2, const Vec2(20, 0));
      expect(outer, isA<EllipseEntity>());
      final oval = outer! as EllipseEntity;
      expect(oval.majorLength, closeTo(12, 1e-9));
      expect(oval.majorLength * oval.ratio, closeTo(7, 1e-9));
    });

    test('a line crossing an ellipse is a TRIM cut', () {
      const oval = EllipseEntity(
        id: 1,
        center: Vec2.zero(),
        majorAxis: Vec2(10, 0),
        ratio: 1,
      );
      final cutter = line(-20, 0, 20, 0);
      final hits = Construct.crossingsAlong(cutter, oval);
      expect(hits.length, 2);
      final trimmed = Construct.trimLine(cutter, hits, const Vec2(0, 0));
      expect(trimmed, isNotNull);
      expect(trimmed!.length, closeTo(10, 1e-6));
    });

    test('trims and extends a spline through its flattened centreline', () {
      final spline = Construct.splineFromControls(const [
        Vec2.zero(),
        Vec2(10, 0),
        Vec2(20, 0),
      ])!;
      final cutter = line(10, -5, 10, 5);
      final hits = Construct.crossingsAlong(spline, cutter);
      expect(hits, isNotEmpty);
      final trimmed = Construct.trimSpline(spline, hits, const Vec2(2, 0));
      expect(trimmed, isNotNull);
      expect(
        Construct.lengthOf(trimmed!),
        lessThan(Construct.lengthOf(spline) - 1),
      );

      final short = Construct.splineFromControls(const [
        Vec2.zero(),
        Vec2(3, 0),
        Vec2(6, 0),
      ])!;
      final wall = line(12, -4, 12, 4);
      final grown = Construct.extendSpline(short, [wall]);
      expect(grown, isNotNull);
      expect(
        Construct.lengthOf(grown!),
        greaterThan(Construct.lengthOf(short)),
      );
    });

    test('offsets a circle outwards or inwards by the pick side', () {
      const source = CircleEntity(id: 1, center: Vec2(0, 0), radius: 10);

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
      final source = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;

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

    test('offsets a bulged arc segment concentrically', () {
      final source = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final outer =
          Construct.offset(source, 2, const Vec2(20, 20)) as PolylineEntity;
      expect(outer.vertexAt(0).x, closeTo(12, 1e-9));
      expect(outer.vertexAt(0).y, closeTo(0, 1e-9));
      expect(outer.vertexAt(1).x, closeTo(0, 1e-9));
      expect(outer.vertexAt(1).y, closeTo(12, 1e-9));
      expect(outer.bulgeAt(0), closeTo(math.tan(math.pi / 8), 1e-9));

      final inner =
          Construct.offset(source, 2, const Vec2(1, 1)) as PolylineEntity;
      expect(inner.vertexAt(0).x, closeTo(8, 1e-9));
      expect(inner.vertexAt(1).y, closeTo(8, 1e-9));
    });

    test('mitres a line into a following bulge', () {
      final joined = Construct.joinEntities([
        line(0, 0, 10, 0),
        ArcEntity(
          id: 2,
          center: const Vec2(0, 0),
          radius: 10,
          startAngle: 0,
          endAngle: math.pi / 2,
        ),
      ])!;

      final offset =
          Construct.offset(joined, 2, const Vec2(0, 5)) as PolylineEntity;
      expect(offset.hasBulges, isTrue);
      expect(offset.vertexAt(0).y, closeTo(2, 1e-9));
      expect(offset.vertexAt(1).x, closeTo(math.sqrt(60), 1e-9));
      expect(offset.vertexAt(1).y, closeTo(2, 1e-9));
      expect(offset.vertexAt(2).x, closeTo(0, 1e-9));
      expect(offset.vertexAt(2).y, closeTo(8, 1e-9));
    });

    eachCase(
      [
        (
          name: 'a point cannot invent an offset',
          entity: const PointEntity(id: 1, position: Vec2.zero()),
          distance: 2.0,
          pick: const Vec2(1, 1),
        ),
        (
          name: 'a text cannot invent an offset',
          entity: const TextEntity(id: 1, position: Vec2.zero(), content: 'x'),
          distance: 1.0,
          pick: const Vec2(1, 1),
        ),
        (
          name: 'a zero distance cannot invent an offset',
          entity: const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          distance: 0.0,
          pick: const Vec2(5, 5),
        ),
        (
          name: 'a negative distance cannot invent an offset',
          entity: const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          distance: -2.0,
          pick: const Vec2(5, 5),
        ),
        (
          name: 'a collapsed span cannot invent an offset',
          entity: const LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero()),
          distance: 2.0,
          pick: const Vec2(0, 1),
        ),
        (
          name: 'an inward arc cannot invent an offset remnant',
          entity: const ArcEntity(
            id: 2,
            center: Vec2.zero(),
            radius: 5,
            startAngle: 0,
            endAngle: math.pi / 2,
          ),
          distance: 5.0,
          pick: Vec2.zero(),
        ),
        (
          name: 'an oversized inward arc cannot invent an offset remnant',
          entity: const ArcEntity(
            id: 2,
            center: Vec2.zero(),
            radius: 5,
            startAngle: 0,
            endAngle: math.pi / 2,
          ),
          distance: 9.0,
          pick: Vec2.zero(),
        ),
      ],
      (c) {
        expect(Construct.offset(c.entity, c.distance, c.pick), isNull);
      },
    );
  });

  group('trimLine', () {
    test('removes the picked end back to the crossing', () {
      final source = line(0, 0, 10, 0);

      final trimmed = Construct.trimLine(source, [
        const Vec2(4, 0),
      ], const Vec2(8, 0));

      expect(trimmed, isNotNull);
      expect(trimmed!.start.x, closeTo(0, 1e-9));
      expect(trimmed.end.x, closeTo(4, 1e-9));
    });

    test('removes the other end when the pick is on it', () {
      final trimmed = Construct.trimLine(line(0, 0, 10, 0), [
        const Vec2(4, 0),
      ], const Vec2(1, 0));

      expect(trimmed!.start.x, closeTo(4, 1e-9));
      expect(trimmed.end.x, closeTo(10, 1e-9));
    });

    test('keeps the longer remnant when trimming out of the middle', () {
      // Two cuts with the pick between them would properly yield two lines.
      // Keeping the longer piece is the documented compromise; what matters is
      // that it is the longer one.
      final trimmed = Construct.trimLine(line(0, 0, 10, 0), [
        const Vec2(2, 0),
        const Vec2(4, 0),
      ], const Vec2(3, 0));

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

    test('a collapsed span cannot invent a remnant', () {
      const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
      expect(
        Construct.trimLine(collapsed, const [Vec2.zero()], const Vec2.zero()),
        isNull,
      );
    });

    test('an endpoint-only crossing cannot invent a remnant', () {
      const source = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
      expect(
        Construct.trimLine(source, const [Vec2.zero()], const Vec2(5, 0)),
        isNull,
      );
      expect(
        Construct.trimLine(source, const [Vec2(10, 0)], const Vec2(5, 0)),
        isNull,
      );
    });

    test('cuts against a bulged polyline on the arc, not the chord', () {
      final wall = PolylineEntity(
        id: 2,
        vertices: Float64List.fromList([10, 0, 1, -10, 0, 0]),
      );
      final crossings = Construct.crossingsWith(line(0, 0, 0, 20), wall);

      expect(crossings, hasLength(1));
      expect(crossings.single.y, closeTo(10, 1e-9));

      final trimmed = Construct.trimLine(
        line(0, 0, 0, 20),
        crossings,
        const Vec2(0, 15),
      );
      expect(trimmed, isNotNull);
      expect(trimmed!.end.y, closeTo(10, 1e-9));
    });
  });

  group('trimPolyline', () {
    final elbow = PolylineEntity.fromPoints(
      id: 1,
      points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
    );

    test('removes the picked tail back to the crossing', () {
      final trimmed = Construct.trimPolyline(elbow, const [
        Vec2(5, 0),
      ], const Vec2(8, 0));

      expect(trimmed, isNotNull);
      expect(trimmed!.vertexCount, 2);
      expect(trimmed.vertexAt(1).x, closeTo(5, 1e-9));
    });

    test('keeps the far side when the pick is on the start remnant', () {
      final trimmed = Construct.trimPolyline(elbow, const [
        Vec2(5, 0),
      ], const Vec2(1, 0));

      expect(trimmed!.vertexAt(0).x, closeTo(5, 1e-9));
      expect(trimmed.vertexAt(trimmed.vertexCount - 1), const Vec2(10, 10));
    });

    test('trims past a corner to a crossing on the second segment', () {
      final trimmed = Construct.trimPolyline(elbow, const [
        Vec2(10, 5),
      ], const Vec2(10, 8));

      expect(trimmed!.vertexCount, 3);
      expect(trimmed.vertexAt(2).y, closeTo(5, 1e-9));
    });

    test('cuts a bulge on the arc, not the chord', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );
      final cut = Vec2(10 * math.cos(math.pi / 4), 10 * math.sin(math.pi / 4));

      final trimmed = Construct.trimPolyline(quarter, [cut], const Vec2(0, 10));

      expect(trimmed, isNotNull);
      expect(trimmed!.vertexAt(1).x, closeTo(cut.x, 1e-9));
      expect(trimmed.vertexAt(1).y, closeTo(cut.y, 1e-9));
      expect(trimmed.bulgeAt(0), closeTo(math.tan(math.pi / 16), 1e-9));
    });

    test('opens a closed polyline by dropping the picked span', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      final trimmed = Construct.trimPolyline(square, const [
        Vec2(5, 0),
        Vec2(5, 10),
      ], const Vec2(10, 5));

      expect(trimmed, isNotNull);
      expect(trimmed!.closed, isFalse);
      expect(trimmed.vertexAt(0).x, closeTo(5, 1e-9));
      expect(trimmed.vertexAt(0).y, closeTo(10, 1e-9));
      expect(trimmed.vertexAt(trimmed.vertexCount - 1).x, closeTo(5, 1e-9));
      expect(trimmed.vertexAt(trimmed.vertexCount - 1).y, closeTo(0, 1e-9));
    });

    test('returns null when a closed polyline has only one crossing', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(10, 10))!;
      expect(
        Construct.trimPolyline(square, const [Vec2(5, 0)], const Vec2(10, 5)),
        isNull,
      );
    });

    test('empty crossings cannot invent a remnant', () {
      expect(
        Construct.trimPolyline(
          PolylineEntity.fromPoints(
            id: 2,
            points: const [Vec2.zero(), Vec2(10, 0), Vec2(10, 10)],
          ),
          const [],
          const Vec2(5, 0),
        ),
        isNull,
      );
    });

    test('a lone vertex cannot invent a remnant', () {
      expect(
        Construct.trimPolyline(
          PolylineEntity.fromPoints(id: 3, points: const [Vec2.zero()]),
          const [Vec2.zero()],
          const Vec2.zero(),
        ),
        isNull,
      );
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
      final trimmed = Construct.trimArc(semicircle, const [
        Vec2(0, 10),
      ], const Vec2(8, 6));

      expect(trimmed, isNotNull);
      expect(trimmed!.startAngle, closeTo(math.pi / 2, 1e-9));
      expect(trimmed.endAngle, closeTo(math.pi, 1e-9));
    });

    test('removes the other end when the pick is on it', () {
      final trimmed = Construct.trimArc(semicircle, const [
        Vec2(0, 10),
      ], const Vec2(-8, 6));

      expect(trimmed!.startAngle, closeTo(0, 1e-9));
      expect(trimmed.endAngle, closeTo(math.pi / 2, 1e-9));
    });

    test('returns null when there is nothing to cut against', () {
      expect(
        Construct.trimArc(semicircle, const [], const Vec2(0, 10)),
        isNull,
      );
    });

    test('a zero-radius arc cannot invent a remnant', () {
      const zeroRadius = ArcEntity(
        id: 2,
        center: Vec2.zero(),
        radius: 0,
        startAngle: 0,
        endAngle: 1,
      );
      expect(
        Construct.trimArc(zeroRadius, const [Vec2.zero()], const Vec2(1, 0)),
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

    test('empty edges cannot invent an extension', () {
      expect(
        Construct.extendLine(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          const [],
        ),
        isNull,
      );
    });

    test('a collapsed span cannot invent an extension', () {
      const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
      expect(
        Construct.extendLine(collapsed, [
          const LineEntity(id: 2, start: Vec2(10, -5), end: Vec2(10, 5)),
        ]),
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

    test('extends to a bulged polyline as its arc, not the chord', () {
      final wall = PolylineEntity(
        id: 2,
        vertices: Float64List.fromList([10, 0, 1, -10, 0, 0]),
      );
      final extended = Construct.extendLine(line(0, 0, 0, 5), [wall]);

      expect(extended, isNotNull);
      expect(extended!.end.y, closeTo(10, 1e-9));
      expect(extended.end.x, closeTo(0, 1e-9));
    });
  });

  group('extendPolyline', () {
    test('grows the last segment to meet a boundary', () {
      final elbow = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 5)],
      );
      final extended = Construct.extendPolyline(elbow, [line(5, 10, 15, 10)]);

      expect(extended, isNotNull);
      expect(extended!.vertexAt(2).y, closeTo(10, 1e-9));
      expect(extended.vertexAt(1), const Vec2(10, 0));
    });

    test('grows the first segment when that end is nearer the pick', () {
      final elbow = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(5, 0), Vec2(10, 0), Vec2(10, 10)],
      );
      final extended = Construct.extendPolyline(elbow, [
        line(0, -5, 0, 5),
      ], const Vec2(5, 0));

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

    test('empty edges cannot invent an extension', () {
      expect(
        Construct.extendPolyline(
          PolylineEntity.fromPoints(
            id: 2,
            points: const [Vec2.zero(), Vec2(10, 0)],
          ),
          const [],
        ),
        isNull,
      );
    });

    test('a lone vertex cannot invent an extension', () {
      expect(
        Construct.extendPolyline(
          PolylineEntity.fromPoints(id: 1, points: const [Vec2.zero()]),
          [const LineEntity(id: 2, start: Vec2(10, -5), end: Vec2(10, 5))],
        ),
        isNull,
      );
    });

    test('grows a bulge along its circle to a boundary', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final extended = Construct.extendPolyline(quarter, [line(-15, 0, -5, 0)]);

      expect(extended, isNotNull);
      expect(extended!.vertexAt(1).x, closeTo(-10, 1e-9));
      expect(extended.vertexAt(1).y, closeTo(0, 1e-9));
      expect(extended.bulgeAt(0), closeTo(1, 1e-9));
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
      final extended = Construct.extendArc(quarter, [line(-15, 0, -5, 0)]);

      expect(extended, isNotNull);
      expect(extended!.startAngle, closeTo(0, 1e-9));
      expect(extended.endAngle, closeTo(math.pi, 1e-9));
    });

    test('grows the start when that end is nearer the pick', () {
      final extended = Construct.extendArc(quarter, [
        line(-5, -10, 5, -10),
      ], const Vec2(10, 0));

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
      expect(Construct.extendArc(quarter, [line(-10, 20, -10, 15)]), isNull);
    });

    test('a zero-radius arc cannot invent an extension', () {
      const zeroRadius = ArcEntity(
        id: 3,
        center: Vec2.zero(),
        radius: 0,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      expect(
        Construct.extendArc(zeroRadius, [
          const LineEntity(id: 4, start: Vec2(-15, 0), end: Vec2(-5, 0)),
        ]),
        isNull,
      );
    });

    test('a closed loop cannot invent an extension', () {
      const fullCircle = ArcEntity(
        id: 3,
        center: Vec2.zero(),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi * 2,
      );
      expect(
        Construct.extendArc(fullCircle, [
          const LineEntity(id: 4, start: Vec2(-15, 0), end: Vec2(-5, 0)),
        ]),
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

    test('a negative or non-finite radius cannot invent a fillet', () {
      const vertical = LineEntity(id: 1, start: Vec2(0, 10), end: Vec2.zero());
      const horizontal = LineEntity(
        id: 2,
        start: Vec2.zero(),
        end: Vec2(10, 0),
      );
      expect(
        Construct.filletLines(
          vertical,
          horizontal,
          -2,
          const Vec2(0, 5),
          const Vec2(5, 0),
        ),
        isNull,
      );
      expect(
        Construct.filletLines(
          vertical,
          horizontal,
          double.nan,
          const Vec2(0, 5),
          const Vec2(5, 0),
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
      expect([
        for (var i = 0; i < filleted.vertexCount; i++) filleted.vertexAt(i),
      ], isNot(contains(const Vec2(0, 0))));
    });

    test('refuses a radius longer than the adjoining sides', () {
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(4, 4))!;
      expect(
        Construct.filletPolylineVertex(square, const Vec2(0, 0), 5),
        isNull,
      );
    });

    test('a zero radius or lone corner cannot invent a rounded vertex', () {
      final square = Construct.rectangle(
        const Vec2.zero(),
        const Vec2(10, 10),
      )!;
      expect(
        Construct.filletPolylineVertex(square, const Vec2.zero(), 0),
        isNull,
      );
      expect(
        Construct.filletPolylineVertex(
          PolylineEntity.fromPoints(
            id: 1,
            points: const [Vec2.zero(), Vec2(10, 0)],
          ),
          const Vec2(10, 0),
          2,
        ),
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
      expect([
        for (var i = 0; i < filleted.vertexCount; i++) filleted.vertexAt(i),
      ], isNot(contains(const Vec2(0, 0))));
      expect([
        for (var i = 0; i < filleted.vertexCount; i++) filleted.vertexAt(i),
      ], isNot(contains(const Vec2(10, 10))));
    });

    test('skips a corner whose sides are shorter than the radius', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10), Vec2(11, 10)],
      );
      final filleted = Construct.filletPolyline(polyline, 2);

      expect(filleted, isNotNull);
      expect(filleted!.vertexCount, 5);
      expect(filleted.vertexAt(3), const Vec2(10, 10));
    });

    test('a non-finite radius cannot invent a fillet', () {
      expect(
        Construct.filletPolyline(
          Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!,
          double.infinity,
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

    test('parallel lines cannot invent a chamfer cut', () {
      const left = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
      const right = LineEntity(id: 2, start: Vec2(0, 4), end: Vec2(10, 4));
      expect(
        Construct.chamferLines(
          left,
          right,
          2,
          2,
          const Vec2(5, 0),
          const Vec2(5, 4),
        ),
        isNull,
      );
    });

    test('a negative or non-finite distance cannot invent a chamfer', () {
      const vertical = LineEntity(id: 1, start: Vec2(0, 10), end: Vec2.zero());
      const horizontal = LineEntity(
        id: 2,
        start: Vec2.zero(),
        end: Vec2(10, 0),
      );
      expect(
        Construct.chamferLines(
          vertical,
          horizontal,
          -2,
          2,
          const Vec2(0, 5),
          const Vec2(5, 0),
        ),
        isNull,
      );
      expect(
        Construct.chamferLines(
          vertical,
          horizontal,
          2,
          double.nan,
          const Vec2(0, 5),
          const Vec2(5, 0),
        ),
        isNull,
      );
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
        Construct.chamferPolylineVertex(square, const Vec2(0, 0), dist1: 5),
        isNull,
      );
    });

    test('a zero distance or lone corner cannot invent a bevel', () {
      final square = Construct.rectangle(
        const Vec2.zero(),
        const Vec2(10, 10),
      )!;
      expect(
        Construct.chamferPolylineVertex(square, const Vec2.zero(), dist1: 0),
        isNull,
      );
      expect(
        Construct.chamferPolylineVertex(
          PolylineEntity.fromPoints(
            id: 1,
            points: const [Vec2.zero(), Vec2(10, 0)],
          ),
          const Vec2(10, 0),
          dist1: 2,
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
      expect([
        for (var i = 0; i < chamfered.vertexCount; i++) chamfered.vertexAt(i),
      ], isNot(contains(const Vec2(0, 0))));
      expect([
        for (var i = 0; i < chamfered.vertexCount; i++) chamfered.vertexAt(i),
      ], isNot(contains(const Vec2(10, 10))));
    });

    test('skips a corner whose sides are shorter than the distance', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10), Vec2(11, 10)],
      );
      final chamfered = Construct.chamferPolyline(polyline, dist1: 2);

      expect(chamfered, isNotNull);
      expect(chamfered!.vertexCount, 5);
      expect(chamfered.vertexAt(3), const Vec2(10, 10));
    });

    test('a non-finite distance cannot invent a chamfer', () {
      expect(
        Construct.chamferPolyline(
          Construct.rectangle(const Vec2.zero(), const Vec2(10, 10))!,
          dist1: double.infinity,
        ),
        isNull,
      );
    });
  });

  group('breakLine', () {
    test('splits a line at one interior point', () {
      final pieces = Construct.breakLine(line(0, 0, 10, 0), const Vec2(4, 0));

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
      expect(Construct.breakLine(line(0, 0, 10, 0), const Vec2(0, 0)), isNull);
    });

    test('a collapsed span cannot invent a break', () {
      const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
      expect(Construct.breakLine(collapsed, const Vec2.zero()), isNull);
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

    test('splits a bulge into two smaller bulges', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final pieces = Construct.breakPolyline(
        quarter,
        Vec2(10 * math.cos(math.pi / 4), 10 * math.sin(math.pi / 4)),
      );

      expect(pieces, hasLength(2));
      expect(pieces![0].vertexCount, 2);
      expect(pieces[0].bulgeAt(0), closeTo(math.tan(math.pi / 16), 1e-9));
      expect(pieces[1].bulgeAt(0), closeTo(math.tan(math.pi / 16), 1e-9));
      expect(
        pieces[0].vertexAt(1).x,
        closeTo(10 * math.cos(math.pi / 4), 1e-9),
      );
      expect(pieces[1].vertexAt(1).y, closeTo(10, 1e-9));
    });

    test('drops the span between two points on an open polyline', () {
      final polyline = PolylineEntity.fromPoints(
        id: 1,
        points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10), Vec2(20, 10)],
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

    test('a lone vertex cannot invent a remnant', () {
      expect(
        Construct.breakPolyline(
          PolylineEntity.fromPoints(id: 1, points: const [Vec2.zero()]),
          const Vec2.zero(),
        ),
        isNull,
      );
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

    test('a zero-radius arc cannot invent a break', () {
      const zeroRadius = ArcEntity(
        id: 2,
        center: Vec2.zero(),
        radius: 0,
        startAngle: 0,
        endAngle: math.pi,
      );
      expect(Construct.breakArc(zeroRadius, const Vec2.zero()), isNull);
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

    test('a zero-radius or coincident pair cannot invent a remnant', () {
      expect(
        Construct.breakCircle(
          const CircleEntity(id: 2, center: Vec2.zero(), radius: 0),
          const Vec2(1, 0),
          const Vec2(0, 1),
        ),
        isNull,
      );
      expect(
        Construct.breakCircle(
          const CircleEntity(id: 3, center: Vec2.zero(), radius: 10),
          const Vec2(10, 0),
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
      final joined = Construct.joinEntities([polyline, line(10, 10, 20, 10)]);

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
        Construct.joinEntities([line(0, 0, 10, 0), line(50, 50, 60, 50)]),
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
      final joined = Construct.joinEntities([line(0, 0, 10, 0), arc]);

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
        vertices: Float64List.fromList([0, 0, 1, 10, 0, 0, 10, 10, 0]),
      );
      final reversed = Construct.reverse(source) as PolylineEntity;

      expect(reversed.vertexAt(0), const Vec2(10, 10));
      expect(reversed.vertexAt(2), const Vec2(0, 0));
      expect(reversed.bulgeAt(1), closeTo(-1, 1e-9));
      expect(reversed.bulgeAt(2), 0);
    });

    eachCase(
      [
        (
          name: 'a collapsed span cannot invent a reversed line',
          entity: const LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero()),
        ),
        (
          name: 'a lone vertex cannot invent a reverse',
          entity: PolylineEntity.fromPoints(id: 3, points: const [Vec2.zero()]),
        ),
        (
          name: 'a point cannot invent a reverse',
          entity: const PointEntity(id: 1, position: Vec2.zero()),
        ),
        (
          name: 'an insert cannot invent a reverse',
          entity: const InsertEntity(
            id: 2,
            blockName: 'CELL',
            position: Vec2.zero(),
          ),
        ),
      ],
      (c) {
        expect(Construct.reverse(c.entity), isNull);
      },
    );
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

    test('follows a bulge as an arc, not the chord', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final points = Construct.dividePolyline(quarter, 2);

      expect(points, hasLength(1));
      expect(points.first.x, closeTo(10 * math.cos(math.pi / 4), 1e-9));
      expect(points.first.y, closeTo(10 * math.sin(math.pi / 4), 1e-9));
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

    test('follows a bulge as an arc, not the chord', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final points = Construct.measurePolyline(
        quarter,
        5 * math.pi / 2,
        const Vec2(10, 0),
      );

      expect(points, hasLength(1));
      expect(points.first.x, closeTo(10 * math.cos(math.pi / 4), 1e-9));
      expect(points.first.y, closeTo(10 * math.sin(math.pi / 4), 1e-9));
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
        Construct.lengthenLine(line(0, 0, 10, 0), const Vec2(10, 0), total: 0),
        isNull,
      );
      expect(
        Construct.lengthenLine(
          line(0, 0, 10, 0),
          const Vec2(10, 0),
          delta: -10,
        ),
        isNull,
      );
    });

    test('a collapsed span cannot invent a lengthened remnant', () {
      const collapsed = LineEntity(id: 1, start: Vec2.zero(), end: Vec2.zero());
      expect(
        Construct.lengthenLine(collapsed, const Vec2.zero(), total: 10),
        isNull,
      );
    });

    test('a non-finite total cannot invent a length change', () {
      const source = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
      expect(
        Construct.lengthenLine(source, const Vec2(10, 0), total: double.nan),
        isNull,
      );
      expect(
        Construct.lengthenLine(
          source,
          const Vec2(10, 0),
          total: double.infinity,
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

    test('a lone or collapsed vertex cannot invent a lengthened remnant', () {
      expect(
        Construct.lengthenPolyline(
          PolylineEntity.fromPoints(id: 2, points: const [Vec2.zero()]),
          const Vec2.zero(),
          total: 10,
        ),
        isNull,
      );
      expect(
        Construct.lengthenPolyline(
          PolylineEntity.fromPoints(
            id: 3,
            points: const [Vec2.zero(), Vec2.zero()],
          ),
          const Vec2.zero(),
          total: 10,
        ),
        isNull,
      );
    });

    test('a non-finite total cannot invent a length change', () {
      expect(
        Construct.lengthenPolyline(
          elbow,
          const Vec2(10, 10),
          total: double.nan,
        ),
        isNull,
      );
    });

    test('grows a bulge along its arc', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final longer = Construct.lengthenPolyline(
        quarter,
        const Vec2(0, 10),
        total: 10 * math.pi * 0.75,
      );

      expect(longer, isNotNull);
      expect(longer!.vertexAt(1).x, closeTo(-10 * math.cos(math.pi / 4), 1e-9));
      expect(longer.vertexAt(1).y, closeTo(10 * math.sin(math.pi / 4), 1e-9));
      expect(longer.bulgeAt(0), closeTo(math.tan(3 * math.pi / 16), 1e-9));
    });

    test('shortens a bulge along its arc', () {
      final quarter = PolylineEntity(
        id: 1,
        vertices: Float64List.fromList([
          10,
          0,
          math.tan(math.pi / 8),
          0,
          10,
          0,
        ]),
      );

      final shorter = Construct.lengthenPolyline(
        quarter,
        const Vec2(0, 10),
        total: 10 * math.pi / 4,
      );

      expect(shorter!.vertexAt(1).x, closeTo(10 * math.cos(math.pi / 4), 1e-9));
      expect(shorter.vertexAt(1).y, closeTo(10 * math.sin(math.pi / 4), 1e-9));
      expect(shorter.bulgeAt(0), closeTo(math.tan(math.pi / 16), 1e-9));
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

    test('a zero-radius or closed arc cannot invent a length change', () {
      const zeroArc = ArcEntity(
        id: 4,
        center: Vec2.zero(),
        radius: 0,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      expect(
        Construct.lengthenArc(zeroArc, const Vec2.zero(), total: 10),
        isNull,
      );
      expect(
        Construct.lengthenArc(
          quarter,
          const Vec2(0, 10),
          total: double.infinity,
        ),
        isNull,
      );
      expect(
        Construct.lengthenArc(
          const ArcEntity(
            id: 4,
            center: Vec2.zero(),
            radius: 10,
            startAngle: 0,
            endAngle: 0,
          ),
          const Vec2(10, 0),
          total: 10,
        ),
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
      expect(Construct.stretch(line(-8, 0, 8, 0), window, delta), isNull);
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

    eachCase(
      [
        (
          name: 'a window miss cannot invent a circle move',
          entity: const CircleEntity(id: 1, center: Vec2.zero(), radius: 5),
          window: const Bounds2(20, 20, 21, 21),
          delta: const Vec2(4, 0),
        ),
        (
          name: 'a window miss cannot invent a line stretch',
          entity: const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          window: const Bounds2(100, 100, 101, 101),
          delta: const Vec2(0, 4),
        ),
        (
          name: 'a zero delta cannot drag a line',
          entity: const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          window: const Bounds2(-1, -1, 1, 1),
          delta: Vec2.zero(),
        ),
        (
          name: 'a window miss cannot stretch an arc',
          entity: const ArcEntity(
            id: 1,
            center: Vec2.zero(),
            radius: 10,
            startAngle: 0,
            endAngle: math.pi / 2,
          ),
          window: const Bounds2(100, 100, 101, 101),
          delta: const Vec2(0, 4),
        ),
        (
          name: 'a window miss cannot drag a leader',
          entity: Construct.leader(const [
            Vec2(0, 0),
            Vec2(10, 5),
            Vec2(14, 5),
          ])!.single,
          window: const Bounds2(40, 40, 41, 41),
          delta: const Vec2(0, 3),
        ),
        (
          name: 'a window miss cannot drag a solid fill',
          entity: const SolidEntity(
            id: 1,
            corners: [Vec2(0, 0), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
          ),
          window: const Bounds2(40, 40, 41, 41),
          delta: const Vec2(0, 2),
        ),
        (
          name: 'a window miss cannot invent a hatch stretch',
          entity: HatchEntity(
            id: 1,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20]),
              ),
            ],
          ),
          window: const Bounds2(100, 100, 101, 101),
          delta: const Vec2(4, 0),
        ),
        (
          name: 'a window miss cannot invent an image stretch',
          entity: const ImageEntity(
            id: 1,
            reference: 'photo.png',
            origin: Vec2.zero(),
            uVector: Vec2(10, 0),
            vVector: Vec2(0, 8),
          ),
          window: const Bounds2(20, 20, 21, 21),
          delta: const Vec2(4, 0),
        ),
        (
          name: 'a window miss cannot invent an insert stretch',
          entity: const InsertEntity(
            id: 1,
            blockName: 'CELL',
            position: Vec2.zero(),
          ),
          window: const Bounds2(20, 20, 21, 21),
          delta: const Vec2(4, 0),
        ),
        (
          name: 'a window miss cannot move a text insertion',
          entity: const TextEntity(
            id: 1,
            position: Vec2.zero(),
            content: 'NOTE',
            height: 2.5,
          ),
          window: const Bounds2(20, 20, 21, 21),
          delta: const Vec2(4, 0),
        ),
        (
          name: 'a window miss cannot drag the whole spline',
          entity: Construct.splineFromControls(const [
            Vec2(0, 0),
            Vec2(4, 4),
            Vec2(8, 0),
            Vec2(12, 4),
          ])!,
          window: const Bounds2(100, 100, 101, 101),
          delta: const Vec2(0, 3),
        ),
        (
          name: 'a zero delta cannot drag a spline',
          entity: Construct.splineFromControls(const [
            Vec2(0, 0),
            Vec2(4, 4),
            Vec2(8, 0),
            Vec2(12, 4),
          ])!,
          window: const Bounds2(-1, -1, 1, 1),
          delta: Vec2.zero(),
        ),
      ],
      (c) {
        expect(Construct.stretch(c.entity, c.window, c.delta), isNull);
      },
    );

    test('capturing an arc end moves only that angle', () {
      const arc = ArcEntity(
        id: 1,
        center: Vec2.zero(),
        radius: 10,
        startAngle: 0,
        endAngle: math.pi / 2,
      );
      final stretched =
          Construct.stretch(arc, const Bounds2(9, -1, 11, 1), const Vec2(0, 4))!
              as ArcEntity;

      expect(stretched.center, const Vec2.zero());
      expect(stretched.radius, 10);
      expect(stretched.startAngle, closeTo(math.atan2(4, 10), 1e-9));
      expect(stretched.endAngle, closeTo(math.pi / 2, 1e-9));
    });

    test('a window stretch moves only the captured leader vertex', () {
      final leader =
          Construct.leader(const [Vec2(0, 0), Vec2(10, 5), Vec2(14, 5)])!.single
              as LeaderEntity;
      final stretched =
          Construct.stretch(
                leader,
                const Bounds2(-1, -1, 1, 1),
                const Vec2(0, 3),
              )!
              as LeaderEntity;

      expect(stretched.grips(), const [Vec2(0, 3), Vec2(10, 5), Vec2(14, 5)]);
      expect(stretched.hasArrowHead, isTrue);
    });

    test('a window stretch moves only the captured fill corner', () {
      const solid = SolidEntity(
        id: 1,
        corners: [Vec2(0, 0), Vec2(4, 0), Vec2(4, 3), Vec2(0, 3)],
      );
      final stretched =
          Construct.stretch(
                solid,
                const Bounds2(-1, -1, 1, 1),
                const Vec2(0, 2),
              )!
              as SolidEntity;

      expect(stretched.corners, const [
        Vec2(0, 2),
        Vec2(4, 0),
        Vec2(4, 3),
        Vec2(0, 3),
      ]);
    });

    test('a window that covers one hatch vertex only moves that vertex', () {
      final hatch = HatchEntity(
        id: 1,
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20]),
          ),
        ],
      );
      final stretched =
          Construct.stretch(
                hatch,
                const Bounds2(-1, -1, 1, 1),
                const Vec2(4, 0),
              )!
              as HatchEntity;
      expect(stretched.loops.single.vertices[0], closeTo(4, 1e-9));
      expect(stretched.loops.single.vertices[1], closeTo(0, 1e-9));
      expect(stretched.loops.single.vertices[2], closeTo(20, 1e-9));
      expect(stretched.loops.single.vertices[3], closeTo(0, 1e-9));
      expect(stretched.loops.single.vertices[4], closeTo(20, 1e-9));
      expect(stretched.loops.single.vertices[5], closeTo(20, 1e-9));
    });

    test('a window on the insertion point moves the text', () {
      const text = TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'NOTE',
        height: 2.5,
      );
      final stretched =
          Construct.stretch(
                text,
                const Bounds2(-1, -1, 1, 1),
                const Vec2(4, 0),
              )!
              as TextEntity;

      expect(stretched.position, const Vec2(4, 0));
      expect(stretched.content, 'NOTE');
      expect(stretched.height, 2.5);
    });

    test('a window stretch moves only the captured spline control', () {
      final spline = Construct.splineFromControls(const [
        Vec2(0, 0),
        Vec2(4, 4),
        Vec2(8, 0),
        Vec2(12, 4),
      ])!;
      final stretched =
          Construct.stretch(
                spline,
                const Bounds2(-1, -1, 1, 1),
                const Vec2(0, 3),
              )!
              as SplineEntity;

      expect(stretched.grips()[0], const Vec2(0, 3));
      expect(stretched.grips()[1], const Vec2(4, 4));
      expect(stretched.grips()[2], const Vec2(8, 0));
      expect(stretched.grips()[3], const Vec2(12, 4));
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
      final square = Construct.rectangle(const Vec2(0, 0), const Vec2(4, 3))!;

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

    test('stretches the first line across an overlapping neighbour', () {
      final first = LineEntity(
        id: 1,
        start: const Vec2(0, 0),
        end: const Vec2(10, 0),
      );
      final overlap = LineEntity(
        id: 2,
        start: const Vec2(5, 0),
        end: const Vec2(15, 0),
      );

      final plan = Construct.overkill([first, overlap]);

      expect(plan.erase, [2]);
      expect(plan.replace, hasLength(1));
      final grown = plan.replace.single as LineEntity;
      expect(grown.id, 1);
      expect(grown.start.x, closeTo(0, 1e-9));
      expect(grown.end.x, closeTo(15, 1e-9));
    });

    test('joins collinear lines that only touch at an endpoint', () {
      final first = LineEntity(
        id: 1,
        start: const Vec2(0, 0),
        end: const Vec2(5, 0),
      );
      final next = LineEntity(
        id: 2,
        start: const Vec2(5, 0),
        end: const Vec2(10, 0),
      );

      final plan = Construct.overkill([first, next]);

      expect(plan.erase, [2]);
      final grown = plan.replace.single as LineEntity;
      expect(grown.end.x, closeTo(10, 1e-9));
    });

    test('leaves a gap between collinear lines alone', () {
      final first = LineEntity(
        id: 1,
        start: const Vec2(0, 0),
        end: const Vec2(3, 0),
      );
      final later = LineEntity(
        id: 2,
        start: const Vec2(5, 0),
        end: const Vec2(10, 0),
      );

      expect(Construct.overkill([first, later]).isEmpty, isTrue);
    });

    test('does not merge lines that only share a colour on another layer', () {
      final first = LineEntity(
        id: 1,
        start: const Vec2(0, 0),
        end: const Vec2(10, 0),
      );
      final other = LineEntity(
        id: 2,
        props: const EntityProps(layer: 'WALLS'),
        start: const Vec2(5, 0),
        end: const Vec2(15, 0),
      );

      expect(Construct.overkill([first, other]).isEmpty, isTrue);
    });
  });

  group('justifyText', () {
    test('moves the insertion point so a left-to-right change stays put', () {
      final text = TextEntity(
        id: 1,
        position: const Vec2(0, 0),
        content: 'ABC',
        height: 10,
      );

      final justified = Construct.justifyText(text, 'right');

      expect(justified, isNotNull);
      expect(justified!.hAlign, TextHAlign.right);
      expect(justified.vAlign, TextVAlign.baseline);
      expect(justified.position.x, closeTo(3 * 10 * 0.62, 1e-9));
      expect(justified.position.y, closeTo(0, 1e-9));
    });

    test('keeps rotated text from sliding off its baseline', () {
      final text = TextEntity(
        id: 1,
        position: const Vec2(0, 0),
        content: 'AB',
        height: 10,
        rotation: math.pi / 2,
      );

      final justified = Construct.justifyText(text, 'right');

      expect(justified, isNotNull);
      expect(justified!.position.x, closeTo(0, 1e-9));
      expect(justified.position.y, closeTo(2 * 10 * 0.62, 1e-9));
    });

    test('rewrites an mtext attachment point', () {
      final text = MTextEntity(
        id: 1,
        position: const Vec2(0, 0),
        content: 'Hi',
        height: 10,
      );

      final justified = Construct.justifyMText(text, 'tr');

      expect(justified, isNotNull);
      expect(justified!.attachment, 3);
      expect(justified.hAlign, TextHAlign.right);
      expect(justified.vAlign, TextVAlign.top);
    });

    test('rejects align and unknown keywords', () {
      final text = TextEntity(id: 1, position: const Vec2.zero(), content: 'A');

      expect(Construct.justifyText(text, 'align'), isNull);
      expect(Construct.justifyText(text, 'widget'), isNull);
    });
  });
}
