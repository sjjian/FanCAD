import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentSession', () {
    test('title falls back to the file name or a generated drawing name', () {
      final untitled = DocumentSession(id: '3', document: CadDocument());
      expect(untitled.title, 'Drawing3');
      untitled.title = 'Sheet';
      expect(untitled.title, 'Sheet');
      final named = DocumentSession(
        id: '1',
        document: CadDocument(),
        filePath: r'C:\work\plan.dxf',
      );
      expect(named.title, 'plan.dxf');
      expect(untitled.toString(), contains('Sheet'));

      final blank = DocumentSession(
        id: '2',
        document: CadDocument(),
        filePath: '   ',
      );
      expect(blank.title, 'Drawing2');
      final folder = DocumentSession(
        id: '3',
        document: CadDocument(),
        filePath: r'C:\work\',
      );
      expect(folder.title, 'Drawing3');

      final slash = DocumentSession(
        id: '7',
        document: CadDocument(),
        filePath: '/',
      );
      expect(slash.title, 'Drawing7');
      slash.dispose();
    });

    test('an edit marks the session dirty and markSaved clears it', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      expect(session.isDirty, isFalse);
      session.edit('line', (transaction) {
        transaction.add(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 0)),
        );
      });
      expect(session.isDirty, isTrue);
      session.markSaved('/tmp/a.dxf');
      expect(session.filePath, '/tmp/a.dxf');
      expect(session.isDirty, isFalse);
      expect(session.title, 'a.dxf');
    });

    test('erasing a selected entity prunes the selection', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      final id = session
          .edit('add', (transaction) {
            transaction.add(const PointEntity(id: 0, position: Vec2.zero()));
          })!
          .change
          .added
          .single;
      session.selection.add(id);
      session.edit('erase', (transaction) => transaction.erase(id));
      expect(session.selection.contains(id), isFalse);
    });

    test('applyPatches goes through the same undo stack', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      final entity = const PointEntity(id: 11, position: Vec2.zero());
      session.applyPatches('ai add', [
        AddEntityPatch(
          entity: entity,
          blockName: session.document.modelSpaceBlockName,
        ),
      ]);
      expect(session.document.entity(11), isNotNull);
      expect(session.undo(), isTrue);
      expect(session.document.entity(11), isNull);
      expect(session.redo(), isTrue);
      expect(session.document.entity(11), isNotNull);
    });

    test('a throwing edit rolls back and does not mark dirty', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      expect(
        () => session.edit('boom', (transaction) {
          transaction.add(
            const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
          );
          throw StateError('nope');
        }),
        throwsStateError,
      );
      expect(session.document.entityCount, 0);
      expect(session.document.entities, isEmpty);
      expect(session.isDirty, isFalse);
      expect(session.undo(), isFalse);
      session.dispose();
    });

    test('importer edits stay clean and are not undoable', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      final committed = session.edit('import', (transaction) {
        transaction.add(const PointEntity(id: 0, position: Vec2.zero()));
      }, source: ChangeSource.importer);
      expect(committed, isNotNull);
      expect(session.isDirty, isFalse);
      expect(session.document.entityCount, 1);
      expect(session.undo(), isFalse);
      expect(session.redo(), isFalse);
      session.notifyExternalChange(const DocumentChange(tablesChanged: true));
      session.dispose();
    });

    test('an empty stack cannot invent an undo or redo', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      expect(session.undo(), isFalse);
      expect(session.redo(), isFalse);
      expect(session.isDirty, isFalse);
      session.dispose();
    });

    test('an empty edit cannot invent a dirty session', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      final committed = session.edit('noop', (_) {});
      expect(committed, isNull);
      expect(session.isDirty, isFalse);
      expect(session.undo(), isFalse);
      session.dispose();
    });

    test('an empty patch list cannot invent a dirty session', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      expect(session.applyPatches('ai', const []), isNull);
      expect(session.isDirty, isFalse);
      session.dispose();
    });

    test('an empty external change cannot invent a notification', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      final changes = <DocumentChange>[];
      final sub = session.changes.listen(changes.add);

      session.notifyExternalChange(const DocumentChange());
      expect(changes, isEmpty);

      sub.cancel();
      session.dispose();
    });

    test('a disposed session cannot invent leftover change events', () async {
      final session = DocumentSession(id: 't', document: CadDocument());
      final seen = <DocumentChange>[];
      final sub = session.changes.listen(seen.add);
      session.dispose();
      session.notifyExternalChange(const DocumentChange(tablesChanged: true));
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      await sub.cancel();
    });
  });
}
