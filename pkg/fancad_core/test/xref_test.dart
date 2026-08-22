import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('attaching an xref places one insert in model space', () {
    final host = CadDocument();
    final foreign = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final session = DocumentSession(id: 't', document: host);

    session.edit('Attach xref', (transaction) {
      const XrefResolver().attach(
        host: host,
        foreign: foreign,
        path: r'C:\parts\bracket.dxf',
        at: const Vec2(5, 6),
        transaction: transaction,
      );
    });

    expect(host.blocks['BRACKET']!.isXref, isTrue);
    expect(host.blocks['BRACKET']!.xrefPath, r'C:\parts\bracket.dxf');
    expect(host.blocks['BRACKET']!.entityIds, hasLength(1));
    final insert = host.activeEntities.whereType<InsertEntity>().single;
    expect(insert.blockName, 'BRACKET');
    expect(insert.position, const Vec2(5, 6));
  });

  test('reattaching the same xref keeps the existing insert', () {
    final host = CadDocument();
    final first = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final second = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(20, 0)),
      );
    final session = DocumentSession(id: 't', document: host);

    session.edit('Attach xref', (transaction) {
      const XrefResolver().attach(
        host: host,
        foreign: first,
        path: '/tmp/part.dxf',
        at: const Vec2(3, 4),
        transaction: transaction,
      );
    });
    final insertId = host.activeEntities.whereType<InsertEntity>().single.id;

    session.edit('Reload xref', (transaction) {
      const XrefResolver().attach(
        host: host,
        foreign: second,
        path: '/tmp/part.dxf',
        at: const Vec2(99, 99),
        transaction: transaction,
      );
    });

    final inserts = host.activeEntities.whereType<InsertEntity>().toList();
    expect(inserts, hasLength(1));
    expect(inserts.single.id, insertId);
    expect(inserts.single.position, const Vec2(3, 4));
    expect(host.blocks['PART']!.entityIds, hasLength(1));
    final line = host.entity(host.blocks['PART']!.entityIds.single)! as LineEntity;
    expect(line.end.x, closeTo(20, 1e-9));
  });

  test('detaching an xref removes the insert and the block', () {
    final host = CadDocument();
    final foreign = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final session = DocumentSession(id: 't', document: host);

    session.edit('Attach xref', (transaction) {
      const XrefResolver().attach(
        host: host,
        foreign: foreign,
        path: '/tmp/part.dxf',
        at: const Vec2(3, 4),
        transaction: transaction,
      );
    });

    session.edit('Detach xref', (transaction) {
      expect(
        const XrefResolver().detach(
          host: host,
          name: 'PART',
          transaction: transaction,
        ),
        isTrue,
      );
    });

    expect(host.blocks.containsKey('PART'), isFalse);
    expect(host.activeEntities.whereType<InsertEntity>(), isEmpty);

    expect(session.undo(), isTrue);
    expect(host.blocks['PART']!.isXref, isTrue);
    expect(host.activeEntities.whereType<InsertEntity>().single.position, const Vec2(3, 4));
  });

  test('binding an xref keeps the insert and drops the file path', () {
    final host = CadDocument();
    final foreign = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final session = DocumentSession(id: 't', document: host);

    session.edit('Attach xref', (transaction) {
      const XrefResolver().attach(
        host: host,
        foreign: foreign,
        path: '/tmp/part.dxf',
        at: const Vec2(3, 4),
        transaction: transaction,
      );
    });

    session.edit('Bind xref', (transaction) {
      expect(
        const XrefResolver().bind(
          host: host,
          name: 'PART',
          transaction: transaction,
        ),
        isTrue,
      );
    });

    expect(host.blocks['PART']!.isXref, isFalse);
    expect(host.blocks['PART']!.xrefPath, isEmpty);
    expect(host.blocks['PART']!.entityIds, hasLength(1));
    expect(
      host.activeEntities.whereType<InsertEntity>().single.position,
      const Vec2(3, 4),
    );

    expect(session.undo(), isTrue);
    expect(host.blocks['PART']!.isXref, isTrue);
    expect(host.blocks['PART']!.xrefPath, '/tmp/part.dxf');
  });
}
