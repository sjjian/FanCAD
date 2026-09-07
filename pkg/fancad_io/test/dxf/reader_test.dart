import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  CadDocument parse(String source) => reader.readString(source);

  test('empty or junk text yields an empty drawing rather than a throw', () {
    expect(reader.readString('').entities, isEmpty);
    expect(reader.readString('not a dxf\nat all').entities, isEmpty);
    expect(reader.readString('  0\nWIPEOUT\n 10\n0\n').entities, isEmpty);
  });

  test(
    'readFile loads the same line a nested writeFile just persisted',
    () async {
      final dir = tempDir(prefix: 'fancad-dxf-read-');
      final document = drawing(
        entities: const [
          LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        ],
      );
      final path = '${dir.path}/nested/part.dxf';
      await const DxfWriter().writeFile(path, document);

      final loaded = await reader.readFile(path);
      final line = loaded.entities.whereType<LineEntity>().single;
      expect(line.start, const Vec2.zero());
      expect(line.end, const Vec2(10, 0));
    },
  );

  group('header', () {
    test('header current layer and a frozen table layer survive a scan', () {
      final document = parse('''
  0
SECTION
  2
HEADER
  9
\$CLAYER
  8
DIM
  9
\$ACADVER
  1
AC1027
  0
ENDSEC
  0
SECTION
  2
TABLES
  0
LAYER
  2
DIM
 70
5
 62
1
  0
ENDSEC
  0
EOF
''');
      expect(document.currentLayer, 'DIM');
      expect(document.headerVariables[r'$ACADVER'], 'AC1027');
      final layer = document.layer('DIM')!;
      expect(layer.frozen, isTrue);
      expect(layer.locked, isTrue);
      expect(layer.visible, isTrue);
      expect(layer.color.value, 1);
    });

    eachCase([
      (
        name: 'DIMSTYLE and generic header vars survive a scan',
        source: r'''
  0
SECTION
  2
HEADER
  9
$DIMSTYLE
  2
ARCH
  9
$INSUNITS
 70
4
  9
$HANDSEED
  5
1F
  0
ENDSEC
  0
EOF
''',
        style: 'ARCH',
        insUnits: '4',
        handSeed: '1F',
      ),
      (
        name:
            'DIMSTYLE also accepts group 7 so a style table alias cannot be dropped',
        source: r'''
  0
SECTION
  2
HEADER
  9
$DIMSTYLE
  7
ISO-25
  0
ENDSEC
  0
EOF
''',
        style: 'ISO-25',
        insUnits: null,
        handSeed: null,
      ),
    ], (c) {
      final document = parse(c.source);
      expect(document.currentDimStyle, c.style);
      if (c.insUnits != null) {
        expect(document.headerVariables[r'$INSUNITS'], c.insUnits);
      }
      if (c.handSeed != null) {
        expect(document.headerVariables[r'$HANDSEED'], c.handSeed);
      }
    });
  });

  group('tables', () {
    test('an unnamed STYLE or LTYPE is skipped rather than stored blank', () {
      final document = parse('''
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
      final document = parse('''
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
  });

  group('entities', () {
    test('LINE and CIRCLE decode without a writer round trip', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
LINE
 10
0
 20
0
 11
4
 21
3
  0
CIRCLE
  8
HOLES
 10
5
 20
5
 40
2
  0
ENDSEC
  0
EOF
''');
      final line = document.entities.whereType<LineEntity>().single;
      expect(line.start, const Vec2.zero());
      expect(line.end, const Vec2(4, 3));
      final circle = document.entities.whereType<CircleEntity>().single;
      expect(circle.center, const Vec2(5, 5));
      expect(circle.radius, 2);
      expect(circle.props.layer, 'HOLES');
    });

    test('arc, point, text and ellipse decode without a writer round trip', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
ARC
 10
0
 20
0
 40
10
 50
0
 51
90
  0
POINT
  8
NODES
420
16711680
 10
3
 20
4
  0
TEXT
  1
Hello
 10
1
 20
2
 40
5
 50
90
  7
Standard
  0
MTEXT
  1
Hi
 10
0
 20
0
 40
2.5
 41
12
 71
9
  0
ELLIPSE
 10
0
 20
0
 11
4
 21
0
 40
0.5
 41
0
 42
${math.pi * 2}
  0
LWPOLYLINE
 90
0
  0
ENDSEC
  0
EOF
''');
      expect(document.entities.whereType<ArcEntity>().single.radius, 10);
      expect(
        document.entities.whereType<ArcEntity>().single.endAngle,
        closeTo(math.pi / 2, 1e-9),
      );
      final point = document.entities.whereType<PointEntity>().single;
      expect(point.position, const Vec2(3, 4));
      expect(point.props.layer, 'NODES');
      expect(point.props.color.kind, ColorKind.trueColor);
      expect(point.props.color.value, 16711680);
      expect(document.entities.whereType<TextEntity>().single.content, 'Hello');
      expect(
        document.entities.whereType<TextEntity>().single.rotation,
        closeTo(math.pi / 2, 1e-9),
      );
      expect(document.entities.whereType<MTextEntity>().single.attachment, 9);
      expect(
        document.entities.whereType<MTextEntity>().single.rectangleWidth,
        12,
      );
      expect(document.entities.whereType<EllipseEntity>().single.ratio, 0.5);
      expect(document.entities.whereType<PolylineEntity>(), isEmpty);
    });

    test('solid, ray and xline decode their corners and direction', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
SOLID
 10
0
 20
0
 11
2
 21
0
 12
2
 22
1
 13
0
 23
1
  0
RAY
 10
1
 20
1
 11
1
 21
0
  0
XLINE
 10
0
 20
0
 11
0
 21
1
  0
ENDSEC
  0
EOF
''');
      expect(
        document.entities.whereType<SolidEntity>().single.corners,
        const [Vec2.zero(), Vec2(2, 0), Vec2(2, 1), Vec2(0, 1)],
      );
      expect(
        document.entities.whereType<RayEntity>().single.direction,
        const Vec2(1, 0),
      );
      expect(
        document.entities.whereType<XLineEntity>().single.direction,
        const Vec2(0, 1),
      );
    });

    test('ARC, POINT, TEXT and MTEXT decode without a writer round trip', () {
      final document = parse(r'''
  0
SECTION
  2
ENTITIES
  0
ARC
 10
0
 20
0
 40
5
 50
0
 51
90
  0
POINT
 10
3
 20
4
  0
TEXT
  1
Hello
 10
1
 20
2
 40
3
 50
90
  7
Notes
  0
MTEXT
  1
{\fArial;Hi}
 10
8
 20
9
 40
2.5
 41
40
 71
5
  7
Title
  0
ENDSEC
  0
EOF
''');
      final arc = document.entities.whereType<ArcEntity>().single;
      expect(arc.center, const Vec2.zero());
      expect(arc.radius, 5);
      expect(arc.startAngle, closeTo(0, 1e-9));
      expect(arc.endAngle, closeTo(math.pi / 2, 1e-9));

      final point = document.entities.whereType<PointEntity>().single;
      expect(point.position, const Vec2(3, 4));

      final text = document.entities.whereType<TextEntity>().single;
      expect(text.content, 'Hello');
      expect(text.position, const Vec2(1, 2));
      expect(text.height, 3);
      expect(text.rotation, closeTo(math.pi / 2, 1e-9));
      expect(text.styleName, 'Notes');

      final mtext = document.entities.whereType<MTextEntity>().single;
      expect(mtext.content, r'{\fArial;Hi}');
      expect(mtext.rectangleWidth, 40);
      expect(mtext.attachment, 5);
      expect(mtext.styleName, 'Title');
    });

    test('ELLIPSE, SOLID, RAY, XLINE and a closed LWPOLYLINE decode', () {
      final document = parse(r'''
  0
SECTION
  2
ENTITIES
  0
ELLIPSE
 10
0
 20
0
 11
4
 21
0
 40
0.5
 41
0
 42
6.283185307179586
  0
SOLID
 10
0
 20
0
 11
2
 21
0
 12
2
 22
1
 13
0
 23
1
  0
RAY
 10
0
 20
0
 11
1
 21
0
  0
XLINE
 10
5
 20
5
 11
0
 21
1
  0
LWPOLYLINE
 70
1
 43
0.5
 10
0
 20
0
 42
1
 10
10
 20
0
  0
LWPOLYLINE
 70
0
  0
ENDSEC
  0
EOF
''');
      final ellipse = document.entities.whereType<EllipseEntity>().single;
      expect(ellipse.center, const Vec2.zero());
      expect(ellipse.majorAxis, const Vec2(4, 0));
      expect(ellipse.ratio, 0.5);

      final solid = document.entities.whereType<SolidEntity>().single;
      expect(solid.corners, const [
        Vec2(0, 0),
        Vec2(2, 0),
        Vec2(2, 1),
        Vec2(0, 1),
      ]);

      final ray = document.entities.whereType<RayEntity>().single;
      expect(ray.origin, const Vec2.zero());
      expect(ray.direction, const Vec2(1, 0));

      final xline = document.entities.whereType<XLineEntity>().single;
      expect(xline.origin, const Vec2(5, 5));
      expect(xline.direction, const Vec2(0, 1));

      final polyline = document.entities.whereType<PolylineEntity>().single;
      expect(polyline.closed, isTrue);
      expect(polyline.constantWidth, 0.5);
      expect(polyline.vertexCount, 2);
      expect(polyline.bulgeAt(0), 1);
      expect(document.entities.whereType<PolylineEntity>(), hasLength(1));
    });

    test('a -Z extrusion ELLIPSE bakes the opposite quadrant', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
ELLIPSE
 10
4328.3061
 20
3148.7434
 11
-4.975
 21
-4.975
 40
1
 41
${5 * math.pi / 4}
 42
${7 * math.pi / 4}
 210
0
 220
0
 230
-1
  0
ENDSEC
  0
EOF
''');
      final ellipse = document.entities.whereType<EllipseEntity>().single;
      expect(ellipse.startParam, closeTo(math.pi / 4, 1e-9));
      expect(ellipse.endParam, closeTo(3 * math.pi / 4, 1e-9));
      expect(ellipse.startPoint.x, closeTo(4328.3061, 1e-6));
      expect(ellipse.startPoint.y, lessThan(3148.7434));
      expect(ellipse.endPoint.y, closeTo(3148.7434, 1e-6));
      expect(ellipse.endPoint.x, greaterThan(4328.3061));
    });

    test('a two-vertex hatch is dropped rather than stored as an empty loop', () {
      final document = parse('''
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
      final document = parse('''
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

    test('a centred TEXT uses the alignment point, not the first corner', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
TEXT
  8
0
 10
0
 20
0
 11
50
 21
20
 40
2.5
  1
TITLE
 72
1
 73
2
  0
ENDSEC
  0
EOF
''');
      final text = document.entities.whereType<TextEntity>().single;
      expect(text.position.x, closeTo(50, 1e-9));
      expect(text.position.y, closeTo(20, 1e-9));
      expect(text.hAlign, TextHAlign.center);
      expect(text.vAlign, TextVAlign.middle);
    });

    test('INSERT rotation is degrees on the wire and radians in the model', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
INSERT
  2
BOLT
 10
1
 20
2
 41
2
 42
3
 50
90
  0
ENDSEC
  0
EOF
''');
      final insert = document.entities.whereType<InsertEntity>().single;
      expect(insert.blockName, 'BOLT');
      expect(insert.position, const Vec2(1, 2));
      expect(insert.scale, const Vec2(2, 3));
      expect(insert.rotation, closeTo(math.pi / 2, 1e-9));
      expect(insert.isArray, isFalse);
    });

    test('MINSERT, LEADER and IMAGE decode without a writer round trip', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
MINSERT
  2
CELL
 10
0
 20
0
 70
2
 71
3
 44
10
 45
5
  0
LEADER
 71
0
  3
CALLOUT
 10
0
 20
0
 10
4
 20
1
  0
IMAGE
  1
photo.png
 10
8
 20
9
 11
1
 21
0
 12
0
 22
1
  0
ENDSEC
  0
EOF
''');
      final array = document.entities.whereType<InsertEntity>().single;
      expect(array.blockName, 'CELL');
      expect(array.isArray, isTrue);
      expect(array.columnCount, 2);
      expect(array.rowCount, 3);
      expect(array.columnSpacing, 10);
      expect(array.rowSpacing, 5);

      final leader = document.entities.whereType<LeaderEntity>().single;
      expect(leader.hasArrowHead, isFalse);
      expect(leader.styleName, 'CALLOUT');
      expect(leader.vertices, [0.0, 0.0, 4.0, 1.0]);

      final image = document.entities.whereType<ImageEntity>().single;
      expect(image.reference, 'photo.png');
      expect(image.origin, const Vec2(8, 9));
      expect(image.uVector, const Vec2(1, 0));
      expect(image.vVector, const Vec2(0, 1));
    });

    test('an INSERT with extrusion (0,0,-1) is stored in WCS', () {
      final document = parse('''
  0
SECTION
  2
ENTITIES
  0
INSERT
  2
MARK
 10
-513651.937
 20
170415.059
 41
-4.17
 42
4.17
210
0
 220
0
230
-1
  0
ENDSEC
  0
EOF
''');
      final insert = document.entities.whereType<InsertEntity>().single;
      expect(insert.position.x, closeTo(513651.937, 1e-6));
      expect(insert.position.y, closeTo(170415.059, 1e-6));
      expect(insert.scale.x, closeTo(4.17, 1e-9));
      expect(insert.scale.y, closeTo(4.17, 1e-9));
      expect(insert.rotation, closeTo(0, 1e-9));
    });

    test('a BLOCK base point is the insertion origin, not discarded', () {
      final document = parse('''
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
TICK
 10
100
 20
50
  0
LINE
 10
100
 20
50
 11
101
 21
50
  0
ENDBLK
  0
ENDSEC
  0
EOF
''');
      expect(document.blocks['TICK']!.basePoint, const Vec2(100, 50));
      expect(document.entities.whereType<UnknownEntity>(), isEmpty);
    });
  });

  group('layouts', () {
    eachCase([
      (
        name: 'a paper block without LAYOUT still becomes a sheet',
        source: r'''
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
*Paper_Space
  0
LINE
 10
0
 20
0
 11
10
 21
0
  0
ENDBLK
  0
ENDSEC
  0
EOF
''',
        expectPaper: true,
      ),
      (
        name: 'model space cannot be invented as a paper sheet',
        source: r'''
  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
*Model_Space
  0
LINE
 10
0
 20
0
 11
1
 21
0
  0
ENDBLK
  0
ENDSEC
  0
EOF
''',
        expectPaper: false,
      ),
    ], (c) {
      final document = parse(c.source);
      final sheets = document.layouts.where((layout) => !layout.isModelSpace);
      if (c.expectPaper) {
        final sheet = sheets.single;
        expect(sheet.name, 'Layout1');
        expect(sheet.blockName, '*Paper_Space');
        expect(sheet.tabOrder, 1);
        expect(document.entitiesOf('*Paper_Space'), hasLength(1));
      } else {
        expect(sheets, isEmpty);
      }
    });

    test('the paper-space main viewport and a zero-size window are dropped', () {
      final document = parse('''
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
      final document = parse('''
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
  });
}
