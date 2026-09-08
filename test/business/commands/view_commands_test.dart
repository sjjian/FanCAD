import 'dart:ui';

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

  group('units', () {
    test('UNITS writes \$INSUNITS as a first-class drawing unit', () async {
      expect(document.insUnits, InsUnits.unitless);
      final result = await run('view.units', {'units': 'mm'});
      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.insUnits, InsUnits.millimeters);
      expect(document.headerVariables[r'$INSUNITS'], '4');
    });
  });

  group('layers', () {
    test(
      'purge deletes unused layers and keeps ones that are occupied',
      () async {
        await run('layer.new', {'name': 'UNUSED'});
        await run('layer.new', {'name': 'USED'});
        await drawLine(0, 0, 1, 0);

        final result = await run('layer.purge');

        expect(result.status, CommandStatus.ok, reason: result.message);
        expect(document.layer('UNUSED'), isNull);
        expect(document.layer('USED'), isNotNull);
        expect(document.layer('0'), isNotNull);
        expect(document.currentLayer, 'USED');
      },
    );

    test('new layer becomes current and is undoable', () async {
      final result = await run('layer.new', {'name': 'DIMS', 'color': '1'});

      expect(result.status, CommandStatus.ok);
      expect(document.currentLayer, 'DIMS');

      await run('edit.undo');
      expect(document.layer('DIMS'), isNull);
      expect(document.currentLayer, '0');
    });

    test('toggling visibility flips the layer state', () async {
      await run('layer.new', {'name': 'GRID'});

      await run('layer.toggleVisible', {'name': 'GRID'});
      expect(document.layer('GRID')!.visible, isFalse);

      await run('layer.toggleVisible', {'name': 'GRID'});
      expect(document.layer('GRID')!.visible, isTrue);
    });

    test('isolate turns off every other layer', () async {
      await run('layer.new', {'name': 'A'});
      await run('layer.new', {'name': 'B'});

      await run('layer.isolate', {'name': 'A'});

      expect(document.layer('A')!.visible, isTrue);
      expect(document.layer('B')!.visible, isFalse);
      expect(document.layer('0')!.visible, isFalse);
    });

    test('isolate hides every object except the selection', () async {
      final keep = await drawLine(0, 0, 10, 0);
      final other = await drawLine(0, 5, 10, 5);

      final result = await run('view.isolateObjects', {
        'ids': [keep],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entity(keep)!.props.visible, isTrue);
      expect(document.entity(other)!.props.visible, isFalse);

      await run('view.unisolateObjects');
      expect(document.entity(other)!.props.visible, isTrue);
    });

    test('hide turns off the selection and unisolate restores it', () async {
      final id = await drawLine(0, 0, 1, 0);

      await run('view.hideObjects', {
        'ids': [id],
      });
      expect(document.entity(id)!.props.visible, isFalse);

      await run('view.unisolateObjects');
      expect(document.entity(id)!.props.visible, isTrue);
    });

    test('layer 0 cannot be deleted', () async {
      final result = await run('layer.delete', {'name': '0'});
      expect(result.status, CommandStatus.failed);
    });

    test(
      'deleting a populated layer is declined without an approver',
      () async {
        await run('layer.new', {'name': 'JUNK'});
        await drawLine(0, 0, 1, 0);

        // Nothing is listening for approvals, so the destructive path must
        // refuse rather than proceed or hang.
        final result = await run('layer.delete', {'name': 'JUNK'});

        expect(result.status, CommandStatus.cancelled);
        expect(document.layer('JUNK'), isNotNull);
        expect(document.entityCount, 1);
      },
    );

    test('deleting a populated layer proceeds once approved', () async {
      await run('layer.new', {'name': 'JUNK'});
      await drawLine(0, 0, 1, 0);
      final subscription = workspace.approvals.listen(
        (request) => request.approve(),
      );
      addTearDown(subscription.cancel);

      final result = await run('layer.delete', {'name': 'JUNK'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.layer('JUNK'), isNull);
      expect(document.entityCount, 0);
      expect(document.currentLayer, '0');
    });

    test('deleting the current layer makes layer 0 current', () async {
      await run('layer.new', {'name': 'TEMP'});
      expect(document.currentLayer, 'TEMP');

      final result = await run('layer.delete', {'name': 'TEMP'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.layer('TEMP'), isNull);
      expect(document.currentLayer, '0');
    });
  });

  group('selection', () {
    test('select all picks up every entity', () async {
      await drawLine(0, 0, 10, 0);
      await drawLine(0, 5, 10, 5);

      await run('select.all');

      expect(workspace.active!.selection.length, 2);
    });

    test('select by layer filters correctly', () async {
      await drawLine(0, 0, 1, 0);
      await run('layer.new', {'name': 'OTHER'});
      await drawLine(0, 1, 1, 1);

      await run('select.byLayer', {'layer': 'OTHER'});

      expect(workspace.active!.selection.length, 1);
    });

    test('select by colour matches the stored colour only', () async {
      await drawLine(0, 0, 1, 0);
      final painted = await drawLine(0, 1, 1, 1);
      await run('edit.changeColor', {
        'ids': [painted],
        'color': '1',
      });

      final result = await run('select.byColor', {'color': '1'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [painted]);
    });

    test('select by linetype matches the stored linetype only', () async {
      await drawLine(0, 0, 1, 0);
      final dashed = await drawLine(0, 1, 1, 1);
      await run('edit.changeLinetype', {
        'ids': [dashed],
        'linetype': 'DASHED',
      });

      final result = await run('select.byLinetype', {'linetype': 'dashed'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [dashed]);
    });

    test('select by lineweight matches the stored weight only', () async {
      await drawLine(0, 0, 1, 0);
      final thick = await drawLine(0, 1, 1, 1);
      await run('edit.changeLineweight', {
        'ids': [thick],
        'weight': '0.25',
      });

      final result = await run('select.byLineweight', {'weight': '25'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [thick]);
    });

    test('select by type keeps only that kind of object', () async {
      await drawLine(0, 0, 1, 0);
      final circle = await run('draw.circle', {
        'center': [0, 0],
        'radius': 3,
      });
      final circleId = (circle.data!['ids']! as List).first as int;

      final result = await run('select.byType', {'kind': 'CIRCLE'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [circleId]);
    });

    test('select by type accepts a polyline alias', () async {
      await drawLine(0, 0, 1, 0);
      final created = await run('draw.polyline', {
        'points': [
          [0, 0],
          [2, 0],
          [2, 2],
        ],
      });
      final id = (created.data!['ids']! as List).first as int;

      final result = await run('select.byType', {'kind': 'lwpolyline'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids, [id]);
    });

    test('select by type refuses an unknown kind', () async {
      final result = await run('select.byType', {'kind': 'widget'});

      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('not an object type'));
    });

    test('select by block keeps only inserts of that definition', () async {
      final a = await drawLine(0, 0, 2, 0);
      final created = await run('edit.block', {
        'ids': [a],
        'name': 'STUD',
        'base': [0, 0],
      });
      final first = (created.data!['ids']! as List).first as int;
      final extra = await run('edit.insert', {
        'name': 'STUD',
        'at': [10, 0],
      });
      final second = (extra.data!['ids']! as List).first as int;
      final other = await drawLine(0, 4, 2, 4);
      await run('edit.block', {
        'ids': [other],
        'name': 'PIN',
        'base': [0, 4],
      });

      final result = await run('select.byBlock', {'name': 'stud'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(workspace.active!.selection.ids.toSet(), {first, second});
    });

    test('select by block refuses an unknown name', () async {
      final result = await run('select.byBlock', {'name': 'MISSING'});

      expect(result.status, CommandStatus.failed);
      expect(result.message, contains('no insertable block'));
    });
  });

  group('zoom', () {
    double scale() => workspace.active!.viewport.viewport.scale;

    test('zoom extents refuses an empty drawing', () async {
      workspace.active!.viewport.setSize(const Size(800, 600), 1);
      expect((await run('view.zoomExtents')).status, CommandStatus.failed);
    });

    test('zoom in, out and extents change the camera', () async {
      workspace.active!.viewport.setSize(const Size(800, 600), 1);
      await run('draw.line', {
        'start': [0, 0],
        'end': [100, 0],
      });
      await run('view.zoomExtents');
      final fitted = scale();

      await run('view.zoomIn');
      expect(scale(), closeTo(fitted * 2, 1e-9));

      await run('view.zoomOut');
      expect(scale(), closeTo(fitted, 1e-9));
    });

    test('zoom selected and zoom window frame the requested area', () async {
      workspace.active!.viewport.setSize(const Size(800, 600), 1);
      final created = await run('draw.line', {
        'start': [0, 0],
        'end': [40, 0],
      });
      final id = (created.data!['ids']! as List).first as int;
      workspace.active!.session.selection.clear();

      expect((await run('view.zoomSelected')).status, CommandStatus.failed);

      workspace.active!.session.selection.replace([id]);
      expect((await run('view.zoomSelected')).status, CommandStatus.ok);
      final selected = scale();

      await run('view.zoomWindow', {
        'corner1': [0, -1],
        'corner2': [4, 1],
      });
      expect(scale(), greaterThan(selected));
    });

    test('regen reports success without touching the drawing', () async {
      final result = await run('view.regen');
      expect(result.status, CommandStatus.ok);
      expect(result.message, contains('regenerated'));
      expect(document.entityCount, 0);
    });
  });
}
