import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

HatchEntity boxHatch({
  String pattern = 'ANSI31',
  bool solid = false,
  double scale = 1,
  double angle = 0,
}) => HatchEntity(
  id: 1,
  solid: solid,
  patternName: pattern,
  patternScale: scale,
  patternAngle: angle,
  loops: [
    HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
  ],
);

void main() {
  group('HatchPattern', () {
    test('names are case-insensitive and unknown names fall back to ANSI31', () {
      expect(HatchPattern.named('ansi31').name, 'ANSI31');
      expect(HatchPattern.named('nope').name, 'ANSI31');
      expect(HatchPattern.named('SOLID').lines, isEmpty);
      expect(HatchPattern.builtIn.containsKey('NET'), isTrue);
    });
  });

  group('HatchGenerator', () {
    test('solid fills and empty loops produce no strokes', () {
      expect(const HatchGenerator().generate(boxHatch(solid: true)), isEmpty);
      expect(
        const HatchGenerator().generate(
          const HatchEntity(id: 1, solid: false, loops: []),
        ),
        isEmpty,
      );
    });

    test('a zero scale is treated as one so the pattern still draws', () {
      final strokes = const HatchGenerator().generate(boxHatch(scale: 0));
      expect(strokes, isNotEmpty);
    });

    test('a hatch far from the pattern origin still generates strokes', () {
      // Pattern lines are infinite and only their offset along the normal
      // carries meaning, so the finite stand-in has to be slid onto the
      // boundary. A production drawing sits tens of thousands of units from
      // the origin, where a segment centred on the origin misses its own
      // loops entirely and every hatch came out empty.
      final atOrigin = const HatchGenerator().generate(boxHatch());
      expect(atOrigin, isNotEmpty);

      for (final offset in <(double, double)>[
        (5000, 500),
        (55391, 9462),
        (-120000, 340000),
      ]) {
        final moved = HatchEntity(
          id: 1,
          solid: false,
          patternName: 'ANSI31',
          loops: [
            HatchLoop(
              vertices: Float64List.fromList([
                offset.$1, offset.$2,
                offset.$1 + 20, offset.$2,
                offset.$1 + 20, offset.$2 + 20,
                offset.$1, offset.$2 + 20,
              ]),
            ),
          ],
        );
        final strokes = const HatchGenerator().generate(moved);
        expect(
          strokes.length,
          closeTo(atOrigin.length, 2),
          reason: 'translating a hatch must not change how it is filled',
        );
        for (final stroke in strokes) {
          for (var i = 0; i < stroke.length; i += 2) {
            expect(stroke[i], inInclusiveRange(offset.$1 - 1e-6, offset.$1 + 20 + 1e-6));
            expect(
              stroke[i + 1],
              inInclusiveRange(offset.$2 - 1e-6, offset.$2 + 20 + 1e-6),
            );
          }
        }
      }
    });

    test('a long thin region at a production offset is filled', () {
      // The shape this was found on: a 2992 x 23 U-profile section at
      // ANSI31 scale 5, which fell back to drawing its boundary as linework
      // and painted over the green outline underneath it.
      final bar = HatchEntity(
        id: 1,
        solid: false,
        patternName: 'ANSI31',
        patternAngle: 0.7853981633974483,
        patternScale: 5,
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([
              55391, 9462,
              58383, 9462,
              58383, 9485,
              55391, 9485,
            ]),
          ),
        ],
      );
      expect(const HatchGenerator().generate(bar), isNotEmpty);
    });

    test('the definition lines in the file win over the pattern table', () {
      // A 23 x 1483 honeycomb section from a production drawing. Its pattern
      // is named ANSI31 and its entity angle is 45 degrees, but the DWG also
      // carries the resolved definition line: horizontal, spaced 15.875. Rot-
      // ating the table's own 45 degrees by another 45 gives lines that run
      // along the bar instead of across it, and only two of them fit.
      const spacing = 15.875;
      final bar = HatchEntity(
        id: 1,
        solid: false,
        patternName: 'ANSI31',
        patternAngle: 0.7853981633974483,
        patternScale: 5,
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([
              54928.4, 7607.1,
              54928.4, 9090.6,
              54905.4, 9090.6,
              54905.4, 7607.1,
            ]),
          ),
        ],
        patternLines: const [
          HatchPatternLine(
            angle: math.pi,
            originX: 45236.355,
            originY: -40545.868,
            deltaY: -spacing,
          ),
        ],
      );

      final strokes = const HatchGenerator().generate(bar);
      expect(strokes, hasLength(93));
      final rows = <double>[];
      for (final stroke in strokes) {
        expect(stroke[1], closeTo(stroke[3], 1e-6), reason: 'rungs run across');
        expect(
          (stroke[0] - stroke[2]).abs(),
          closeTo(23, 1e-6),
          reason: 'a rung spans the full width of the section',
        );
        rows.add(stroke[1]);
      }
      rows.sort();
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i] - rows[i - 1], closeTo(spacing, 1e-6));
      }

      // Without them the same entity falls back to the table and its angle.
      final table = const HatchGenerator().generate(
        bar.copyWith(patternLines: const []),
      );
      expect(table, hasLength(2));
    });

    test('NET strokes stay inside the boundary', () {
      final strokes = const HatchGenerator().generate(boxHatch(pattern: 'NET'));
      expect(strokes, isNotEmpty);
      for (final stroke in strokes) {
        for (var i = 0; i < stroke.length; i += 2) {
          expect(stroke[i], inInclusiveRange(-1e-6, 20 + 1e-6));
          expect(stroke[i + 1], inInclusiveRange(-1e-6, 20 + 1e-6));
        }
      }
    });
  });

  group('HatchEntity', () {
    test('copyWith keeps the loops and emit fills a solid', () {
      final hatch = boxHatch().copyWith(patternName: 'STEEL', patternScale: 2);
      expect(hatch.patternName, 'STEEL');
      expect(hatch.patternScale, 2);
      expect(hatch.loops, hasLength(1));
      final sink = PolylineSink();
      boxHatch(solid: true).emit(const EmitContext(tolerance: 0.1), sink);
      expect(sink.fills, isNotEmpty);
    });

    test('a grip on the inner loop does not move the outer vertices', () {
      final hatch = HatchEntity(
        id: 1,
        solid: true,
        loops: [
          HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
          HatchLoop(
            vertices: Float64List.fromList([6, 6, 10, 6, 10, 10, 6, 10]),
            isOuter: false,
          ),
        ],
      );
      expect(hatch.grips(), hasLength(8));
      final edited = hatch.withGrip(5, const Vec2(12, 7));
      expect(edited.loops.first.vertices[0], 0);
      expect(edited.loops.last.vertices[2], closeTo(12, 1e-9));
      expect(edited.loops.last.vertices[3], closeTo(7, 1e-9));
      expect(hatch.withGrip(20, const Vec2.zero()), hatch);

      final sink = PolylineSink();
      edited.emit(const EmitContext(tolerance: 0.1), sink);
      expect(sink.fills, hasLength(1));
      expect(sink.polylines, hasLength(2));
    });

    test('a solid with only an island still fills that ring', () {
      const empty = HatchEntity(id: 1, loops: []);
      final silent = PolylineSink();
      empty.emit(const EmitContext(tolerance: 0.1), silent);
      expect(silent.fills, isEmpty);

      final island = HatchEntity(
        id: 1,
        solid: true,
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([0, 0, 4, 0, 4, 4, 0, 4]),
            isOuter: false,
          ),
        ],
      );
      final sink = PolylineSink();
      island.emit(const EmitContext(tolerance: 0.1), sink);
      expect(sink.fills, hasLength(1));
      expect(sink.polylines, hasLength(1));
    });
  });
}
