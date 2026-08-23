import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

HatchEntity boxHatch({String pattern = 'ANSI31', double angle = 0}) =>
    HatchEntity(
      id: 1,
      solid: false,
      patternName: pattern,
      patternAngle: angle,
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
    );

bool axisAligned(Float64List stroke) =>
    (stroke[0] - stroke[2]).abs() < 1e-6 ||
    (stroke[1] - stroke[3]).abs() < 1e-6;

void main() {
  test(
    'a SOLID pattern name emits no strokes even when the hatch is not solid',
    () {
      expect(
        const HatchGenerator().generate(boxHatch(pattern: 'SOLID')),
        isEmpty,
      );
    },
  );

  test(
    'an empty-vertex loop is treated as no boundary rather than a crash',
    () {
      final hatch = HatchEntity(
        id: 1,
        solid: false,
        patternName: 'NET',
        loops: [HatchLoop(vertices: Float64List(0))],
      );
      expect(const HatchGenerator().generate(hatch), isEmpty);
    },
  );

  test(
    'patternAngle rotates NET off the axes so a 45° hatch is not horizontal',
    () {
      final upright = const HatchGenerator().generate(boxHatch(pattern: 'NET'));
      final rotated = const HatchGenerator().generate(
        boxHatch(pattern: 'NET', angle: math.pi / 4),
      );
      expect(upright, isNotEmpty);
      expect(upright.every(axisAligned), isTrue);
      expect(rotated, isNotEmpty);
      expect(rotated.any((stroke) => !axisAligned(stroke)), isTrue);
    },
  );
}
