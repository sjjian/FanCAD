import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('a paper block without LAYOUT still becomes a sheet', () {
    final document = reader.readString(r'''
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
''');
    final sheet = document.layouts.singleWhere(
      (layout) => !layout.isModelSpace,
    );
    expect(sheet.name, 'Layout1');
    expect(sheet.blockName, '*Paper_Space');
    expect(sheet.tabOrder, 1);
    expect(document.entitiesOf('*Paper_Space'), hasLength(1));
  });

  test('model space cannot be invented as a paper sheet', () {
    final document = reader.readString(r'''
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
''');
    expect(document.layouts.where((layout) => !layout.isModelSpace), isEmpty);
  });
}
