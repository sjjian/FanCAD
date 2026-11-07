import 'dart:math' as math;

import 'hatch_pattern_line.dart';

/// A named hatch pattern, matching the `.pat` file convention.
class HatchPattern {
  const HatchPattern({required this.name, required this.lines});

  final String name;
  final List<HatchPatternLine> lines;

  static final Map<String, HatchPattern> builtIn = {
    'SOLID': const HatchPattern(name: 'SOLID', lines: []),
    'ANSI31': HatchPattern(
      name: 'ANSI31',
      lines: [HatchPatternLine(angle: math.pi / 4, deltaY: 3.175)],
    ),
    'ANSI32': HatchPattern(
      name: 'ANSI32',
      lines: [
        HatchPatternLine(angle: math.pi / 4, deltaY: 9.525),
        HatchPatternLine(angle: math.pi / 4, originX: 4.7625, deltaY: 9.525),
      ],
    ),
    'ANSI37': HatchPattern(
      name: 'ANSI37',
      lines: [
        HatchPatternLine(angle: math.pi / 4, deltaY: 3.175),
        HatchPatternLine(angle: -math.pi / 4, deltaY: 3.175),
      ],
    ),
    'NET': HatchPattern(
      name: 'NET',
      lines: [
        HatchPatternLine(angle: 0, deltaY: 3.175),
        HatchPatternLine(angle: math.pi / 2, deltaY: 3.175),
      ],
    ),
    'DOTS': HatchPattern(
      name: 'DOTS',
      lines: [
        HatchPatternLine(angle: 0, deltaY: 3.175, dashes: [0, -3.175]),
      ],
    ),
    'STEEL': HatchPattern(
      name: 'STEEL',
      lines: [
        HatchPatternLine(angle: math.pi / 4, deltaY: 3.175),
        HatchPatternLine(angle: math.pi / 4, originX: 1.5875, deltaY: 3.175),
      ],
    ),
  };

  static HatchPattern named(String name) =>
      builtIn[name.toUpperCase()] ?? builtIn['ANSI31']!;
}
