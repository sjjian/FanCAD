import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('junk hatch loops cannot invent a boundary', () {
    final hatch = CadEntity.fromJson(const {
      'type': 'hatch',
      'loops': 'nope',
    }) as HatchEntity;
    expect(hatch.loops, isEmpty);
    final sink = PolylineSink();
    hatch.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });

  test('resolved definition lines survive a JSON round trip', () {
    final hatch = HatchEntity(
      id: 7,
      solid: false,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20])),
      ],
      patternLines: const [
        HatchPatternLine(
          angle: 3.141592653589793,
          originX: 45236.355,
          originY: -40545.868,
          deltaY: -15.875,
          dashes: [2, -1],
        ),
      ],
    );

    final decoded =
        CadEntity.fromJson(hatch.toJson()) as HatchEntity;
    expect(decoded.patternLines, hasLength(1));
    expect(decoded.patternLines.single.angle, closeTo(math.pi, 1e-12));
    expect(decoded.patternLines.single.originY, closeTo(-40545.868, 1e-9));
    expect(decoded.patternLines.single.deltaY, closeTo(-15.875, 1e-12));
    expect(decoded.patternLines.single.dashes, [2, -1]);

    // A hatch that only names a pattern must not grow an empty list key.
    expect(
      HatchEntity(id: 8, loops: hatch.loops).toJson(),
      isNot(contains('patternLines')),
    );
  });
}
