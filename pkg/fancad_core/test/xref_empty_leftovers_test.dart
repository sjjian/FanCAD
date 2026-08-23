import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty foreign drawing cannot invent xref members', () {
    final host = CadDocument();
    final session = DocumentSession(id: 't', document: host);

    session.edit('attach', (transaction) {
      expect(
        const XrefResolver().attach(
          host: host,
          foreign: CadDocument(),
          path: '/tmp/blank.dxf',
          transaction: transaction,
        ),
        'BLANK',
      );
    });

    expect(host.blocks['BLANK']!.entityIds, isEmpty);
    expect(host.blocks['BLANK']!.isXref, isTrue);
    session.dispose();
  });
}
