import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a new layer cannot invent a previous table row', () {
    final document = CadDocument();
    const layer = LayerDef(name: 'TEMP');
    final put = PutLayerPatch(layer);
    final undo = put.inverse(document);

    expect(undo, isA<RemoveLayerPatch>());
    put.applyTo(document);
    expect(document.layer('TEMP'), isNotNull);
    undo.applyTo(document);
    expect(document.layer('TEMP'), isNull);
  });
}
