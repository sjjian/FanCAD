import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a new text style cannot invent a previous font', () {
    final document = CadDocument();
    const style = TextStyleDef(name: 'Notes', fontFamily: 'Arial', height: 5);
    final put = PutTextStylePatch(style, null);
    final undo = put.inverse(document);

    put.applyTo(document);
    expect(document.textStyles['Notes']?.fontFamily, 'Arial');
    undo.applyTo(document);
    expect(document.textStyles['Notes']?.fontFamily, 'txt');
    expect(document.textStyles['Notes']?.height, 0);
  });
}
