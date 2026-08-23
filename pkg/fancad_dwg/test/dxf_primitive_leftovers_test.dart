import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('ARC, POINT, TEXT and MTEXT decode without a writer round trip', () {
    final document = reader.readString(r'''
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
    final document = reader.readString(r'''
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
}
