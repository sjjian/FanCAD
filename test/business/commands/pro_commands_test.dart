import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
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

  group('layouts', () {
    test('set layout switches to a paper tab and frames the sheet', () async {
      document.addLayout(
        const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
      );

      final result = await run('layout.set', {'name': 'Layout1'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Layout1');
      expect(document.activeLayout.isModelSpace, isFalse);
      expect(document.extents.width, closeTo(297, 1e-9));
    });

    test('new layout opens a paper tab and frames the sheet', () async {
      final result = await run('layout.new');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Layout1');
      expect(document.activeLayout.isModelSpace, isFalse);
      expect(document.activeLayout.blockName, '*Paper_Space');
      expect(document.extents.width, closeTo(297, 1e-9));
      expect(document.extents.height, closeTo(210, 1e-9));

      await run('edit.undo');
      expect(document.activeLayoutName, 'Model');
      expect(document.layouts, hasLength(1));
    });

    test('new layout accepts a name and a sheet size', () async {
      final result = await run('layout.new', {
        'name': 'A3',
        'width': 420,
        'height': 297,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'A3');
      expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
      expect(document.activeLayout.paperHeight, closeTo(297, 1e-9));
    });

    test('new layout refuses a duplicate name', () async {
      await run('layout.new');
      final result = await run('layout.new', {'name': 'Layout1'});

      expect(result.status, CommandStatus.failed);
      expect(
        document.layouts.where((item) => !item.isModelSpace),
        hasLength(1),
      );
    });

    test('delete layout removes the current paper tab', () async {
      await run('layout.new');
      final result = await run('layout.delete');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Model');
      expect(document.layouts.where((item) => !item.isModelSpace), isEmpty);

      await run('edit.undo');
      expect(document.activeLayoutName, 'Layout1');
    });

    test(
      'copy layout duplicates the sheet, viewports and paper entities',
      () async {
        await run('layout.new');
        await run('layout.pagesetup', {'width': 420, 'height': 297});
        await run('layout.mview', {
          'corner1': [10, 10],
          'corner2': [200, 150],
          'scale': 1,
        });
        await drawLine(10, 10, 40, 10);
        expect(document.entitiesOf('*Paper_Space'), hasLength(1));

        final result = await run('layout.copy');

        expect(result.status, CommandStatus.ok, reason: result.message);
        expect(document.activeLayoutName, 'Layout2');
        expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
        expect(document.activeLayout.paperHeight, closeTo(297, 1e-9));
        expect(document.activeLayout.blockName, '*Paper_Space0');
        expect(document.activeLayout.viewports, hasLength(1));
        expect(
          document.activeLayout.viewports.single.paperBounds,
          const Bounds2(10, 10, 200, 150),
        );
        expect(document.entitiesOf('*Paper_Space0'), hasLength(1));
        expect(document.entitiesOf('*Paper_Space'), hasLength(1));
        expect(
          document.entitiesOf('*Paper_Space').single.id,
          isNot(document.entitiesOf('*Paper_Space0').single.id),
        );

        await run('edit.undo');
        expect(document.activeLayoutName, 'Layout1');
        expect(document.layouts.any((item) => item.name == 'Layout2'), isFalse);
        expect(document.blocks.containsKey('*Paper_Space0'), isFalse);
      },
    );

    test('copy layout refuses the model tab', () async {
      final result = await run('layout.copy', {'name': 'Model'});
      expect(result.status, CommandStatus.failed);
      expect(document.layouts, hasLength(1));
    });

    test('rename layout keeps the sheet and paper entities', () async {
      await run('layout.new');
      await run('layout.pagesetup', {'width': 420, 'height': 297});
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });
      await drawLine(10, 10, 40, 10);

      final result = await run('layout.rename', {'to': 'Title'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Title');
      expect(document.layouts.any((item) => item.name == 'Layout1'), isFalse);
      expect(document.activeLayout.blockName, '*Paper_Space');
      expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
      expect(document.activeLayout.viewports, hasLength(1));
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));

      await run('edit.undo');
      expect(document.activeLayoutName, 'Layout1');
      expect(document.layouts.any((item) => item.name == 'Title'), isFalse);
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));
    });

    test('rename layout refuses the model tab', () async {
      final result = await run('layout.rename', {
        'name': 'Model',
        'to': 'World',
      });
      expect(result.status, CommandStatus.failed);
      expect(document.activeLayoutName, 'Model');
    });

    test('order layout moves a paper tab and keeps Model first', () async {
      await run('layout.new');
      await run('layout.new');
      await run('layout.new');
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1', 'Layout2', 'Layout3'],
      );

      final result = await run('layout.order', {'name': 'Layout3', 'index': 0});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout3', 'Layout1', 'Layout2'],
      );
      expect(
        [for (final layout in document.layouts) layout.tabOrder],
        [0, 1, 2, 3],
      );

      await run('edit.undo');
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1', 'Layout2', 'Layout3'],
      );
    });

    test('order layout can insert before or after another paper tab', () async {
      await run('layout.new');
      await run('layout.new');
      await run('layout.new');

      final before = await run('layout.order', {
        'name': 'Layout3',
        'before': 'Layout2',
      });
      expect(before.status, CommandStatus.ok, reason: before.message);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1', 'Layout3', 'Layout2'],
      );

      final after = await run('layout.order', {
        'name': 'Layout1',
        'after': 'Layout2',
      });
      expect(after.status, CommandStatus.ok, reason: after.message);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout3', 'Layout2', 'Layout1'],
      );
    });

    test('order layout refuses Model', () async {
      await run('layout.new');
      final result = await run('layout.order', {'name': 'Model', 'index': 0});
      expect(result.status, CommandStatus.failed);
      expect(
        [for (final layout in document.layouts) layout.name],
        ['Model', 'Layout1'],
      );
    });

    test('rename layout refuses a duplicate name', () async {
      await run('layout.new');
      await run('layout.new');
      final result = await run('layout.rename', {
        'name': 'Layout1',
        'to': 'Layout2',
      });
      expect(result.status, CommandStatus.failed);
      expect(document.layouts.any((item) => item.name == 'Layout1'), isTrue);
    });

    test('copy layout refuses a duplicate name', () async {
      await run('layout.new');
      await run('layout.new');
      final result = await run('layout.copy', {
        'name': 'Layout1',
        'to': 'Layout2',
      });
      expect(result.status, CommandStatus.failed);
    });

    test('delete layout erases paper-space entities', () async {
      await run('layout.new');
      await drawLine(10, 10, 40, 10);
      expect(document.entitiesOf('*Paper_Space'), hasLength(1));

      final result = await run('layout.delete', {'name': 'Layout1'});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.entitiesOf('*Paper_Space'), isEmpty);
      expect(document.layouts.any((item) => item.name == 'Layout1'), isFalse);
    });

    test('page setup changes the current sheet size', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 420,
        'height': 297,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.paperWidth, closeTo(420, 1e-9));
      expect(document.activeLayout.paperHeight, closeTo(297, 1e-9));
      expect(document.extents.width, closeTo(420, 1e-9));

      await run('edit.undo');
      expect(document.activeLayout.paperWidth, closeTo(297, 1e-9));
      expect(document.activeLayout.paperHeight, closeTo(210, 1e-9));
    });

    test('page setup stores a plot rotation', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'rotation': 90,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.plotRotation, 90);

      await run('edit.undo');
      expect(document.activeLayout.plotRotation, 0);
    });

    test('page setup stores a plot window', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'corner1': [10, 20],
        'corner2': [110, 80],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.plotWindow, const Bounds2(10, 20, 110, 80));

      await run('edit.undo');
      expect(document.activeLayout.plotWindow, isNull);
    });

    test('page setup stores plot scale, fit and offset', () async {
      await run('layout.new');
      final result = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'scale': 0.5,
        'offset': [10, 20],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.plotScale, closeTo(0.5, 1e-9));
      expect(document.activeLayout.plotOffsetX, closeTo(10, 1e-9));
      expect(document.activeLayout.plotOffsetY, closeTo(20, 1e-9));
      expect(document.activeLayout.plotFit, isFalse);

      final fitted = await run('layout.pagesetup', {
        'width': 297,
        'height': 210,
        'fit': true,
      });
      expect(fitted.status, CommandStatus.ok, reason: fitted.message);
      expect(document.activeLayout.plotFit, isTrue);
    });

    test('page setup refuses Model', () async {
      final result = await run('layout.pagesetup', {
        'name': 'Model',
        'width': 420,
        'height': 297,
      });

      expect(result.status, CommandStatus.failed);
    });

    test('delete layout refuses Model', () async {
      final result = await run('layout.delete', {'name': 'Model'});

      expect(result.status, CommandStatus.failed);
      expect(document.layouts, hasLength(1));
    });

    test('mview works on a layout created by layout.new', () async {
      await drawLine(0, 0, 80, 0);
      await run('layout.new');
      final result = await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports, hasLength(1));
    });

    test('mview refuses the model tab', () async {
      final result = await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
      });

      expect(result.status, CommandStatus.failed);
      expect(document.activeLayout.viewports, isEmpty);
    });

    test('mview cuts a window that frames the model', () async {
      await drawLine(0, 0, 80, 0);
      document.addLayout(
        const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
      );
      await run('layout.set', {'name': 'Layout1'});

      final result = await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports, hasLength(1));
      final viewport = document.activeLayout.viewports.single;
      expect(viewport.paperBounds, const Bounds2(10, 10, 200, 150));
      expect(viewport.modelCenter.x, closeTo(40, 1e-9));
      expect(viewport.scale, closeTo(190 / 80, 1e-9));

      await run('edit.undo');
      expect(document.activeLayout.viewports, isEmpty);
    });

    test('vpscale changes the only viewport on the sheet', () async {
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final result = await run('layout.vpscale', {'scale': 0.5});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports.single.scale, closeTo(0.5, 1e-9));

      await run('edit.undo');
      expect(document.activeLayout.viewports.single.scale, closeTo(1, 1e-9));
    });

    test('vpscale fit frames the model again', () async {
      await drawLine(0, 0, 80, 0);
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final result = await run('layout.vpscale', {'fit': true});

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(
        document.activeLayout.viewports.single.scale,
        closeTo(190 / 80, 1e-9),
      );
      expect(
        document.activeLayout.viewports.single.modelCenter.x,
        closeTo(40, 1e-9),
      );
    });

    test('vpscale refuses a locked viewport', () async {
      await run('layout.new');
      final layout = document.activeLayout;
      document.addLayout(
        layout.copyWith(
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2.zero(),
              scale: 1,
              locked: true,
            ),
          ],
        ),
      );

      final result = await run('layout.vpscale', {'scale': 0.25});

      expect(result.status, CommandStatus.failed);
      expect(document.activeLayout.viewports.single.scale, closeTo(1, 1e-9));
    });

    test('vpscale refuses the model tab', () async {
      final result = await run('layout.vpscale', {'scale': 1});
      expect(result.status, CommandStatus.failed);
    });

    test('vplock toggles the only viewport and blocks vpscale', () async {
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final locked = await run('layout.vplock');
      expect(locked.status, CommandStatus.ok, reason: locked.message);
      expect(document.activeLayout.viewports.single.locked, isTrue);

      final refused = await run('layout.vpscale', {'scale': 0.25});
      expect(refused.status, CommandStatus.failed);
      expect(document.activeLayout.viewports.single.scale, closeTo(1, 1e-9));

      final unlocked = await run('layout.vplock', {'locked': false});
      expect(unlocked.status, CommandStatus.ok, reason: unlocked.message);
      expect(document.activeLayout.viewports.single.locked, isFalse);

      final scaled = await run('layout.vpscale', {'scale': 0.25});
      expect(scaled.status, CommandStatus.ok, reason: scaled.message);
      expect(document.activeLayout.viewports.single.scale, closeTo(0.25, 1e-9));

      await run('edit.undo');
      await run('edit.undo');
      expect(document.activeLayout.viewports.single.locked, isTrue);
    });

    test('vplock refuses the model tab', () async {
      final result = await run('layout.vplock', {'locked': true});
      expect(result.status, CommandStatus.failed);
    });

    test(
      'vpon toggles the only viewport and refuses vpmax while off',
      () async {
        await run('layout.new');
        await run('layout.mview', {
          'corner1': [10, 10],
          'corner2': [200, 150],
          'scale': 1,
        });

        final off = await run('layout.vpon');
        expect(off.status, CommandStatus.ok, reason: off.message);
        expect(document.activeLayout.viewports.single.isOn, isFalse);

        final refused = await run('layout.vpmax');
        expect(refused.status, CommandStatus.failed);
        expect(document.activeLayout.isModelSpace, isFalse);

        final on = await run('layout.vpon', {'on': true});
        expect(on.status, CommandStatus.ok, reason: on.message);
        expect(document.activeLayout.viewports.single.isOn, isTrue);

        await run('edit.undo');
        expect(document.activeLayout.viewports.single.isOn, isFalse);
      },
    );

    test('vpon refuses the model tab', () async {
      final result = await run('layout.vpon', {'on': false});
      expect(result.status, CommandStatus.failed);
    });

    test('vplayer freezes a layer in the only viewport', () async {
      await run('layer.new', {'name': 'DIMS'});
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 1,
      });

      final frozen = await run('layout.vplayer', {'layers': 'DIMS'});
      expect(frozen.status, CommandStatus.ok, reason: frozen.message);
      expect(document.activeLayout.viewports.single.frozenLayers, ['DIMS']);

      final thawed = await run('layout.vplayer', {
        'layers': 'DIMS',
        'freeze': false,
      });
      expect(thawed.status, CommandStatus.ok, reason: thawed.message);
      expect(document.activeLayout.viewports.single.frozenLayers, isEmpty);

      await run('edit.undo');
      expect(document.activeLayout.viewports.single.frozenLayers, ['DIMS']);
    });

    test('vplayer refuses the model tab', () async {
      await run('layer.new', {'name': 'DIMS'});
      final result = await run('layout.vplayer', {'layers': 'DIMS'});
      expect(result.status, CommandStatus.failed);
    });

    test('vpmax opens model space through the viewport', () async {
      await run('layout.new');
      await run('layout.mview', {
        'corner1': [10, 10],
        'corner2': [200, 150],
        'scale': 0.5,
      });

      final result = await run('layout.vpmax');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.isModelSpace, isTrue);
      expect(workspace.active!.session.maximizedLayoutName, 'Layout1');
      expect(workspace.active!.session.maximizedViewportIndex, 0);

      final back = await run('layout.vpmin');
      expect(back.status, CommandStatus.ok, reason: back.message);
      expect(document.activeLayoutName, 'Layout1');
      expect(workspace.active!.session.maximizedLayoutName, isNull);
    });

    test('vpmax refuses the model tab', () async {
      final result = await run('layout.vpmax');
      expect(result.status, CommandStatus.failed);
    });

    test('vpmin refuses when nothing is maximized', () async {
      final result = await run('layout.vpmin');
      expect(result.status, CommandStatus.failed);
    });

    test('mview honours an explicit scale', () async {
      document.addLayout(
        const Layout(name: 'Layout1', blockName: '*Paper_Space', tabOrder: 1),
      );
      await run('layout.set', {'name': 'Layout1'});

      final result = await run('layout.mview', {
        'corner1': [0, 0],
        'corner2': [100, 80],
        'scale': 0.1,
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayout.viewports.single.scale, closeTo(0.1, 1e-12));
    });
  });

  group('plot', () {
    test('plots a named paper layout without switching tabs', () async {
      await run('layout.new', {'name': 'A3', 'width': 420, 'height': 297});
      await run('layout.set', {'name': 'Model'});
      final dir = Directory.systemTemp.createTempSync('fancad_plot');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/sheet.svg';

      final result = await run('print.exportSvg', {
        'path': path,
        'layout': 'A3',
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.activeLayoutName, 'Model');
      expect(result.data!['layout'], 'A3');
      final svg = File(path).readAsStringSync();
      expect(svg, contains('width="420'));
      expect(svg, contains('height="297'));
    });

    test('plot honours a window on the named layout', () async {
      await run('layout.new', {'name': 'A3', 'width': 420, 'height': 297});
      final dir = Directory.systemTemp.createTempSync('fancad_plot');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/window.svg';

      final result = await run('print.exportSvg', {
        'path': path,
        'layout': 'A3',
        'corner1': [10, 20],
        'corner2': [110, 80],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      final svg = File(path).readAsStringSync();
      expect(svg, contains('width="100'));
      expect(svg, contains('height="60'));
    });

    test('plot refuses an unknown layout', () async {
      final result = await run('print.exportSvg', {
        'path': '/tmp/out.svg',
        'layout': 'Missing',
      });
      expect(result.status, CommandStatus.failed);
    });
  });

  group('xrefs', () {
    test('attach places an insert in model space', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/bracket.dxf';
      final foreign = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      File(path).writeAsStringSync(const DxfWriter().writeString(foreign));

      final result = await run('xref.attach', {
        'path': path,
        'at': [5, 6],
      });

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks['BRACKET']!.isXref, isTrue);
      final insert = document.activeEntities.whereType<InsertEntity>().single;
      expect(insert.blockName, 'BRACKET');
      expect(insert.position, const Vec2(5, 6));
    });

    test('reload rereads the file and keeps the insert', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/part.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );

      await run('xref.attach', {
        'path': path,
        'at': [3, 4],
      });
      final insertId = document.activeEntities
          .whereType<InsertEntity>()
          .single
          .id;

      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(20, 0)),
          ),
        ),
      );

      final result = await run('xref.reload');

      expect(result.status, CommandStatus.ok, reason: result.message);
      final insert = document.entity(insertId)! as InsertEntity;
      expect(insert.position, const Vec2(3, 4));
      final line =
          document.entity(document.blocks['PART']!.entityIds.single)!
              as LineEntity;
      expect(line.end.x, closeTo(20, 1e-9));
    });

    test('reload refuses when there is no xref', () async {
      final result = await run('xref.reload');
      expect(result.status, CommandStatus.failed);
    });

    test('reload refuses a missing file', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/gone.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );
      await run('xref.attach', {'path': path});
      File(path).deleteSync();

      final result = await run('xref.reload');

      expect(result.status, CommandStatus.failed);
      expect(document.blocks['GONE']!.entityIds, hasLength(1));
    });

    test('detach removes the insert and the xref block', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/part.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );
      await run('xref.attach', {
        'path': path,
        'at': [3, 4],
      });

      final result = await run('xref.detach');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks.containsKey('PART'), isFalse);
      expect(document.activeEntities.whereType<InsertEntity>(), isEmpty);

      await run('edit.undo');
      expect(document.blocks['PART']!.isXref, isTrue);
      expect(
        document.activeEntities.whereType<InsertEntity>().single.position,
        const Vec2(3, 4),
      );
    });

    test('detach refuses when there is no xref', () async {
      final result = await run('xref.detach');
      expect(result.status, CommandStatus.failed);
    });

    test('bind keeps the insert and drops the file path', () async {
      final dir = Directory.systemTemp.createTempSync('fancad_xref');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/part.dxf';
      File(path).writeAsStringSync(
        const DxfWriter().writeString(
          CadDocument()..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ),
        ),
      );
      await run('xref.attach', {
        'path': path,
        'at': [3, 4],
      });

      final result = await run('xref.bind');

      expect(result.status, CommandStatus.ok, reason: result.message);
      expect(document.blocks['PART']!.isXref, isFalse);
      expect(
        document.activeEntities.whereType<InsertEntity>().single.position,
        const Vec2(3, 4),
      );

      final reload = await run('xref.reload');
      expect(reload.status, CommandStatus.failed);
    });

    test('bind refuses when there is no xref', () async {
      final result = await run('xref.bind');
      expect(result.status, CommandStatus.failed);
    });
  });
}
