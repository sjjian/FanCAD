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
