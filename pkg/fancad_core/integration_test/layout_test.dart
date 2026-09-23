@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG layout', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a model-only drawing does not grow a Layout1 tab', () async {
      final opened = await rt.dwg(
        CadDocument()..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        ),
        name: 'modelonly',
      );
      expect(opened.layouts.where((item) => !item.isModelSpace), isEmpty);
      final model = opened.layouts.where((item) => item.isModelSpace).single;
      expect(model.paperWidth, closeTo(297, 1e-4));
      expect(model.paperHeight, closeTo(210, 1e-4));
    });

    test('two paper tabs keep separate entity lists', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'A3',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.addLayout(
        const Layout(
          name: 'A4',
          blockName: '*Paper_Space0',
          tabOrder: 2,
          paperWidth: 210,
          paperHeight: 297,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const CircleEntity(id: 2, center: Vec2(5, 5), radius: 2),
        blockName: '*Paper_Space0',
      );
      document.addEntity(
        const LineEntity(id: 3, start: Vec2(100, 0), end: Vec2(110, 0)),
      );

      final opened = await rt.dwg(document, name: 'sheets');
      expectMatchingSnapshots(document, opened, step: 'paper tabs');
      expect(
        opened.layouts.where((item) => item.name == 'A3').single.paperWidth,
        closeTo(420, 1e-4),
      );
      expect(
        opened.layouts.where((item) => item.name == 'A4').single.paperWidth,
        closeTo(210, 1e-4),
      );
    });

    test('paper viewports survive a DWG round trip', () async {
      final document = CadDocument()
        ..putLayer(const LayerDef(name: 'DIMS', color: CadColor.indexed(1)));
      document.addLayout(
        Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(20, 20, 400, 277),
              modelCenter: Vec2(50, 50),
              scale: 0.1,
              rotation: 0.25,
              locked: true,
              frozenLayers: ['DIMS'],
            ),
          ],
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
        blockName: '*Paper_Space',
      );

      final opened = await rt.dwg(document, name: 'vp');
      final sheet = opened.layouts.where((item) => item.name == 'Sheet').single;
      expect(sheet.viewports, hasLength(1));
      final viewport = sheet.viewports.single;
      expect(viewport.paperBounds.minX, closeTo(20, 1e-4));
      expect(viewport.paperBounds.minY, closeTo(20, 1e-4));
      expect(viewport.paperBounds.maxX, closeTo(400, 1e-4));
      expect(viewport.paperBounds.maxY, closeTo(277, 1e-4));
      expect(viewport.modelCenter.x, closeTo(50, 1e-4));
      expect(viewport.modelCenter.y, closeTo(50, 1e-4));
      expect(viewport.scale, closeTo(0.1, 1e-4));
      expect(viewport.rotation, closeTo(0.25, 1e-4));
      expect(viewport.isOn, isTrue);
      expect(viewport.locked, isTrue);
      expect(viewport.frozenLayers, ['DIMS']);
    });

    test('TEXT and MTEXT on a sheet stay in paper space', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const TextEntity(
          id: 1,
          position: Vec2(20, 200),
          content: 'title',
          height: 5,
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const MTextEntity(
          id: 2,
          position: Vec2(20, 180),
          content: 'notes',
          height: 3,
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const LineEntity(id: 3, start: Vec2.zero(), end: Vec2(1, 0)),
      );

      final opened = await rt.dwg(document, name: 'ptext');
      expectMatchingSnapshots(document, opened, step: 'paper text');
      expect(
        sameOwner(
          opened.ownerOf(opened.entities.whereType<TextEntity>().single.id),
          '*Paper_Space',
        ),
        isTrue,
      );
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<TextEntity>(),
        isEmpty,
      );
    });

    test('CIRCLE and HATCH on a sheet stay in paper space', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const CircleEntity(id: 1, center: Vec2(40, 40), radius: 8),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        HatchEntity(
          id: 2,
          loops: [
            HatchLoop(
              vertices: Float64List.fromList([10, 10, 30, 10, 30, 25, 10, 25]),
            ),
          ],
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(const PointEntity(id: 3, position: Vec2(100, 0)));

      final opened = await rt.dwg(document, name: 'pgeom');
      expectMatchingSnapshots(document, opened, step: 'paper geom');
      expect(
        sameOwner(
          opened.ownerOf(opened.entities.whereType<CircleEntity>().single.id),
          '*Paper_Space',
        ),
        isTrue,
      );
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<HatchEntity>(),
        isEmpty,
      );
    });

    test('an INSERT on the second paper tab stays on that tab', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'A3',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.addLayout(
        const Layout(
          name: 'A4',
          blockName: '*Paper_Space0',
          tabOrder: 2,
          paperWidth: 210,
          paperHeight: 297,
        ),
      );
      document.putBlock(const BlockRecord(name: 'MARK'));
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
        blockName: 'MARK',
      );
      document.addEntity(
        const InsertEntity(id: 2, blockName: 'MARK', position: Vec2(25, 40)),
        blockName: '*Paper_Space0',
      );

      final opened = await rt.dwg(document, name: 'p2ins');
      expectMatchingSnapshots(document, opened, step: 'second-tab insert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(sameOwner(opened.ownerOf(insert.id), '*Paper_Space0'), isTrue);
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<InsertEntity>(),
        isEmpty,
      );
    });

    test('plot rotation is not yet written', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
          plotRotation: 90,
          plotScale: 0.5,
          plotFit: true,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(5, 0)),
        blockName: '*Paper_Space',
      );
      final opened = await rt.dwg(document, name: 'plotrot');
      final sheet = opened.layouts.where((item) => item.name == 'Sheet').single;
      expect(sheet.paperWidth, closeTo(297, 1e-4));
      expect(
        sheet.plotRotation,
        0,
        reason: 'dwg_export writes paper size, not plot twist / scale / fit',
      );
    });

    test('an empty paper tab still keeps its size', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Blank',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
      );
      final opened = await rt.dwg(document, name: 'emptytab');
      final sheet = opened.layouts.where((item) => item.name == 'Blank').single;
      expect(sheet.paperWidth, closeTo(420, 1e-4));
      expect(sheet.paperHeight, closeTo(297, 1e-4));
      expect(
        opened.entitiesOf(sheet.blockName).whereType<LineEntity>(),
        isEmpty,
      );
    });

    test('ARC and SOLID on a sheet stay in paper space', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addEntity(
        const ArcEntity(
          id: 1,
          center: Vec2(50, 50),
          radius: 10,
          startAngle: 0,
          endAngle: 2,
        ),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const SolidEntity(
          id: 2,
          corners: [Vec2(5, 5), Vec2(15, 5), Vec2(15, 12), Vec2(5, 12)],
        ),
        blockName: '*Paper_Space',
      );
      final opened = await rt.dwg(document, name: 'parc');
      expectMatchingSnapshots(document, opened, step: 'paper arc solid');
      expect(
        sameOwner(
          opened.ownerOf(opened.entities.whereType<ArcEntity>().single.id),
          '*Paper_Space',
        ),
        isTrue,
      );
    });

    test('three paper tabs keep three entity lists', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'A',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.addLayout(
        const Layout(
          name: 'B',
          blockName: '*Paper_Space0',
          tabOrder: 2,
          paperWidth: 297,
          paperHeight: 210,
        ),
      );
      document.addLayout(
        const Layout(
          name: 'C',
          blockName: '*Paper_Space1',
          tabOrder: 3,
          paperWidth: 210,
          paperHeight: 297,
        ),
      );
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(3, 0)),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const CircleEntity(id: 2, center: Vec2(1, 1), radius: 1),
        blockName: '*Paper_Space0',
      );
      document.addEntity(
        const PointEntity(id: 3, position: Vec2(2, 2)),
        blockName: '*Paper_Space1',
      );
      final opened = await rt.dwg(document, name: 'three');
      expectMatchingSnapshots(document, opened, step: 'three tabs');
      expect(opened.layouts.where((item) => !item.isModelSpace), hasLength(3));
    });
  });
}
