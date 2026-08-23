import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a first header write cannot invent a previous value', () {
    final document = CadDocument();
    final put = HeaderVariablePatch(r'$FOO', '1', null);
    final undo = put.inverse(document);

    put.applyTo(document);
    expect(document.headerVariables[r'$FOO'], '1');
    undo.applyTo(document);
    expect(document.headerVariables[r'$FOO'], '');
  });
}
