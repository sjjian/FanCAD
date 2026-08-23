import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a new dimstyle cannot invent a previous row', () {
    final document = CadDocument();
    const style = DimStyleDef(name: 'ARCH');
    final put = PutDimStylePatch(style, null);
    final undo = put.inverse(document);

    expect(undo, isA<RemoveDimStylePatch>());
    put.applyTo(document);
    expect(document.namedDimStyle('ARCH'), isNotNull);
    undo.applyTo(document);
    expect(document.namedDimStyle('ARCH'), isNull);
  });
}
