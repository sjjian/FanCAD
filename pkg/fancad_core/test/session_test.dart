import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('SelectionSet', () {
    test('add, toggle and replace keep a single current set', () {
      final selection = SelectionSet();
      expect(selection.isEmpty, isTrue);
      expect(selection.add(1), isTrue);
      expect(selection.add(1), isFalse);
      expect(selection.addAll([1, 2, 3]), 2);
      expect(selection.ids, {1, 2, 3});
      expect(selection.isSingle, isFalse);
      expect(selection.contains(2), isTrue);
      expect(selection.toggle(2), isFalse);
      expect(selection.contains(2), isFalse);
      expect(selection.toggle(2), isTrue);
      selection.replace([4]);
      expect(selection.single, 4);
      expect(selection.length, 1);
      selection.replace([4]);
      expect(selection.ids, {4});
    });

    test('viewport selection clears entity ids and grips', () {
      final selection = SelectionSet()
        ..add(9)
        ..activeGrips[9] = 0;
      selection.selectViewports([0, 2]);
      expect(selection.ids, isEmpty);
      expect(selection.viewportIndices, {0, 2});
      expect(selection.activeGrips, isEmpty);
      selection.selectViewports([0, 2]);
      expect(selection.add(1), isTrue);
      expect(selection.viewportIndices, isEmpty);
      expect(selection.toString(), 'SelectionSet(1)');
    });

    test('remove, prune and clear drop ids that no longer exist', () {
      final selection = SelectionSet()..addAll([1, 2, 3]);
      expect(selection.remove(2), isTrue);
      expect(selection.remove(2), isFalse);
      expect(selection.removeAll([1, 9]), 1);
      selection.prune((id) => id == 3);
      expect(selection.ids, {3});
      selection.selectViewports([0, 5]);
      selection.pruneViewports(2);
      expect(selection.viewportIndices, {0});
      selection.clear();
      expect(selection.isEmpty, isTrue);
      selection.dispose();
    });

    test('changes fire once per mutation', () {
      final selection = SelectionSet();
      final sizes = <int>[];
      final sub = selection.changes.listen((ids) => sizes.add(ids.length));
      selection.add(1);
      selection.addAll([2]);
      selection.clear();
      expect(sizes, [1, 2, 0]);
      sub.cancel();
    });
  });

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
            transaction.add(
              const PointEntity(id: 0, position: Vec2.zero()),
            );
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
        () => session.edit('boom', (_) => throw StateError('nope')),
        throwsStateError,
      );
      expect(session.document.entityCount, 0);
      expect(session.isDirty, isFalse);
    });

    test('importer edits stay clean and are not undoable', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      session.edit(
        'import',
        (transaction) {
          transaction.add(
            const PointEntity(id: 0, position: Vec2.zero()),
          );
        },
        source: ChangeSource.importer,
      );
      expect(session.isDirty, isFalse);
      expect(session.document.entityCount, 1);
      expect(session.undo(), isFalse);
      expect(session.redo(), isFalse);
      session.notifyExternalChange(const DocumentChange(tablesChanged: true));
      session.dispose();
    });
  });
}
