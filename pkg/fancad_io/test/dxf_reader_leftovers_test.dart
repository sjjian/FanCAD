import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test(
    'readFile loads the same line a nested writeFile just persisted',
    () async {
      final dir = Directory.systemTemp.createTempSync('fancad-dxf-read-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      final path = '${dir.path}/nested/part.dxf';
      await const DxfWriter().writeFile(path, document);

      final loaded = await reader.readFile(path);
      final line = loaded.entities.whereType<LineEntity>().single;
      expect(line.start, const Vec2.zero());
      expect(line.end, const Vec2(10, 0));
    },
  );

  test('LINE and CIRCLE decode without a writer round trip', () {
    final document = reader.readString('''
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
}
