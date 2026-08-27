import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('empty or junk text yields an empty drawing rather than a throw', () {
    expect(reader.readString('').entities, isEmpty);
    expect(reader.readString('not a dxf\nat all').entities, isEmpty);
    expect(reader.readString('  0\nWIPEOUT\n 10\n0\n').entities, isEmpty);
  });

  test('header current layer and a frozen table layer survive a scan', () {
    final document = reader.readString('''
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

  test('arc, point, text and ellipse decode without a writer round trip', () {
    final document = reader.readString('''
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
    expect(document.entities.whereType<MTextEntity>().single.rectangleWidth, 12);
    expect(document.entities.whereType<EllipseEntity>().single.ratio, 0.5);
    expect(document.entities.whereType<PolylineEntity>(), isEmpty);
  });

  test('solid, ray and xline decode their corners and direction', () {
    final document = reader.readString('''
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
}
