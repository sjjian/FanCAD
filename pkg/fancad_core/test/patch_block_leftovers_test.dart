import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('undoing a new block cannot invent a previous definition', () {
    final document = CadDocument();
    const block = BlockRecord(name: 'TEMP');
    final put = PutBlockPatch(block, null);
    final undo = put.inverse(document);

    expect(undo, isA<RemoveBlockPatch>());
    put.applyTo(document);
    expect(document.blocks.containsKey('TEMP'), isTrue);
    undo.applyTo(document);
    expect(document.blocks.containsKey('TEMP'), isFalse);
  });
}
