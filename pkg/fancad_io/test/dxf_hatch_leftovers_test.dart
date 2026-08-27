import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('a two-vertex hatch is dropped rather than stored as an empty loop', () {
    final document = reader.readString('''
  0
SECTION
  2
ENTITIES
  0
HATCH
  2
ANSI31
 93
2
 10
0
 20
0
 10
4
 20
0
  0
ENDSEC
  0
EOF
''');
    expect(document.entities.whereType<HatchEntity>(), isEmpty);
  });

  test('HATCH, SPLINE and DIMENSION decode without a writer round trip', () {
    final document = reader.readString('''
  0
SECTION
  2
ENTITIES
  0
HATCH
  2
ANSI31
 70
0
 41
0
 52
45
 93
4
 10
0
 20
0
 10
10
 20
0
 10
10
 20
10
 10
0
 20
10
  0
SPLINE
 70
1
 71
3
 10
0
 20
0
 10
4
 20
0
 40
0
 40
1
 41
1
  0
DIMENSION
  2
*D1
 10
5
 20
8
 13
0
 23
0
 14
10
 24
0
 42
10
  1
TYP
  3
ARCH
 70
32
  0
ENDSEC
  0
EOF
''');
    final hatch = document.entities.whereType<HatchEntity>().single;
    expect(hatch.patternName, 'ANSI31');
    expect(hatch.solid, isFalse);
    expect(hatch.patternScale, 1);
    expect(hatch.patternAngle, closeTo(math.pi / 4, 1e-9));
    expect(hatch.loops, hasLength(1));
    expect(hatch.loops.single.pointCount, 4);

    final spline = document.entities.whereType<SplineEntity>().single;
    expect(spline.closed, isTrue);
    expect(spline.degree, 3);
    expect(spline.controlPoints, [0.0, 0.0, 4.0, 0.0]);
    expect(spline.knots, [0.0, 1.0]);
    expect(spline.weights, [1.0]);

    final dim = document.entities.whereType<DimensionEntity>().single;
    expect(dim.blockName, '*D1');
    expect(dim.textPosition, const Vec2(5, 8));
    expect(dim.definitionPoints, const [Vec2.zero(), Vec2(10, 0)]);
    expect(dim.measurement, 10);
    expect(dim.overrideText, 'TYP');
    expect(dim.styleName, 'ARCH');
    expect(dim.dimensionType, 32);
  });
}
