import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a new linetype cannot invent a previous dash pattern', () {
    final document = CadDocument();
    const lineType = LineTypeDef(
      name: 'CUSTOM',
      pattern: [12, -6],
      patternLength: 18,
    );
    final put = PutLineTypePatch(lineType, null);
    final undo = put.inverse(document);

    put.applyTo(document);
    expect(document.lineTypes['CUSTOM']?.pattern, [12, -6]);
    undo.applyTo(document);
    expect(document.lineTypes['CUSTOM']?.pattern, isEmpty);
    expect(document.lineTypes['CUSTOM']?.patternLength, 0);
  });
}
