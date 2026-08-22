import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

/// Undo integrity is the property the whole editing model rests on: if a
/// transaction cannot be inverted exactly, every command built on top of it is
/// unsafe. These tests check exactness rather than plausibility.
void main() {
  CadDocument newDocument() => CadDocument()
    ..putLayer(const LayerDef(name: 'WORK'))
    ..currentLayer = 'WORK';

  group('Transaction', () {
    test('applies eagerly so a command can read back its own work', () {
      final document = newDocument();
      final transaction = Transaction(document);
      final id = transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 0)),
      );
      expect(document.entity(id), isNotNull);
      transaction.commit();
    });

    test('rollback restores the document exactly', () {
      final document = newDocument();
      final baseId = document.addEntity(
        CircleEntity(id: 0, center: const Vec2.zero(), radius: 5),
      ).id;
      final before = document.entityCount;

      final transaction = Transaction(document)
        ..add(LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(1, 1)))
        ..erase(baseId);
      expect(document.entityCount, before);
      expect(document.entity(baseId), isNull);

      transaction.rollback();
      expect(document.entityCount, before);
      expect(document.entity(baseId), isNotNull);
    });

    test('refuses edits on a locked layer and reports them', () {
      final document = newDocument()
        ..putLayer(const LayerDef(name: 'LOCKED', locked: true));
      final id = document.addEntity(
        LineEntity(
          id: 0,
          props: const EntityProps(layer: 'LOCKED'),
          start: const Vec2.zero(),
          end: const Vec2(1, 0),
        ),
      ).id;

      final transaction = Transaction(document);
      expect(transaction.erase(id), isFalse);
      expect(transaction.skipped, [id]);
      expect(document.entity(id), isNotNull);
    });

    test('commit returns null when nothing changed', () {
      final document = newDocument();
      expect(Transaction(document).commit(), isNull);
    });
  });

  group('UndoStack', () {
    test('undo and redo restore geometry exactly', () {
      final session = DocumentSession(id: '1', document: newDocument());
      final id = session
          .edit('draw', (t) {
            t.add(
              LineEntity(
                id: 0,
                start: const Vec2.zero(),
                end: const Vec2(10, 0),
              ),
            );
          })!
          .change
          .added
          .single;

      session.edit('move', (t) {
        t.transform(id, Mat3.translation(5, 5));
      });
      var line = session.document.entity(id)! as LineEntity;
      expect(line.start.x, closeTo(5, 1e-12));

      expect(session.undo(), isTrue);
      line = session.document.entity(id)! as LineEntity;
      expect(line.start.x, closeTo(0, 1e-12));
      expect(line.end.x, closeTo(10, 1e-12));

      expect(session.redo(), isTrue);
      line = session.document.entity(id)! as LineEntity;
      expect(line.start.x, closeTo(5, 1e-12));
    });

    test('undo restores an erased entity to its original draw order', () {
      final session = DocumentSession(id: '1', document: newDocument());
      final ids = session
          .edit('draw three', (t) {
            for (var i = 0; i < 3; i++) {
              t.add(
                CircleEntity(id: 0, center: Vec2(i * 10, 0), radius: 4),
              );
            }
          })!
          .change
          .added;

      final block = session.document.currentBlockName;
      final orderBefore = session.document.blocks[block]!.entityIds.toList();

      session.edit('erase middle', (t) => t.erase(ids[1]));
      expect(
        session.document.blocks[block]!.entityIds,
        [ids[0], ids[2]],
      );

      session.undo();
      expect(session.document.blocks[block]!.entityIds, orderBefore);
    });

    test('a new edit clears the redo branch', () {
      final session = DocumentSession(id: '1', document: newDocument());
      session.edit('a', (t) {
        t.add(PointEntity(id: 0, position: const Vec2.zero()));
      });
      session.undo();
      expect(session.history.canRedo, isTrue);
      session.edit('b', (t) {
        t.add(PointEntity(id: 0, position: const Vec2(1, 1)));
      });
      expect(session.history.canRedo, isFalse);
    });

    test('importer changes are not undoable', () {
      final session = DocumentSession(id: '1', document: newDocument());
      session.edit('import', (t) {
        t.add(PointEntity(id: 0, position: const Vec2.zero()));
      }, source: ChangeSource.importer);
      expect(session.history.canUndo, isFalse);
      expect(session.isDirty, isFalse);
    });

    test('repeated undo and redo cycles do not drift', () {
      final session = DocumentSession(id: '1', document: newDocument());
      final id = session
          .edit('arc', (t) {
            t.add(
              ArcEntity(
                id: 0,
                center: const Vec2(3, 4),
                radius: 7,
                startAngle: 0.3,
                endAngle: 2.1,
              ),
            );
          })!
          .change
          .added
          .single;
      session.edit('rotate', (t) {
        t.transform(id, Mat3.rotation(math.pi / 6));
      });
      final rotated = session.document.entity(id)! as ArcEntity;

      for (var i = 0; i < 20; i++) {
        session.undo();
        session.redo();
      }
      final after = session.document.entity(id)! as ArcEntity;
      expect(after.center.x, closeTo(rotated.center.x, 1e-12));
      expect(after.center.y, closeTo(rotated.center.y, 1e-12));
      expect(after.radius, closeTo(rotated.radius, 1e-12));
      expect(after.startAngle, closeTo(rotated.startAngle, 1e-12));
    });

    test('the history is capped', () {
      final session = DocumentSession(
        id: '1',
        document: newDocument(),
        history: UndoStack(limit: 4),
      );
      for (var i = 0; i < 10; i++) {
        session.edit('draw $i', (t) {
          t.add(PointEntity(id: 0, position: Vec2(i.toDouble(), 0)));
        });
      }
      expect(session.history.depth, 4);
    });
  });

  group('DocumentSession', () {
    test('reports what changed so the renderer can update incrementally', () {
      final session = DocumentSession(id: '1', document: newDocument());
      final changes = <DocumentChange>[];
      session.changes.listen(changes.add);

      final id = session
          .edit('draw', (t) {
            t.add(
              LineEntity(
                id: 0,
                start: const Vec2.zero(),
                end: const Vec2(1, 0),
              ),
            );
          })!
          .change
          .added
          .single;
      session.edit('recolour', (t) {
        t.setColorOf([id], const CadColor.indexed(3));
      });

      expect(changes.first.added, [id]);
      expect(changes.last.modified, [id]);
      expect(changes.last.added, isEmpty);
    });

    test('selection drops entities that were erased', () {
      final session = DocumentSession(id: '1', document: newDocument());
      final id = session
          .edit('draw', (t) {
            t.add(PointEntity(id: 0, position: const Vec2.zero()));
          })!
          .change
          .added
          .single;
      session.selection.add(id);
      expect(session.selection.contains(id), isTrue);

      session.edit('erase', (t) => t.erase(id));
      expect(session.selection.contains(id), isFalse);
    });

    test('creating a paper layout is invertible', () {
      final document = newDocument();
      final session = DocumentSession(id: '1', document: document);
      const layout = Layout(
        name: 'Layout1',
        blockName: '*Paper_Space',
        tabOrder: 1,
      );

      session.edit('New Layout', (transaction) {
        transaction
          ..putLayout(layout)
          ..setActiveLayout('Layout1');
      });
      expect(document.activeLayoutName, 'Layout1');
      expect(document.blocks.containsKey('*Paper_Space'), isTrue);

      expect(session.undo(), isTrue);
      expect(document.activeLayoutName, 'Model');
      expect(
        document.layouts.any((item) => item.name == 'Layout1'),
        isFalse,
      );
      expect(document.blocks.containsKey('*Paper_Space'), isFalse);
    });

    test('deleting a paper layout is invertible', () {
      final document = newDocument();
      final session = DocumentSession(id: '1', document: document);
      session.edit('New Layout', (transaction) {
        transaction
          ..putLayout(
            const Layout(
              name: 'Layout1',
              blockName: '*Paper_Space',
              tabOrder: 1,
            ),
          )
          ..setActiveLayout('Layout1')
          ..add(
            const LineEntity(
              id: 0,
              start: Vec2(10, 10),
              end: Vec2(40, 10),
            ),
            blockName: '*Paper_Space',
          );
      });
      expect(document.activeLayoutName, 'Layout1');
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));

      session.edit('Delete Layout', (transaction) {
        for (final entity in document.entitiesOf('*Paper_Space')) {
          transaction.erase(entity.id);
        }
        transaction
          ..setActiveLayout('Model')
          ..removeLayout('Layout1');
      });
      expect(document.activeLayoutName, 'Model');
      expect(document.layouts.any((item) => item.name == 'Layout1'), isFalse);
      expect(document.entitiesOf('*Paper_Space'), isEmpty);

      expect(session.undo(), isTrue);
      expect(document.activeLayoutName, 'Layout1');
      expect(document.layouts.any((item) => item.name == 'Layout1'), isTrue);
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));
    });

    test('adding a paper viewport is invertible', () {
      final document = newDocument()
        ..addLayout(
          const Layout(
            name: 'Layout1',
            blockName: '*Paper_Space',
            tabOrder: 1,
          ),
        );
      const viewport = PaperViewport(
        paperBounds: Bounds2(10, 10, 110, 90),
        modelCenter: Vec2(40, 0),
        scale: 0.5,
      );
      final session = DocumentSession(id: '1', document: document);
      final paper = document.layouts.firstWhere((item) => item.name == 'Layout1');

      expect(
        session.edit('MVIEW', (transaction) {
          transaction.putLayout(paper.copyWith(viewports: [viewport]));
        }),
        isNotNull,
      );
      final added = document.layouts
          .firstWhere((item) => item.name == 'Layout1')
          .viewports
          .single;
      expect(added.paperBounds, viewport.paperBounds);
      expect(added.modelCenter, viewport.modelCenter);
      expect(added.scale, viewport.scale);

      expect(session.undo(), isTrue);
      expect(
        document.layouts.firstWhere((item) => item.name == 'Layout1').viewports,
        isEmpty,
      );
    });

    test('a throwing edit leaves the document untouched', () {
      final session = DocumentSession(id: '1', document: newDocument());
      session.edit('seed', (t) {
        t.add(PointEntity(id: 0, position: const Vec2.zero()));
      });
      final countBefore = session.document.entityCount;

      expect(
        () => session.edit('boom', (t) {
          t.add(PointEntity(id: 0, position: const Vec2(1, 1)));
          throw StateError('command failed halfway');
        }),
        throwsStateError,
      );
      expect(session.document.entityCount, countBefore);
      expect(session.history.depth, 1);
    });
  });
}
