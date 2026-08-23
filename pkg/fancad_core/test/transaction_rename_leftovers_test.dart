import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing or reserved block cannot invent a rename', () {
    final document = CadDocument();
    final transaction = Transaction(document)
      ..putBlock(const BlockRecord(name: 'DOOR'))
      ..putBlock(const BlockRecord(name: 'LEAF'))
      ..putBlock(const BlockRecord(name: '*U1', isAnonymous: true))
      ..putBlock(const BlockRecord(name: 'EXT', xrefPath: '/tmp/a.dwg'));

    expect(transaction.renameBlock('NOPE', 'NEXT'), isFalse);
    expect(transaction.renameBlock('DOOR', ''), isFalse);
    expect(transaction.renameBlock('DOOR', 'DOOR'), isFalse);
    expect(transaction.renameBlock('DOOR', 'LEAF'), isFalse);
    expect(transaction.renameBlock('*Model_Space', 'Nope'), isFalse);
    expect(transaction.renameBlock('*U1', 'CELL'), isFalse);
    expect(transaction.renameBlock('EXT', 'CELL'), isFalse);
    expect(document.blocks.containsKey('DOOR'), isTrue);
    expect(document.blocks.containsKey('LEAF'), isTrue);
    expect(document.blocks.containsKey('*U1'), isTrue);
    expect(document.blocks.containsKey('EXT'), isTrue);
  });
}
