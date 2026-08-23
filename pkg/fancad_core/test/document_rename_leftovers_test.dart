import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing or colliding name cannot invent a rename', () {
    final document = CadDocument()
      ..putBlock(const BlockRecord(name: 'DOOR'))
      ..putBlock(const BlockRecord(name: 'LEAF'));

    expect(document.renameBlock('DOOR', ''), isFalse);
    expect(document.renameBlock('DOOR', 'DOOR'), isFalse);
    expect(document.renameBlock('NOPE', 'NEXT'), isFalse);
    expect(document.renameBlock('DOOR', 'LEAF'), isFalse);
    expect(document.removeBlock('NOPE'), isNull);
    expect(document.removeLayout('NOPE'), isFalse);
    expect(document.blocks.containsKey('DOOR'), isTrue);
  });
}
