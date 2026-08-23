import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  const reader = DxfReader();

  test('DIMSTYLE and generic header vars survive a scan', () {
    final document = reader.readString(r'''
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
''');
    expect(document.currentDimStyle, 'ARCH');
    expect(document.headerVariables[r'$INSUNITS'], '4');
    expect(document.headerVariables[r'$HANDSEED'], '1F');
  });

  test(
    'DIMSTYLE also accepts group 7 so a style table alias cannot be dropped',
    () {
      final document = reader.readString(r'''
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
''');
      expect(document.currentDimStyle, 'ISO-25');
    },
  );
}
