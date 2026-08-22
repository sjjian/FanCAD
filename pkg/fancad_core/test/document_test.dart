import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('BlockRecord', () {
    test('xref and copyWith keep the entity list', () {
      const block = BlockRecord(
        name: 'TITLE',
        entityIds: [1, 2],
        xrefPath: 'a.dwg',
      );
      expect(block.isXref, isTrue);
      expect(block.copyWith(xrefPath: '').isXref, isFalse);
      expect(block.toString(), contains('2 entities'));
    });
  });

  group('Layout', () {
    test('plot rotation snaps to quarters and copy can clear the window', () {
      expect(Layout.normalizePlotRotation(80), 90);
      expect(Layout.normalizePlotRotation(-90), 270);
      const sheet = Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        plotWindow: Bounds2(0, 0, 10, 10),
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(20, 20, 100, 80),
            modelCenter: Vec2.zero(),
          ),
        ],
      );
      expect(sheet.hasCustomPlotPlacement, isFalse);
      expect(sheet.viewportIndexAt(50, 50), 0);
      expect(sheet.viewportIndexAt(0, 0), isNull);
      expect(sheet.copyWith(clearPlotWindow: true).plotWindow, isNull);
      expect(sheet.copyWith(plotFit: true).hasCustomPlotPlacement, isTrue);
      expect(sheet.toString(), contains('A3'));
    });
  });

  group('DocumentChange', () {
    test('merge unions ids and regeneration flags', () {
      const empty = DocumentChange();
      expect(empty.isEmpty, isTrue);
      final merged = const DocumentChange(added: [1]).merge(
        const DocumentChange(removed: [2], tablesChanged: true),
      );
      expect(merged.added, [1]);
      expect(merged.removed, [2]);
      expect(merged.requiresFullRegeneration, isTrue);
      expect(merged.isNotEmpty, isTrue);
    });
  });

  group('CadDocument', () {
    test('add, replace and remove keep owner and draw order', () {
      final document = CadDocument();
      expect(document.isEmpty, isTrue);
      final first = document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
      );
      final second = document.addEntity(
        const PointEntity(id: 0, position: Vec2(1, 1)),
      );
      expect(first.id, isNot(0));
      expect(document.ownerOf(first.id), document.modelSpaceBlockName);
      expect(document.entityIndexOf(second.id), 1);
      expect(document.activeEntities.map((e) => e.id), [first.id, second.id]);

      document.replaceEntity(
        LineEntity(
          id: first.id,
          start: const Vec2(1, 0),
          end: const Vec2(11, 0),
        ),
      );
      expect((document.entity(first.id)! as LineEntity).start.x, 1);

      expect(document.removeEntity(second.id)?.kind, EntityKind.point);
      expect(document.entity(second.id), isNull);
      expect(document.entityIndexOf(second.id), isNull);
      expect(document.entityCount, 1);
    });

    test('insertEntity restores an id at a specific draw-order index', () {
      final document = CadDocument();
      final a = document.addEntity(
        const PointEntity(id: 0, position: Vec2.zero()),
      );
      final c = document.addEntity(
        const PointEntity(id: 0, position: Vec2(2, 0)),
      );
      document.insertEntity(
        const PointEntity(id: 50, position: Vec2(1, 0)),
        blockName: document.modelSpaceBlockName,
        index: 1,
      );
      expect(document.entitiesOf(document.modelSpaceBlockName).map((e) => e.id), [
        a.id,
        50,
        c.id,
      ]);
    });

    test('layer 0 and Standard dimstyle cannot be removed', () {
      final document = CadDocument()
        ..putLayer(const LayerDef(name: 'WALLS'))
        ..putLineType(LineTypeDef.dashed)
        ..putTextStyle(const TextStyleDef(name: 'Notes'))
        ..putDimStyle(const DimStyleDef(name: 'ARCH'))
        ..currentDimStyle = 'ARCH';
      expect(document.removeLayer('0'), isNull);
      expect(document.removeLayer('WALLS')?.name, 'WALLS');
      expect(document.removeDimStyle('Standard'), isNull);
      expect(document.removeDimStyle('arch')?.name, 'ARCH');
      expect(document.currentDimStyle, 'Standard');
      expect(document.dimStyle('missing').name, 'Standard');
    });

    test('blocks rename unless they are layout containers', () {
      final document = CadDocument();
      final line = document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
        blockName: 'DOOR',
      );
      expect(document.renameBlock('DOOR', 'LEAF'), isTrue);
      expect(document.ownerOf(line.id), 'LEAF');
      expect(document.renameBlock('*Model_Space', 'Nope'), isFalse);
      expect(document.removeBlock('LEAF')?.entityIds, [line.id]);
      expect(document.entity(line.id), isNull);
      expect(
        document.insertableBlocks.map((b) => b.name),
        isNot(contains('*Model_Space')),
      );
    });

    test('paper layouts can be added, activated and removed', () {
      final document = CadDocument();
      expect(document.setActiveLayout('missing'), isFalse);
      document.addLayout(
        const Layout(
          name: 'A3',
          blockName: '*Paper_Space',
          tabOrder: 1,
        ),
      );
      expect(document.setActiveLayout('A3'), isTrue);
      expect(document.activeLayoutName, 'A3');
      expect(document.removeLayout('Model'), isFalse);
      expect(document.removeLayout('A3'), isTrue);
      expect(document.activeLayoutName, 'Model');
    });

    test('queryVisible skips hidden entities and respects the index', () {
      final document = CadDocument();
      final visible = document.addEntity(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(5, 0)),
      );
      document.addEntity(
        const LineEntity(
          id: 0,
          props: EntityProps(visible: false),
          start: Vec2(0, 1),
          end: Vec2(5, 1),
        ),
      );
      expect(document.queryVisible(const Bounds2(-1, -1, 6, 6)), [visible.id]);
      document.setHeaderVariable('\$INSUNITS', '4');
      expect(document.headerVariables['\$INSUNITS'], '4');
      document.invalidateCaches();
      expect(document.queryVisible(const Bounds2(-1, -1, 6, 6)), [visible.id]);
    });
  });
}
