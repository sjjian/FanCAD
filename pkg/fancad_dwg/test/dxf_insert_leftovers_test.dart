import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('INSERT rotation is degrees on the wire and radians in the model', () {
    final document = reader.readString('''
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
    final document = reader.readString('''
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
}
