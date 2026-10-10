import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

/// Every [Curve] must agree with itself about where a parameter lands.
///
/// TRIM, BREAK, LENGTHEN and EXTEND are written once against these four
/// members, so a type whose `span` and `along` disagree cuts in the wrong
/// place in every one of those commands at once.
void main() {
  final curves = <String, Curve>{
    'line': const LineEntity(id: 1, start: Vec2(-2, 1), end: Vec2(8, 6)),
    'arc across zero': const ArcEntity(
      id: 2,
      center: Vec2(1, 2),
      radius: 5,
      startAngle: math.pi * 1.5,
      endAngle: math.pi / 2,
    ),
    'circle': const CircleEntity(id: 3, center: Vec2(4, -1), radius: 3),
    'tilted elliptical arc': const EllipseEntity(
      id: 4,
      center: Vec2(2, 2),
      majorAxis: Vec2(4, 3),
      ratio: 0.5,
      startParam: 1,
      endParam: 5,
    ),
    'full ellipse': const EllipseEntity(
      id: 5,
      center: Vec2(-3, 0),
      majorAxis: Vec2(0, 6),
      ratio: 0.4,
      startParam: 0.5,
      endParam: 0.5,
    ),
    'open polyline with a bulge': PolylineEntity(
      id: 6,
      vertices: Float64List.fromList([0, 0, 0, 10, 0, 0.6, 10, 8, 0, 3, 8, 0]),
      constantWidth: 0.2,
    ),
    'polyline ending on a bulge': PolylineEntity(
      id: 7,
      vertices: Float64List.fromList([0, 0, 0, 6, 0, -0.4, 6, 5, 0]),
    ),
    'closed polyline with a bulge': PolylineEntity(
      id: 8,
      vertices: Float64List.fromList([0, 0, 0, 8, 0, 1, 8, 6, 0, 0, 6, 0]),
      closed: true,
    ),
    'spline': SplineEntity(
      id: 9,
      controlPoints: Float64List.fromList([0, 0, 2, 5, 6, -3, 9, 4, 12, 0]),
      knots: const [0, 0, 0, 0, 0.5, 1, 1, 1, 1],
    ),
  };

  const tolerance = 1e-6;
  const samples = [0.1, 0.25, 0.5, 0.73, 0.9];

  void expectNear(Vec2 actual, Vec2 expected, String reason) {
    expect(
      actual.distanceTo(expected),
      lessThan(tolerance),
      reason: '$reason: $actual vs $expected',
    );
  }

  for (final MapEntry(key: name, value: curve) in curves.entries) {
    group(name, () {
      test('paramNear inverts along', () {
        for (final t in samples) {
          expect(curve.paramNear(curve.along(t)), closeTo(t, 1e-6));
        }
        if (!curve.isLoop) {
          expect(curve.paramNear(curve.along(0)), closeTo(0, 1e-9));
          expect(curve.paramNear(curve.along(1)), closeTo(1, 1e-9));
        }
      });

      test('a span starts and ends where along says', () {
        for (final (from, to) in [(0.0, 0.4), (0.25, 0.9), (0.6, 1.0)]) {
          final piece = curve.span(from, to);
          expect(piece, isA<Curve>(), reason: 'span($from, $to)');
          piece as Curve;
          expect(piece.id, curve.id);
          expectNear(piece.along(0), curve.along(from), 'start of $from..$to');
          expectNear(piece.along(1), curve.along(to), 'end of $from..$to');
        }
      });

      test('two spans that meet add up to the whole', () {
        final first = curve.span(0, 0.35) as Curve;
        final second = curve.span(0.35, 1) as Curve;
        expect(
          first.pathLength + second.pathLength,
          closeTo(curve.pathLength, 1e-6),
        );
      });

      if (curve.isLoop) {
        test('a span across the seam runs forward', () {
          final across = curve.span(0.7, 0.2) as Curve;
          final rest = curve.span(0.2, 0.7) as Curve;
          expectNear(across.along(0), curve.along(0.7), 'start');
          expectNear(across.along(1), curve.along(0.2), 'end');
          expect(
            across.pathLength + rest.pathLength,
            closeTo(curve.pathLength, 1e-6),
          );
        });

        test('a loop cannot grow', () {
          expect(curve.maxGrowth(atStart: true), 0);
          expect(curve.maxGrowth(atStart: false), 0);
        });
      } else {
        test('an empty or backward span is null', () {
          expect(curve.span(0.4, 0.4), isNull);
          expect(curve.span(0.6, 0.3), isNull);
        });

        test('a span past either end continues the way the end heads', () {
          final growth = math.min(
            0.2,
            math.min(
              curve.maxGrowth(atStart: true),
              curve.maxGrowth(atStart: false),
            ),
          );
          final grown = curve.span(-growth, 1 + growth) as Curve;
          final length = 1 + 2 * growth;
          expectNear(grown.along(growth / length), curve.along(0), 'old start');
          expectNear(
            grown.along((1 + growth) / length),
            curve.along(1),
            'old end',
          );
          if (curve is! EllipseEntity) {
            expect(grown.pathLength, closeTo(curve.pathLength * length, 1e-6));
          }
        });

        test('a span cannot reach past maxGrowth', () {
          for (final atStart in [true, false]) {
            final limit = curve.maxGrowth(atStart: atStart);
            if (limit.isInfinite) continue;
            expect(
              atStart
                  ? curve.span(-limit * 1.01, 1)
                  : curve.span(0, 1 + limit * 1.01),
              isNull,
            );
            expect(
              atStart ? curve.span(-limit, 1) : curve.span(0, 1 + limit),
              isNotNull,
            );
          }
        });
      }
    });
  }

  test('an arc span that keeps an end keeps its stored angle', () {
    final arc = curves['arc across zero']! as ArcEntity;
    final shortened = arc.span(0.5, 1)!;
    expect(shortened.endAngle, arc.endAngle);
    expect(shortened.startAngle, closeTo(arc.endAngle - arc.sweep / 2, 1e-12));
    expect(arc.span(0, 0.5)!.startAngle, arc.startAngle);
  });

  test('a polyline span splits a bulge onto the arc, not the chord', () {
    final polyline = curves['open polyline with a bulge']! as PolylineEntity;
    final half = polyline.span(0, 0.5)!;
    for (var i = 0; i < 40; i++) {
      final point = half.along(i / 40);
      expect(
        polyline.along(polyline.paramNear(point)).distanceTo(point),
        lessThan(1e-6),
      );
    }
    expect(half.constantWidth, polyline.constantWidth);
    expect(half.closed, isFalse);
  });

  test('a bulge grown almost to a full turn stays on its circle', () {
    final quarter = PolylineEntity(
      id: 1,
      vertices: Float64List.fromList([10, 0, math.tan(math.pi / 8), 0, 10, 0]),
    );
    final tail = quarter.span(1, 1 + quarter.maxGrowth(atStart: false))!;
    expect(tail.vertexAt(0).distanceTo(const Vec2(0, 10)), lessThan(1e-12));
    expect(tail.vertexAt(1).distanceTo(Vec2.zero()), closeTo(10, 1e-12));
  });

  test('a circle span is the counter-clockwise arc between the params', () {
    final circle = curves['circle']! as CircleEntity;
    final arc = circle.span(0.75, 0.25)!;
    expect(arc.sweep, closeTo(math.pi, 1e-12));
    expectNear(arc.startPoint, const Vec2(4, -4), 'bottom');
  });
}
