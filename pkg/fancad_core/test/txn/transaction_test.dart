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
      final baseId = document
          .addEntity(CircleEntity(id: 0, center: const Vec2.zero(), radius: 5))
          .id;
      final before = document.entityCount;

      final transaction = Transaction(document)
        ..add(
          LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(1, 1)),
        )
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
      final id = document
          .addEntity(
            LineEntity(
              id: 0,
              props: const EntityProps(layer: 'LOCKED'),
              start: const Vec2.zero(),
              end: const Vec2(1, 0),
            ),
          )
          .id;

      final transaction = Transaction(document);
      expect(transaction.erase(id), isFalse);
      expect(transaction.transform(id, const Mat3.translation(1, 0)), isFalse);
      expect(transaction.isEmpty, isTrue);
      expect(transaction.skipped, [id, id]);
      expect(document.entity(id), isNotNull);
    });

    test('commit returns null when nothing changed', () {
      final document = newDocument();
      final transaction = Transaction(document, label: 'noop');
      expect(transaction.commit(), isNull);
      expect(transaction.isCommitted, isTrue);
    });

    test('rolling back an empty transaction cannot invent a change', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'noop');
      expect(transaction.rollback().isEmpty, isTrue);
      expect(transaction.isCommitted, isTrue);
      expect(document.isEmpty, isTrue);
    });

    test('a missing or identical entity cannot invent a mutation', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      const missing = LineEntity(id: 99, start: Vec2.zero(), end: Vec2(10, 0));

      expect(transaction.erase(99), isFalse);
      expect(transaction.modify(missing), isFalse);
      expect(transaction.eraseAll([99, 100]), 0);
      expect(transaction.isEmpty, isTrue);

      final id = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final current = document.entity(id)!;
      expect(transaction.modify(current), isFalse);
      expect(transaction.transform(id, const Mat3.identity()), isFalse);
    });

    test('a layer still in use cannot invent a drop', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      transaction.putLayer(const LayerDef(name: 'WALLS'));
      transaction.add(
        const LineEntity(
          id: 0,
          props: EntityProps(layer: 'WALLS'),
          start: Vec2.zero(),
          end: Vec2(4, 0),
        ),
      );
      expect(transaction.removeLayer('WALLS'), isFalse);
    });

    test('layer 0 or a missing name cannot invent a drop', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      expect(transaction.removeLayer('0'), isFalse);
      expect(transaction.removeLayer('NOPE'), isFalse);
      expect(transaction.isEmpty, isTrue);
    });

    test('model space or a missing tab cannot invent a drop', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      expect(transaction.removeLayout('NOPE'), isFalse);
      expect(transaction.removeLayout('Model'), isFalse);
      expect(transaction.isEmpty, isTrue);
    });

    test('a missing or layout block cannot invent a drop', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      expect(transaction.removeBlock('NOPE'), isFalse);
      expect(transaction.removeBlock('*Model_Space'), isFalse);
      expect(transaction.isEmpty, isTrue);
    });

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

    test('setting the current layer to itself cannot invent a patch', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      transaction.setCurrentLayer('0');
      expect(transaction.isEmpty, isTrue);
      transaction.setCurrentDimStyle('Standard');
      expect(transaction.isEmpty, isTrue);
    });

    test('a missing id cannot invent a color or linetype edit', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      expect(transaction.setColorOf([99], const CadColor.indexed(3)), 0);
      expect(transaction.setLineTypeOf([99], 'DASHED'), 0);
      expect(transaction.setLineWeightOf([99], 25), 0);
      expect(transaction.isEmpty, isTrue);
    });

    test('identical props cannot invent a property edit', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      final id = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
      final current = document.entity(id)!;
      expect(transaction.setProps(id, current.props), isFalse);
      expect(transaction.setLayerOf([99], 'WALLS'), 0);
      expect(transaction.setVisibleOf([99], false), 0);
    });

    test('an out-of-range grip cannot invent a mutation', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      final id = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
      expect(transaction.moveGrip(id, 99, const Vec2(1, 1)), isFalse);
      expect(transaction.moveGrip(99, 0, const Vec2(1, 1)), isFalse);
    });

    test('duplicating a missing id cannot invent a copy', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      expect(transaction.duplicate([99], Mat3.translation(10, 0)), isEmpty);
      expect(transaction.isEmpty, isTrue);
    });

    test('an identity transform cannot invent leftover moves', () {
      final document = CadDocument();
      final transaction = Transaction(document);
      final id = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
      expect(transaction.transformAll([id, 99], const Mat3.identity()), 0);
      expect(transaction.transform(99, Mat3.translation(1, 0)), isFalse);
    });
  });

  group('CommittedTransaction', () {
    test('an empty transaction summary stays the label', () {
      final committed = CommittedTransaction(
        label: 'Edit',
        source: ChangeSource.user,
        forward: const [],
        inverse: const [],
        change: const DocumentChange(),
        timestamp: DateTime.utc(2026, 1, 1),
      );
      expect(committed.summarize(), 'Edit');
      expect(committed.patchCount, 0);
    });

    test('repeated patches collapse and mixed patches keep the label', () {
      const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
      final add = AddEntityPatch(entity: line, blockName: '*Model_Space');
      final one = CommittedTransaction(
        label: 'Draw',
        source: ChangeSource.command,
        forward: [add],
        inverse: const [],
        change: const DocumentChange(added: [1]),
        timestamp: DateTime.utc(2026, 1, 1),
      );
      expect(one.summarize(), add.describe());

      final two = CommittedTransaction(
        label: 'Draw',
        source: ChangeSource.command,
        forward: [add, add],
        inverse: const [],
        change: const DocumentChange(added: [1, 2]),
        timestamp: DateTime.utc(2026, 1, 1),
      );
      expect(two.summarize(), '${add.describe()} x2');

      final mixed = CommittedTransaction(
        label: 'Edit',
        source: ChangeSource.user,
        forward: [
          add,
          RemoveEntityPatch(entity: line, blockName: '*Model_Space'),
        ],
        inverse: const [],
        change: const DocumentChange(),
        timestamp: DateTime.utc(2026, 1, 1),
      );
      expect(mixed.summarize(), 'Edit (2 changes)');
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
              t.add(CircleEntity(id: 0, center: Vec2(i * 10, 0), radius: 4));
            }
          })!
          .change
          .added;

      final block = session.document.currentBlockName;
      final orderBefore = session.document.blocks[block]!.entityIds.toList();

      session.edit('erase middle', (t) => t.erase(ids[1]));
      expect(session.document.blocks[block]!.entityIds, [ids[0], ids[2]]);

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
      expect(session.undo(), isFalse);
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

    test('an empty stack cannot invent undo or redo labels', () {
      final stack = UndoStack();
      expect(stack.nextUndoLabel, isNull);
      expect(stack.nextRedoLabel, isNull);
      expect(stack.undo(CadDocument()), isNull);
      expect(stack.redo(CadDocument()), isNull);
      expect(stack.depth, 0);
    });

    test('a short undo run cannot invent a coalesced turn', () {
      final stack = UndoStack();
      stack.coalesceLast(2);
      expect(stack.depth, 0);
      stack.coalesceLast(1);
      expect(stack.depth, 0);
    });

    test('a tiny undo limit cannot invent leftover history', () {
      final stack = UndoStack(limit: 1);
      final document = CadDocument();
      final first = Transaction(document, label: 'a')
        ..add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 0)));
      stack.push(first.commit()!);
      final second = Transaction(document, label: 'b')
        ..add(const LineEntity(id: 0, start: Vec2(2, 0), end: Vec2(3, 0)));
      stack.push(second.commit()!);
      expect(stack.depth, 1);
      expect(stack.nextUndoLabel, contains('line'));
    });

    test('clearing the stack cannot invent leftover undo', () {
      final session = DocumentSession(id: 't', document: CadDocument());
      session.edit('draw', (transaction) {
        transaction.add(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
        );
      });
      expect(session.history.canUndo, isTrue);
      session.history.clear();
      expect(session.history.canUndo, isFalse);
      expect(session.history.canRedo, isFalse);
      expect(session.undo(), isFalse);
      session.dispose();
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
      expect(document.layouts.any((item) => item.name == 'Layout1'), isFalse);
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
            const LineEntity(id: 0, start: Vec2(10, 10), end: Vec2(40, 10)),
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
          const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
        );
      const viewport = PaperViewport(
        paperBounds: Bounds2(10, 10, 110, 90),
        modelCenter: Vec2(40, 0),
        scale: 0.5,
      );
      final session = DocumentSession(id: '1', document: document);
      final paper = document.layouts.firstWhere(
        (item) => item.name == 'Layout1',
      );

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

  group('associated dimensions', () {
    test('transforming a source regenerates the associated dimension', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final lineId = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final dimId = transaction.add(
        Construct.linearDimension(
          const Vec2.zero(),
          const Vec2(10, 0),
          const Vec2(5, 3),
          sourceIds: [lineId],
        )!,
      );
      transaction.commit();

      final moved = Transaction(document, label: 'Move');
      expect(moved.transform(lineId, const Mat3.translation(0, 4)), isTrue);
      moved.commit();

      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.definitionPoints[0], const Vec2(0, 4));
      expect(dim.definitionPoints[1], const Vec2(10, 4));
      expect(dim.definitionPoints[2].y, closeTo(7, 1e-9));
    });

    test('stretching a source updates the measurement', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final lineId = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final dimId = transaction.add(
        Construct.linearDimension(
          const Vec2.zero(),
          const Vec2(10, 0),
          const Vec2(5, 3),
          sourceIds: [lineId],
        )!,
      );
      transaction.commit();

      final stretch = Transaction(document, label: 'Stretch');
      stretch.modify(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(16, 0))
            .withId(lineId),
      );
      stretch.commit();

      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(16, 1e-9));
      expect(dim.sourceIds, [lineId]);
    });

    test('a grip on the source regenerates the associated dimension', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final lineId = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final dimId = transaction.add(
        Construct.linearDimension(
          const Vec2.zero(),
          const Vec2(10, 0),
          const Vec2(5, 3),
          sourceIds: [lineId],
        )!,
      );
      transaction.commit();

      final grip = Transaction(document, label: 'Grip');
      expect(grip.moveGrip(lineId, 2, const Vec2(16, 0)), isTrue);
      grip.commit();

      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(16, 1e-9));
      expect(dim.sourceIds, [lineId]);
    });

    test('moving only the dimension keeps origins on the source', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final lineId = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final dimId = transaction.add(
        Construct.linearDimension(
          const Vec2.zero(),
          const Vec2(10, 0),
          const Vec2(5, 3),
          sourceIds: [lineId],
        )!,
      );
      transaction.commit();

      final moved = Transaction(document, label: 'Move dim');
      expect(moved.transform(dimId, const Mat3.translation(0, 4)), isTrue);
      moved.commit();

      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.definitionPoints[0], const Vec2.zero());
      expect(dim.definitionPoints[1], const Vec2(10, 0));
      expect(dim.definitionPoints[2].y, closeTo(7, 1e-9));
    });

    test('erasing the source keeps the last measurement', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final lineId = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final dimId = transaction.add(
        Construct.linearDimension(
          const Vec2.zero(),
          const Vec2(10, 0),
          const Vec2(5, 3),
          sourceIds: [lineId],
        )!,
      );
      transaction.commit();

      final erase = Transaction(document, label: 'Erase');
      expect(erase.erase(lineId), isTrue);
      erase.commit();

      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.sourceIds, isEmpty);
    });

    test('copying a source and its dimension remaps the association', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final lineId = transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final dimId = transaction.add(
        Construct.linearDimension(
          const Vec2.zero(),
          const Vec2(10, 0),
          const Vec2(5, 3),
          sourceIds: [lineId],
        )!,
      );
      transaction.commit();

      final copy = Transaction(document, label: 'Copy');
      final created = copy.duplicate([lineId, dimId], const Mat3.translation(0, 5));
      copy.commit();

      expect(created, hasLength(2));
      final copiedDim = document.entity(created[1])! as DimensionEntity;
      expect(copiedDim.sourceIds, [created[0]]);
      expect(copiedDim.measurement, closeTo(10, 1e-9));

      final original = document.entity(dimId)! as DimensionEntity;
      expect(original.sourceIds, [lineId]);
    });

    test('transforming a radius source updates the measurement', () {
      final document = CadDocument();
      final transaction = Transaction(document, label: 'draw');
      final circleId = transaction.add(
        const CircleEntity(id: 0, center: Vec2.zero(), radius: 5),
      );
      final dimId = transaction.add(
        Construct.radiusDimension(
          document.entity(circleId)!,
          const Vec2(8, 0),
        )!,
      );
      transaction.commit();

      final scaled = Transaction(document, label: 'Scale');
      expect(scaled.transform(circleId, const Mat3.scaling(2, 2)), isTrue);
      scaled.commit();

      final dim = document.entity(dimId)! as DimensionEntity;
      expect(dim.measurement, closeTo(10, 1e-9));
      expect(dim.sourceIds, [circleId]);
    });
  });
}
