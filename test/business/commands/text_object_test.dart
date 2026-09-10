import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/workspace.dart';

late Headless app;

CadDocument get document => app.document;

Workspace get workspace => app.workspace;

Future<CommandResult> run(String id, [Map<String, Object?> args = const {}]) =>
    app.run(id, args);

Future<int> addText({
  String content = 'A',
  List<double> at = const [0, 0],
  double height = 2.5,
}) async {
  final created = await run('draw.text', {
    'content': content,
    'at': at,
    'height': height,
  });
  expect(created.status, CommandStatus.ok, reason: created.message);
  return (created.data!['ids']! as List).first as int;
}

void main() {
  setUp(() {
    app = Headless();
  });

  group('edit.textObject', () {
    test('refuses a call with no content, height, colour or justify', () async {
      final id = await addText();

      final result = await run('edit.textObject', {
        'ids': [id],
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(id)! as TextEntity).content, 'A');
    });

    test('refuses a non-text selection', () async {
      final id = await app.drawLine(0, 0, 10, 0);

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 8,
      });

      expect(result.status, CommandStatus.failed);
    });

    test('refuses empty TEXT content', () async {
      final id = await addText(content: 'ROOM');

      final result = await run('edit.textObject', {
        'ids': [id],
        'text': '',
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(id)! as TextEntity).content, 'ROOM');
    });

    test('refuses a non-positive height', () async {
      final id = await addText();

      expect(
        (await run('edit.textObject', {
          'ids': [id],
          'height': 0,
        })).status,
        CommandStatus.failed,
      );
      expect(
        (await run('edit.textObject', {
          'ids': [id],
          'height': -2,
        })).status,
        CommandStatus.failed,
      );
      expect((document.entity(id)! as TextEntity).height, 2.5);
    });

    test('refuses Align, Fit and unknown justifications', () async {
      final id = await addText(content: 'ABC', height: 10);

      for (final justify in ['align', 'fit', 'nope']) {
        final result = await run('edit.textObject', {
          'ids': [id],
          'justify': justify,
        });
        expect(result.status, CommandStatus.failed, reason: justify);
      }
      expect((document.entity(id)! as TextEntity).hAlign, TextHAlign.left);
    });

    test('mtext height stays on the attachment point', () async {
      final created = await run('draw.mtext', {
        'content': 'NOTE',
        'at': [10, 20],
        'height': 2.5,
        'width': 40,
        'justify': 'tr',
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 8,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final text = document.entity(id)! as MTextEntity;
      expect(text.height, 8);
      expect(text.position, const Vec2(10, 20));
      expect(text.attachment, 3);
      expect(text.rectangleWidth, 40);
    });

    test('mtext justify rewrites the attachment', () async {
      final created = await run('draw.mtext', {
        'content': 'Hi',
        'at': [0, 0],
        'height': 10,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.textObject', {
        'ids': [id],
        'justify': 'br',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as MTextEntity).attachment, 9);
    });

    test('attrib height and value change together', () async {
      late final int id;
      workspace.active!.session.edit('seed', (transaction) {
        id = transaction.add(
          const AttribEntity(
            id: 0,
            position: Vec2(1, 1),
            tag: 'TITLE',
            value: 'OLD',
            height: 2.5,
          ),
        );
      });

      final result = await run('edit.textObject', {
        'ids': [id],
        'text': 'NEW',
        'height': 6,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final attrib = document.entity(id)! as AttribEntity;
      expect(attrib.value, 'NEW');
      expect(attrib.height, 6);
      expect(attrib.position, const Vec2(1, 1));
      expect(attrib.tag, 'TITLE');
    });

    test('attdef height keeps the tag and flags', () async {
      final created = await run('draw.attdef', {
        'tag': 'NO',
        'value': 'A-00',
        'at': [2, 3],
        'height': 2.5,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 8,
        'justify': 'right',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final def = document.entity(id)! as AttdefEntity;
      expect(def.tag, 'NO');
      expect(def.defaultValue, 'A-00');
      expect(def.height, 8);
      expect(def.hAlign, TextHAlign.right);
    });

    test('mleader height and attachment change without moving vertices', () async {
      late final int id;
      workspace.active!.session.edit('seed', (transaction) {
        id = transaction.add(
          MLeaderEntity(
            id: 0,
            vertices: Float64List.fromList([0, 0, 10, 0]),
            content: 'NOTE',
            textPosition: const Vec2(10, 1),
            textHeight: 2.5,
            attachment: 4,
          ),
        );
      });

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 5,
        'justify': 'tr',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final leader = document.entity(id)! as MLeaderEntity;
      expect(leader.textHeight, 5);
      expect(leader.attachment, 3);
      expect(leader.vertices.toList(), [0.0, 0.0, 10.0, 0.0]);
    });

    test('a dimension accepts colour and override, not height', () async {
      final created = await run('draw.dimLinear', {
        'first': [0, 0],
        'second': [6, 0],
        'dimLine': [3, 2],
      });
      final id = (created.data!['ids']! as List).first as int;

      expect(
        (await run('edit.textObject', {
          'ids': [id],
          'height': 12,
        })).status,
        CommandStatus.failed,
      );

      final result = await run('edit.textObject', {
        'ids': [id],
        'text': '<> mm',
        'color': 3,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final dim = document.entity(id)! as DimensionEntity;
      expect(dim.displayText, '6.00 mm');
      expect(dim.props.color, const CadColor.indexed(3));
    });

    test('a no-op height does not dirty the drawing', () async {
      final id = await addText(height: 2.5);
      final undoLabel = workspace.active!.history.nextUndoLabel;

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 2.5,
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(id)! as TextEntity).height, 2.5);
      expect(
        workspace.active!.history.nextUndoLabel,
        undoLabel,
        reason: 'no-op height must not push another undo',
      );
    });

    test('height, colour and justify undo as one step', () async {
      final id = await addText(content: 'ABC', at: [0, 0], height: 10);

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 5,
        'color': 1,
        'justify': 'right',
      });
      expect(result.status, CommandStatus.ok, reason: result.message);

      var text = document.entity(id)! as TextEntity;
      expect(text.height, 5);
      expect(text.hAlign, TextHAlign.right);
      expect(text.props.color, const CadColor.indexed(1));

      await run('edit.undo');
      text = document.entity(id)! as TextEntity;
      expect(text.height, 10);
      expect(text.hAlign, TextHAlign.left);
      expect(text.position, const Vec2.zero());
      expect(text.props.color, const CadColor.byLayer());
    });

    test('cancels when nothing is selected', () async {
      final result = await run('edit.textObject', {'height': 8});
      expect(result.status, CommandStatus.cancelled);
    });

    test('skips a line in a mixed selection', () async {
      final lineId = await app.drawLine(0, 0, 10, 0);
      final textId = await addText(height: 2.5);

      final result = await run('edit.textObject', {
        'ids': [lineId, textId],
        'height': 8,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(textId)! as TextEntity).height, 8);
      expect(
        (document.entity(lineId)! as LineEntity).end,
        const Vec2(10, 0),
      );
    });

    test('refuses empty MTEXT and mleader notes', () async {
      final mtext = await run('draw.mtext', {
        'content': 'NOTE',
        'at': [0, 0],
      });
      final mtextId = (mtext.data!['ids']! as List).first as int;
      late final int leaderId;
      workspace.active!.session.edit('seed', (transaction) {
        leaderId = transaction.add(
          MLeaderEntity(
            id: 0,
            vertices: Float64List.fromList([0, 0, 10, 0]),
            content: 'NOTE',
          ),
        );
      });

      expect(
        (await run('edit.textObject', {
          'ids': [mtextId],
          'text': '',
        })).status,
        CommandStatus.failed,
      );
      expect(
        (await run('edit.textObject', {
          'ids': [leaderId],
          'text': '',
        })).status,
        CommandStatus.failed,
      );
      expect((document.entity(mtextId)! as MTextEntity).content, 'NOTE');
      expect((document.entity(leaderId)! as MLeaderEntity).content, 'NOTE');
    });

    test('an attribute may be cleared', () async {
      late final int id;
      workspace.active!.session.edit('seed', (transaction) {
        id = transaction.add(
          const AttribEntity(
            id: 0,
            position: Vec2.zero(),
            tag: 'TITLE',
            value: 'OLD',
          ),
        );
      });

      final result = await run('edit.textObject', {
        'ids': [id],
        'text': '',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(id)! as AttribEntity).value, isEmpty);
    });

    test('empty content fails the whole set when any target requires it', () async {
      final textId = await addText(content: 'ROOM');
      late final int attribId;
      workspace.active!.session.edit('seed', (transaction) {
        attribId = transaction.add(
          const AttribEntity(
            id: 0,
            position: Vec2.zero(),
            tag: 'TITLE',
            value: 'OLD',
          ),
        );
      });

      final result = await run('edit.textObject', {
        'ids': [textId, attribId],
        'text': '',
      });

      expect(result.status, CommandStatus.failed);
      expect((document.entity(textId)! as TextEntity).content, 'ROOM');
      expect((document.entity(attribId)! as AttribEntity).value, 'OLD');
    });

    test('colour alone recolors without moving the insertion', () async {
      final id = await addText(at: [4, 2], height: 2.5);

      final result = await run('edit.textObject', {
        'ids': [id],
        'color': 3,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final text = document.entity(id)! as TextEntity;
      expect(text.props.color, const CadColor.indexed(3));
      expect(text.position, const Vec2(4, 2));
      expect(text.height, 2.5);
    });

    test('the current justification is a no-op', () async {
      final id = await addText();
      final undoLabel = workspace.active!.history.nextUndoLabel;

      final result = await run('edit.textObject', {
        'ids': [id],
        'justify': 'left',
      });

      expect(result.status, CommandStatus.failed);
      expect(workspace.active!.history.nextUndoLabel, undoLabel);
    });

    test('two objects share one undo', () async {
      final first = await addText(content: 'A', at: [0, 0], height: 2.5);
      final second = await addText(content: 'B', at: [10, 0], height: 2.5);

      final result = await run('edit.textObject', {
        'ids': [first, second],
        'height': 8,
        'color': 2,
      });
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect((document.entity(first)! as TextEntity).height, 8);
      expect((document.entity(second)! as TextEntity).height, 8);

      await run('edit.undo');
      expect((document.entity(first)! as TextEntity).height, 2.5);
      expect((document.entity(second)! as TextEntity).height, 2.5);
      expect(document.entity(first), isNotNull);
      expect(document.entity(second), isNotNull);
    });

    test('height keeps rotation and style on TEXT', () async {
      final created = await run('draw.text', {
        'content': 'A',
        'at': [1, 2],
        'height': 2.5,
        'rotation': 90,
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('edit.textObject', {
        'ids': [id],
        'height': 10,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final text = document.entity(id)! as TextEntity;
      expect(text.height, 10);
      expect(text.position, const Vec2(1, 2));
      expect(text.rotation, closeTo(math.pi / 2, 1e-9));
      expect(text.styleName, 'Standard');
    });
  });
}
