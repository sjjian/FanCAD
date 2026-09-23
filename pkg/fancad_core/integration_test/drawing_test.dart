@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG drawing', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('a drawing with CJK names reopens as UTF-8', () async {
      const layerName = '工艺';
      final opened = await rt.dwg(
        drawing(
          layers: const [LayerDef(name: layerName, color: CadColor.indexed(1))],
          entities: const [
            TextEntity(
              id: 1,
              props: EntityProps(layer: layerName),
              position: Vec2.zero(),
              content: '开槽',
              height: 2.5,
            ),
            MTextEntity(
              id: 2,
              props: EntityProps(layer: layerName),
              position: Vec2(0, 10),
              content: '锡东',
              height: 2.5,
            ),
          ],
        ),
        name: 'cjkutf',
      );

      final texts = <String>[
        ...opened.layers.keys,
        for (final entity in opened.entities)
          if (entity is TextEntity)
            entity.content
          else if (entity is MTextEntity)
            entity.content,
      ].join('\n');
      expect(texts.contains('\uFFFD'), isFalse);
      expect(
        texts.contains('工艺') || texts.contains('开槽') || texts.contains('锡东'),
        isTrue,
      );
      expect(opened.layers.keys.any((name) => name.contains(r'\U+')), isFalse);
    }, timeout: Roundtrip.timeout);

    test(
      'a synthetic drawing survives DWG save and reopen',
      () async {
        final source = syntheticDrawing();
        final opened = await rt.dwg(source, name: 'round1');

        expectFiniteModelExtents(opened, step: 'first write');
        expectMatchingSnapshots(source, opened, step: 'first write');
        expectNamedBlockIntact(opened, 'PART', lineCount: 3);
        expectNamedBlockIntact(opened, 'TITLE', attdefTag: 'Sheet no');
        expect(
          opened.entities.whereType<LineEntity>().first.props.lineWeight,
          LineWeight.byLayer,
          reason: 'DWG 29 must come back as ByLayer, not 0.29 mm',
        );
        final titled = opened.entities.whereType<InsertEntity>().firstWhere(
          (e) => e.blockName == 'TITLE',
        );
        expect(
          titled.attributes['Sheet no'],
          '01',
          reason: 'an ATTRIB tag with a space must survive dwg_add_ATTRIB',
        );
      },
      timeout: Roundtrip.timeout,
    );

    test('edits survive a second DWG save and reopen', () async {
      final source = syntheticDrawing();
      final opened = await rt.dwg(source, name: 'before');

      final edited = applyEdits(opened);
      final reopened = await rt.dwg(edited, name: 'after');

      expectFiniteModelExtents(reopened, step: 'edit pass');
      expectMatchingSnapshots(edited, reopened, step: 'edit pass');

      final moved = reopened.entities.whereType<LineEntity>().where(
        (e) =>
            close(e.start, const Vec2(105, 3)) &&
            close(e.end, const Vec2(115, 3)),
      );
      expect(moved, hasLength(1), reason: 'edit pass: translated LINE');

      final text = reopened.entities.whereType<TextEntity>().where(
        (e) => e.content == 'edited',
      );
      expect(text, hasLength(1), reason: 'edit pass: TEXT content');
      expect(text.single.position.x, closeTo(1200, 1e-6));
      expect(text.single.position.y, closeTo(800, 1e-6));

      final arc = reopened.entities.whereType<ArcEntity>().single;
      expect(arc.props.layer, 'NOTES', reason: 'edit pass: ARC layer');

      final added = reopened.entities.whereType<CircleEntity>().where(
        (e) =>
            close(e.center, const Vec2(500, 500)) &&
            (e.radius - 12).abs() < 1e-6,
      );
      expect(added, hasLength(1), reason: 'edit pass: added CIRCLE');

      expect(
        reopened.entities.whereType<PointEntity>().where(
          (e) => close(e.position, const Vec2(77, 88)),
        ),
        isEmpty,
        reason: 'edit pass: deleted POINT',
      );
    }, timeout: Roundtrip.timeout);

    test(
      'MULTILEADER and REGION survive a DWG round-trip',
      () async {
        final document = CadDocument()
          ..addEntity(
            const AttribEntity(
              id: 1,
              position: Vec2(6, 6),
              tag: 'REV',
              value: 'B',
            ),
          )
          ..addEntity(
            UnknownEntity(
              id: 2,
              originalType: 'REGION',
              strokes: Float64List.fromList([0, 0, 2, 0, 2, 2]),
              strokeCounts: const [3],
            ),
          )
          ..addEntity(
            MLeaderEntity(
              id: 3,
              vertices: Float64List.fromList([0, 8, 4, 8]),
              content: 'callout',
              textPosition: const Vec2(5, 8),
              textHeight: 2.5,
            ),
          );

        final opened = await rt.dwg(document, name: 'gaps');

        expect(
          opened.entities.whereType<AttribEntity>(),
          isEmpty,
          reason: 'a standalone ATTRIB is stored as TEXT',
        );
        expect(
          opened.entities.whereType<TextEntity>().any((e) => e.content == 'B'),
          isTrue,
          reason: 'ATTRIB content must still be visible as TEXT',
        );
        expect(
          opened.entities.whereType<UnknownEntity>(),
          isNotEmpty,
          reason: 'REGION strokes must come back as UNKNOWN, not LWPOLYLINE',
        );
        expect(
          opened.entities.whereType<UnknownEntity>().single.originalType,
          'REGION',
        );
        expect(
          opened.entities.whereType<MLeaderEntity>(),
          isEmpty,
          reason: 'R2004 writes MULTILEADER as LEADER+MTEXT',
        );
        expect(
          opened.entities.whereType<LeaderEntity>(),
          isNotEmpty,
          reason: 'the callout stem must remain a LEADER',
        );
        expect(
          opened.entities.whereType<MTextEntity>().single.content,
          contains('callout'),
        );
      },
      timeout: Roundtrip.timeout,
    );

    test('insertion units survive a DWG round trip', () async {
      final source = CadDocument()
        ..setHeaderVariable(r'$INSUNITS', '1')
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
        );
      final opened = await rt.dwg(source, name: 'insunits');
      expect(opened.insUnits, InsUnits.inches);
    });

    test(
      'insert move, mtext edit and hatch add survive a second save',
      () async {
        final source = CadDocument()
          ..putBlock(const BlockRecord(name: 'PART'))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
            blockName: 'PART',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'PART',
              position: Vec2(10, 10),
            ),
          )
          ..addEntity(
            const MTextEntity(id: 3, position: Vec2(0, 8), content: 'note'),
          )
          ..addEntity(
            const CircleEntity(id: 4, center: Vec2(20, 20), radius: 3),
          );

        final opened = await rt.dwg(source, name: 'edit2a');
        final insert = opened.entities.whereType<InsertEntity>().single;
        opened.replaceEntity(
          InsertEntity(
            id: insert.id,
            props: insert.props,
            blockName: insert.blockName,
            position: const Vec2(15, 12),
            scale: insert.scale,
            rotation: insert.rotation,
            attributes: insert.attributes,
          ),
        );
        final mtext = opened.entities.whereType<MTextEntity>().single;
        opened.replaceEntity(
          MTextEntity(
            id: mtext.id,
            props: mtext.props,
            position: mtext.position,
            content: 'changed',
            height: mtext.height,
            rotation: mtext.rotation,
            styleName: mtext.styleName,
            rectangleWidth: mtext.rectangleWidth,
          ),
        );
        opened.removeEntity(
          opened.entities.whereType<CircleEntity>().single.id,
        );
        opened.addEntity(
          HatchEntity(
            id: 0,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 6, 0, 6, 6, 0, 6]),
              ),
            ],
          ),
        );

        final reopened = await rt.dwg(opened, name: 'edit2b');
        expectMatchingSnapshots(opened, reopened, step: 'further edits');
        expect(
          reopened.entities.whereType<InsertEntity>().single.position,
          const Vec2(15, 12),
        );
        expect(
          reopened.entities.whereType<MTextEntity>().single.content,
          'changed',
        );
        expect(reopened.entities.whereType<CircleEntity>(), isEmpty);
        expect(reopened.entities.whereType<HatchEntity>(), hasLength(1));
      },
    );

    test('deleting an INSERT leaves the block definition', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'KEEP'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(3, 0)),
          blockName: 'KEEP',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'KEEP', position: Vec2(9, 9)),
        );
      final opened = await rt.dwg(source, name: 'delinsa');
      opened.removeEntity(opened.entities.whereType<InsertEntity>().single.id);
      final reopened = await rt.dwg(opened, name: 'delinsb');
      expect(reopened.blocks.containsKey('KEEP'), isTrue);
      expect(reopened.entities.whereType<InsertEntity>(), isEmpty);
      expect(reopened.entitiesOf('KEEP').whereType<LineEntity>(), hasLength(1));
    });

    test('editing an INSERT attribute survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'FORM'))
        ..addEntity(
          const AttdefEntity(
            id: 1,
            position: Vec2.zero(),
            tag: 'REV',
            defaultValue: 'A',
          ),
          blockName: 'FORM',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'FORM',
            position: Vec2(6, 6),
            attributes: {'REV': 'A'},
          ),
        );
      final opened = await rt.dwg(source, name: 'attr1');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: insert.position,
          scale: insert.scale,
          rotation: insert.rotation,
          attributes: const {'REV': 'C'},
        ),
      );
      final reopened = await rt.dwg(opened, name: 'attr2');
      expect(
        reopened.entities.whereType<InsertEntity>().single.attributes['REV'],
        'C',
      );
    });

    test('moving a LINE inside a named block survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'PART', position: Vec2(10, 10)),
        );
      final opened = await rt.dwg(source, name: 'blked1');
      final line = opened.entitiesOf('PART').whereType<LineEntity>().single;
      opened.replaceEntity(
        LineEntity(
          id: line.id,
          props: line.props,
          start: const Vec2(1, 1),
          end: const Vec2(5, 1),
        ),
      );
      final reopened = await rt.dwg(opened, name: 'blked2');
      final moved = reopened.entitiesOf('PART').whereType<LineEntity>().single;
      expect(moved.start, const Vec2(1, 1));
      expect(moved.end, const Vec2(5, 1));
    });

    test('changing a LINE layer survives a second save', () async {
      final source = CadDocument()
        ..putLayer(const LayerDef(name: 'A', color: CadColor.indexed(1)))
        ..putLayer(const LayerDef(name: 'B', color: CadColor.indexed(2)))
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'A'),
            start: Vec2.zero(),
            end: Vec2(3, 0),
          ),
        );
      final opened = await rt.dwg(source, name: 'ly1');
      final line = opened.entities.whereType<LineEntity>().single;
      opened.replaceEntity(line.withProps(const EntityProps(layer: 'B')));
      final reopened = await rt.dwg(opened, name: 'ly2');
      expect(reopened.entities.whereType<LineEntity>().single.props.layer, 'B');
    });

    test('rotating an INSERT survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'ARM'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'ARM',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'ARM', position: Vec2(5, 5)),
        );
      final opened = await rt.dwg(source, name: 'rot1');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: insert.position,
          scale: insert.scale,
          rotation: 0.7,
          attributes: insert.attributes,
        ),
      );
      final reopened = await rt.dwg(opened, name: 'rot2');
      expect(
        reopened.entities.whereType<InsertEntity>().single.rotation,
        closeTo(0.7, 1e-6),
      );
    });

    test(
      'saving over the same DWG path replaces the previous drawing',
      () async {
        final directory = tempDir(prefix: 'fancad-ow');
        final path = '${directory.path}/same.dwg';

        final first = CadDocument()
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          );
        await rt.importer.save(path, first);
        final second = CadDocument()
          ..addEntity(const CircleEntity(id: 1, center: Vec2(4, 4), radius: 2));
        await rt.importer.save(path, second);
        final opened = (await rt.importer.open(path)).document;
        expect(opened.entities.whereType<LineEntity>(), isEmpty);
        expect(opened.entities.whereType<CircleEntity>(), hasLength(1));
      },
    );

    test('adding a LINE to an existing block survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'PART', position: Vec2(8, 8)),
        );
      final opened = await rt.dwg(source, name: 'addb1');
      opened.addEntity(
        const LineEntity(id: 0, start: Vec2(0, 1), end: Vec2(2, 1)),
        blockName: 'PART',
      );
      final reopened = await rt.dwg(opened, name: 'addb2');
      expect(reopened.entitiesOf('PART').whereType<LineEntity>(), hasLength(2));
    });

    test('changing a CIRCLE radius survives a second save', () async {
      final source = CadDocument()
        ..addEntity(const CircleEntity(id: 1, center: Vec2(4, 4), radius: 2));
      final opened = await rt.dwg(source, name: 'cr1');
      final circle = opened.entities.whereType<CircleEntity>().single;
      opened.replaceEntity(
        CircleEntity(
          id: circle.id,
          props: circle.props,
          center: circle.center,
          radius: 7,
        ),
      );
      final reopened = await rt.dwg(opened, name: 'cr2');
      expect(
        reopened.entities.whereType<CircleEntity>().single.radius,
        closeTo(7, 1e-6),
      );
    });

    test('changing TEXT height survives a second save', () async {
      final source = CadDocument()
        ..addEntity(
          const TextEntity(
            id: 1,
            position: Vec2(1, 1),
            content: 'h',
            height: 2.5,
          ),
        );
      final opened = await rt.dwg(source, name: 'th1');
      final text = opened.entities.whereType<TextEntity>().single;
      opened.replaceEntity(
        TextEntity(
          id: text.id,
          props: text.props,
          position: text.position,
          content: text.content,
          height: 8,
          rotation: text.rotation,
          styleName: text.styleName,
          widthFactor: text.widthFactor,
          obliqueAngle: text.obliqueAngle,
          hAlign: text.hAlign,
          vAlign: text.vAlign,
        ),
      );
      final reopened = await rt.dwg(opened, name: 'th2');
      expect(
        reopened.entities.whereType<TextEntity>().single.height,
        closeTo(8, 1e-6),
      );
    });

    test('deleting a block member leaves the other members', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'PART',
        )
        ..addEntity(
          const LineEntity(id: 2, start: Vec2.zero(), end: Vec2(0, 2)),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(id: 3, blockName: 'PART', position: Vec2(6, 6)),
        );
      final opened = await rt.dwg(source, name: 'delm1');
      final first = opened.entitiesOf('PART').whereType<LineEntity>().first;
      opened.removeEntity(first.id);
      final reopened = await rt.dwg(opened, name: 'delm2');
      expect(reopened.entitiesOf('PART').whereType<LineEntity>(), hasLength(1));
      expect(reopened.entities.whereType<InsertEntity>(), hasLength(1));
    });

    test('adding a paper LINE survives a second save', () async {
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
        const CircleEntity(id: 1, center: Vec2(10, 10), radius: 2),
        blockName: '*Paper_Space',
      );
      final opened = await rt.dwg(document, name: 'padd1');
      final paper = opened.layouts
          .firstWhere((item) => item.name == 'Sheet')
          .blockName;
      opened.addEntity(
        const LineEntity(id: 0, start: Vec2(0, 0), end: Vec2(20, 0)),
        blockName: paper,
      );
      final reopened = await rt.dwg(opened, name: 'padd2');
      final line = reopened.entities.whereType<LineEntity>().single;
      expect(line.end.x, closeTo(20, 1e-6));
      expect(sameOwner(reopened.ownerOf(line.id), '*Paper_Space'), isTrue);
    });

    test('changing INSERT scale survives a second save', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'ARM'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'ARM',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'ARM', position: Vec2(4, 4)),
        );
      final opened = await rt.dwg(source, name: 'sc1');
      final insert = opened.entities.whereType<InsertEntity>().single;
      opened.replaceEntity(
        InsertEntity(
          id: insert.id,
          props: insert.props,
          blockName: insert.blockName,
          position: insert.position,
          scale: const Vec2(0.5, 2),
          rotation: insert.rotation,
          attributes: insert.attributes,
        ),
      );
      final reopened = await rt.dwg(opened, name: 'sc2');
      final scaled = reopened.entities.whereType<InsertEntity>().single;
      expect(scaled.scale.x, closeTo(0.5, 1e-6));
      expect(scaled.scale.y, closeTo(2, 1e-6));
    });

    test('changing an ARC sweep survives a second save', () async {
      final source = CadDocument()
        ..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2(0, 0),
            radius: 5,
            startAngle: 0,
            endAngle: 1,
          ),
        );
      final opened = await rt.dwg(source, name: 'arc1');
      final arc = opened.entities.whereType<ArcEntity>().single;
      opened.replaceEntity(
        ArcEntity(
          id: arc.id,
          props: arc.props,
          center: arc.center,
          radius: arc.radius,
          startAngle: arc.startAngle,
          endAngle: 2.2,
        ),
      );
      final reopened = await rt.dwg(opened, name: 'arc2');
      expect(
        reopened.entities.whereType<ArcEntity>().single.endAngle,
        closeTo(2.2, 1e-6),
      );
    });

    test('moving a POINT survives a second save', () async {
      final source = CadDocument()
        ..addEntity(const PointEntity(id: 1, position: Vec2(1, 1)));
      final opened = await rt.dwg(source, name: 'pt1');
      final point = opened.entities.whereType<PointEntity>().single;
      opened.replaceEntity(
        PointEntity(
          id: point.id,
          props: point.props,
          position: const Vec2(9, 8),
        ),
      );
      final reopened = await rt.dwg(opened, name: 'pt2');
      expect(
        reopened.entities.whereType<PointEntity>().single.position,
        const Vec2(9, 8),
      );
    });

    test('a third save keeps the latest geometry', () async {
      var document = CadDocument()
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
        );
      document = await rt.dwg(document, name: 't1');
      final line = document.entities.whereType<LineEntity>().single;
      document.replaceEntity(
        LineEntity(
          id: line.id,
          props: line.props,
          start: const Vec2(1, 1),
          end: const Vec2(3, 1),
        ),
      );
      document = await rt.dwg(document, name: 't2');
      document.addEntity(
        const CircleEntity(id: 0, center: Vec2(5, 5), radius: 1),
      );
      final third = await rt.dwg(document, name: 't3');
      expect(
        third.entities.whereType<LineEntity>().single.end,
        const Vec2(3, 1),
      );
      expect(third.entities.whereType<CircleEntity>(), hasLength(1));
    });

    test('deleting a paper TEXT leaves the sheet', () async {
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
        const TextEntity(id: 1, position: Vec2(10, 10), content: 'gone'),
        blockName: '*Paper_Space',
      );
      document.addEntity(
        const CircleEntity(id: 2, center: Vec2(20, 20), radius: 3),
        blockName: '*Paper_Space',
      );
      final opened = await rt.dwg(document, name: 'pdel1');
      opened.removeEntity(opened.entities.whereType<TextEntity>().single.id);
      final reopened = await rt.dwg(opened, name: 'pdel2');
      expect(reopened.entities.whereType<TextEntity>(), isEmpty);
      expect(
        sameOwner(
          reopened.ownerOf(
            reopened.entities.whereType<CircleEntity>().single.id,
          ),
          '*Paper_Space',
        ),
        isTrue,
      );
    });

    test('changing a block member layer survives a second save', () async {
      final source = CadDocument()
        ..putLayer(const LayerDef(name: 'A', color: CadColor.indexed(1)))
        ..putLayer(const LayerDef(name: 'B', color: CadColor.indexed(2)))
        ..putBlock(const BlockRecord(name: 'PART'))
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'A'),
            start: Vec2.zero(),
            end: Vec2(2, 0),
          ),
          blockName: 'PART',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'PART', position: Vec2(4, 4)),
        );
      final opened = await rt.dwg(source, name: 'bly1');
      final line = opened.entitiesOf('PART').whereType<LineEntity>().single;
      opened.replaceEntity(line.withProps(const EntityProps(layer: 'B')));
      final reopened = await rt.dwg(opened, name: 'bly2');
      expect(
        reopened.entitiesOf('PART').whereType<LineEntity>().single.props.layer,
        'B',
      );
    });
  });
}
