import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a new layout cannot invent a previous tab', () {
    final document = CadDocument();
    const layout = Layout(name: 'A3', blockName: '*Paper_Space', tabOrder: 1);
    final put = PutLayoutPatch(layout);
    final undo = put.inverse(document);

    expect(undo, isA<RemoveLayoutPatch>());
    put.applyTo(document);
    expect(document.layouts.any((item) => item.name == 'A3'), isTrue);
    undo.applyTo(document);
    expect(document.layouts.any((item) => item.name == 'A3'), isFalse);
  });
}
