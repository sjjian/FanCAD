import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_io/src/fcb/reader.dart';
import 'package:test/test.dart';

void main() {
  test('a centred TEXT uses the alignment point, not the first corner', () {
    final document = const DxfReader().readString('''
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

  test('FCB text uses a trailing alignment point when eight numbers are present',
      () {
    expect(fcbTextPosition([0, 0, 2.5, 0, 1, 0]), const Vec2(0, 0));
    expect(fcbTextPosition([0, 0, 2.5, 0, 1, 0, 50, 20]), const Vec2(50, 20));
  });
}
