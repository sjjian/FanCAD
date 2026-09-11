import 'package:fancad/business/commands/clipboard/capture.dart';
import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

late Headless app;

CadDocument get document => app.document;

Workspace get workspace => app.workspace;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    app.run(id, args);

Future<int> drawLine(double x1, double y1, double x2, double y2) =>
    app.drawLine(x1, y1, x2, y2);

void main() {
  setUp(() {
    app = Headless();
  });

  test(
    'COPYCLIP then PASTECLIP in another tab places relative to the base',
    () async {
      final id = await drawLine(0, 0, 10, 0);
      final copied = await run('edit.copyClip', {
        'ids': [id],
      });
      expect(copied.status, CommandStatus.ok, reason: copied.message);
      expect(workspace.clipboard.isEmpty, isFalse);

      workspace.newDocument();
      expect(document.entityCount, 0);

      final pasted = await run('edit.pasteClip', {
        'to': [4, 5],
      });
      expect(pasted.status, CommandStatus.ok, reason: pasted.message);
      final line = document.entities.whereType<LineEntity>().single;
      // COPYCLIP base is the lower-left of the line, (0, 0).
      expect(line.start, const Vec2(4, 5));
      expect(line.end, const Vec2(14, 5));
    },
  );

  test(
    'CUTCLIP removes the source and still pastes in another drawing',
    () async {
      final id = await drawLine(0, 0, 6, 0);
      final cut = await run('edit.cutClip', {
        'ids': [id],
      });
      expect(cut.status, CommandStatus.ok, reason: cut.message);
      expect(document.entity(id), isNull);

      workspace.newDocument();
      final pasted = await run('edit.pasteClip', {
        'to': [0, 0],
      });
      expect(pasted.status, CommandStatus.ok, reason: pasted.message);
      expect(document.entities.whereType<LineEntity>(), hasLength(1));
    },
  );

  test('COPYBASE uses the specified base, not the extents corner', () async {
    final id = await drawLine(10, 0, 20, 0);
    await run('edit.copyBase', {
      'from': [10, 0],
      'ids': [id],
    });

    workspace.newDocument();
    await run('edit.pasteClip', {
      'to': [0, 5],
    });
    final line = document.entities.whereType<LineEntity>().single;
    expect(line.start, const Vec2(0, 5));
    expect(line.end, const Vec2(10, 5));
  });

  test('PASTEORIG keeps the source coordinates', () async {
    final id = await drawLine(8, 2, 12, 2);
    await run('edit.copyClip', {
      'ids': [id],
    });

    workspace.newDocument();
    final pasted = await run('edit.pasteOrig');
    expect(pasted.status, CommandStatus.ok, reason: pasted.message);
    final line = document.entities.whereType<LineEntity>().single;
    expect(line.start, const Vec2(8, 2));
    expect(line.end, const Vec2(12, 2));
  });

  test('an empty clipboard cancels PASTECLIP', () async {
    final result = await run('edit.pasteClip', {
      'to': [0, 0],
    });
    expect(result.status, CommandStatus.cancelled);
    expect(result.message.toLowerCase(), contains('empty'));
  });

  test(
    'COPYCLIP of a font-coded dimension keeps the *D note after paste',
    () async {
      const raw = r'{\F宋体|c134;型材1}';
      const rotation = 1.5707963267948966;
      late final int dimId;
      workspace.active!.session.edit('seed', (Transaction transaction) {
        transaction.putBlock(
          const BlockRecord(name: '*D1', isAnonymous: true, entityIds: []),
        );
        transaction.add(
          const MTextEntity(
            id: 0,
            position: Vec2(5, 3),
            content: raw,
            height: 40,
            rotation: rotation,
            attachment: 5,
          ),
          blockName: '*D1',
        );
        dimId = transaction.add(
          const DimensionEntity(
            id: 0,
            blockName: '*D1',
            measurement: 10,
            overrideText: raw,
            definitionPoints: [Vec2.zero(), Vec2(0, -10)],
            textPosition: Vec2(5, 3),
            dimensionType: 161,
          ),
        );
      });

      final copied = await run('edit.copyBase', {
        'from': [0, 0],
        'ids': [dimId],
      });
      expect(copied.status, CommandStatus.ok, reason: copied.message);

      workspace.newDocument();
      final pasted = await run('edit.pasteClip', {
        'to': [100, 40],
      });
      expect(pasted.status, CommandStatus.ok, reason: pasted.message);

      final dim = document.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, isNotEmpty);
      expect(dim.textPosition, const Vec2(105, 43));
      final note = document
          .entitiesOf(dim.blockName)
          .whereType<MTextEntity>()
          .single;
      expect(note.position, const Vec2(105, 43));
      expect(note.height, 40);
      expect(note.rotation, closeTo(rotation, 1e-12));

      final sink = PolylineSink();
      dim.emit(document.emitContext(tolerance: 0.1), sink);
      expect(sink.texts, isNotEmpty);
      expect(sink.texts.every((item) => item.height == 40), isTrue);
      expect(
        sink.texts.every((item) => (item.rotation - rotation).abs() < 1e-9),
        isTrue,
      );
      expect(sink.texts.map((item) => item.text).join(), contains('型材1'));
      expect(sink.texts.every((item) => !item.text.contains(r'\F')), isTrue);
    },
  );

  test('PASTEBLOCK creates one insert at the insertion point', () async {
    final first = await drawLine(0, 0, 10, 0);
    final second = await drawLine(0, 0, 0, 4);
    await run('edit.copyClip', {
      'ids': [first, second],
    });

    workspace.newDocument();
    final pasted = await run('edit.pasteBlock', {
      'to': [1, 1],
    });
    expect(pasted.status, CommandStatus.ok, reason: pasted.message);
    expect(document.activeEntities.whereType<InsertEntity>(), hasLength(1));
    expect(document.activeEntities.whereType<LineEntity>(), isEmpty);
    final insert = document.activeEntities.whereType<InsertEntity>().single;
    expect(insert.position, const Vec2(1, 1));
  });

  test('a large clip still ghosts as outlines, not a crossing box', () async {
    final ids = <int>[];
    workspace.active!.session.edit('seed', (transaction) {
      for (var i = 0; i < 220; i++) {
        ids.add(
          transaction.add(
            LineEntity(
              id: 0,
              start: Vec2(i.toDouble(), 0),
              end: Vec2(i.toDouble(), 1),
            ),
          ),
        );
      }
    });
    final copied = await run('edit.copyClip', {'ids': ids});
    expect(copied.status, CommandStatus.ok, reason: copied.message);
    final clip = workspace.clipboard.clip!;
    expect(clip.entities, hasLength(220));

    final ghost = pastePreviewShapes(clip);
    expect(ghost.whereType<OverlayRect>(), isEmpty);
    expect(ghost.whereType<OverlayPolyline>(), isNotEmpty);
  });

  test('a clip insert ghosts the block contents, not the destination', () {
    final source = CadDocument();
    final build = Transaction(source, label: 'build');
    build.putBlock(const BlockRecord(name: 'MARK', entityIds: []));
    build.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(8, 0)),
      blockName: 'MARK',
    );
    final insertId = build.add(
      const InsertEntity(id: 0, blockName: 'MARK', position: Vec2(3, 1)),
    );
    build.commit();
    final clip = DrawingClip.extract(source, [
      insertId,
    ], basePoint: const Vec2(3, 1))!;

    final ghost = pastePreviewShapes(clip);
    expect(ghost, isNotEmpty);
    expect(ghost.whereType<OverlayRect>(), isEmpty);
    final points = ghost.whereType<OverlayPolyline>().expand(
      (shape) => shape.points,
    );
    expect(points, contains(const Vec2(3, 1)));
    expect(points, contains(const Vec2(11, 1)));
  });
}
