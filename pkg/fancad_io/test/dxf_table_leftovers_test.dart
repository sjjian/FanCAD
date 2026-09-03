import 'dart:math' as math;

import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('an unnamed STYLE or LTYPE is skipped rather than stored blank', () {
    final document = reader.readString('''
  0
SECTION
  2
TABLES
  0
STYLE
 40
2.5
  0
LTYPE
  3
Dashed
 49
12
 49
-6
  0
ENDSEC
  0
EOF
''');
    expect(document.textStyles.keys, isNot(contains('')));
    expect(document.lineTypes.keys, isNot(contains('')));
  });

  test('LTYPE, STYLE and DIMSTYLE decode without a writer round trip', () {
    final document = reader.readString('''
  0
SECTION
  2
TABLES
  0
LTYPE
  2
DASHED
  3
Dashed __ __
 49
12
 49
-6
  0
STYLE
  2
ROMANS
  3
romans.shx
  4
bigfont.shx
 40
3
 41
0.8
 50
15
 71
6
  0
DIMSTYLE
  2
ARCH
140
3.5
 41
2
 42
1
 44
2
 46
0.5
 40
2
271
0
  7
ROMANS
  0
ENDSEC
  0
EOF
''');
    final dashed = document.lineTypes['DASHED']!;
    expect(dashed.description, 'Dashed __ __');
    expect(dashed.pattern, [12.0, -6.0]);
    expect(dashed.patternLength, 18);

    final style = document.textStyles['ROMANS']!;
    expect(style.fontFamily, 'romans.shx');
    expect(style.bigFontFamily, 'bigfont.shx');
    expect(style.height, 3);
    expect(style.widthFactor, 0.8);
    expect(style.obliqueAngle, closeTo(15 * math.pi / 180, 1e-9));
    expect(style.backwards, isTrue);
    expect(style.upsideDown, isTrue);
    expect(style.isShxFont, isTrue);

    final dim = document.dimStyle('ARCH');
    expect(dim.textHeight, 3.5);
    expect(dim.arrowSize, 2);
    expect(dim.extensionLineOffset, 1);
    expect(dim.extensionLineExtend, 2);
    expect(dim.textGap, 0.5);
    expect(dim.scale, 2);
    expect(dim.decimalPlaces, 0);
    expect(dim.textStyle, 'ROMANS');
  });
}
