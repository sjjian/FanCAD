import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing or local block cannot invent a detach or bind', () {
    final host = CadDocument();
    final session = DocumentSession(id: 't', document: host);

    session.edit('local', (transaction) {
      transaction.putBlock(const BlockRecord(name: 'LOCAL', entityIds: []));
    });

    session.edit('miss', (transaction) {
      expect(
        const XrefResolver().detach(
          host: host,
          name: 'NOPE',
          transaction: transaction,
        ),
        isFalse,
      );
      expect(
        const XrefResolver().bind(
          host: host,
          name: 'LOCAL',
          transaction: transaction,
        ),
        isFalse,
      );
    });
  });

  test('a path without a stem still attaches as XREF', () {
    final host = CadDocument();
    final foreign = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final session = DocumentSession(id: 't', document: host);

    session.edit('attach', (transaction) {
      expect(
        const XrefResolver().attach(
          host: host,
          foreign: foreign,
          path: '/tmp/',
          transaction: transaction,
        ),
        'XREF',
      );
    });

    expect(host.blocks['XREF']!.isXref, isTrue);
    expect(host.activeEntities.whereType<InsertEntity>(), hasLength(1));
  });

  test('detach matches an xref name case-insensitively', () {
    final host = CadDocument();
    final foreign = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final session = DocumentSession(id: 't', document: host);

    session.edit('attach', (transaction) {
      const XrefResolver().attach(
        host: host,
        foreign: foreign,
        path: '/tmp/part.dxf',
        transaction: transaction,
      );
    });

    session.edit('detach', (transaction) {
      expect(
        const XrefResolver().detach(
          host: host,
          name: 'part',
          transaction: transaction,
        ),
        isTrue,
      );
    });

    expect(host.blocks.containsKey('PART'), isFalse);
  });
}
