import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('the paper-space main viewport and a zero-size window are dropped', () {
    final document = reader.readString('''
  0
SECTION
  2
OBJECTS
  0
LAYOUT
  1
Sheet
  2
*Paper_Space
  0
ENDSEC
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
*Paper_Space
  0
VIEWPORT
 69
1
 40
80
 41
60
  0
VIEWPORT
 69
2
 40
0
 41
60
  0
ENDBLK
  0
ENDSEC
  0
EOF
''');
    final sheet = document.layouts.singleWhere(
      (layout) => layout.name == 'Sheet',
    );
    expect(sheet.viewports, isEmpty);
    expect(sheet.plotWindow, isNull);
  });

  test('LAYOUT and VIEWPORT decode without a writer round trip', () {
    final document = reader.readString('''
  0
SECTION
  2
OBJECTS
  0
LAYOUT
  1
Sheet
  2
*Paper_Space
 71
1
 44
420
 45
297
 75
1
 72
4
 48
0
 49
0
140
100
141
80
142
2
290
1
  0
ENDSEC
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
*Paper_Space
  0
VIEWPORT
 69
3
  8
VP
 10
50
 20
40
 40
80
 41
60
 12
5
 22
6
 45
30
 50
90
 68
1
 90
16384
331
GRID
331
  
  0
ENDBLK
  0
ENDSEC
  0
EOF
''');
    final sheet = document.layouts.singleWhere(
      (layout) => layout.name == 'Sheet',
    );
    expect(sheet.blockName, '*Paper_Space');
    expect(sheet.tabOrder, 1);
    expect(sheet.paperWidth, 420);
    expect(sheet.paperHeight, 297);
    expect(sheet.plotRotation, 90);
    expect(sheet.plotScale, 2);
    expect(sheet.plotFit, isTrue);
    expect(sheet.plotWindow, const Bounds2(0, 0, 100, 80));

    final viewport = sheet.viewports.single;
    expect(viewport.layer, 'VP');
    expect(viewport.modelCenter, const Vec2(5, 6));
    expect(viewport.scale, 2);
    expect(viewport.rotation, closeTo(math.pi / 2, 1e-9));
    expect(viewport.locked, isTrue);
    expect(viewport.isOn, isTrue);
    expect(viewport.frozenLayers, ['GRID']);
    expect(viewport.paperBounds.minX, closeTo(10, 1e-9));
    expect(viewport.paperBounds.minY, closeTo(10, 1e-9));
    expect(viewport.paperBounds.maxX, closeTo(90, 1e-9));
    expect(viewport.paperBounds.maxY, closeTo(70, 1e-9));
  });
}
