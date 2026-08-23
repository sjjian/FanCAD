import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing path cannot invent an attach name', () {
    final host = CadDocument();
    final foreign = CadDocument();
    final session = DocumentSession(id: 't', document: host);
    session.edit('attach', (transaction) {
      expect(
        const XrefResolver().attach(
          host: host,
          foreign: foreign,
          path: '',
          transaction: transaction,
        ),
        'XREF',
      );
    });
    expect(host.blocks.containsKey('XREF'), isTrue);
    expect(host.blocks['XREF']!.isXref, isFalse);
    session.dispose();
  });
}
