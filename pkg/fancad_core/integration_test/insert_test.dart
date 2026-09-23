@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

import '../test/io/support/native.dart';
import '../test/io/support/roundtrip.dart';
import 'support/snapshots.dart';

void main() {
  nativeGroup('DWG insert', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test('insert scale, rotation and base point survive', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'TICK', basePoint: Vec2(100, 50)))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2(100, 50), end: Vec2(101, 50)),
          blockName: 'TICK',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'TICK',
            position: Vec2(10, 20),
            scale: Vec2(2, 3),
            rotation: 0.25,
          ),
        );
      final opened = await rt.dwg(source, name: 'tick');
      expect(opened.blocks['TICK']?.basePoint, const Vec2(100, 50));
      expectMatchingSnapshots(source, opened, step: 'scaled insert');
    });

    test('a MINSERT keeps row and column counts', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'CELL'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
          blockName: 'CELL',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'CELL',
            position: Vec2(0, 0),
            columnCount: 3,
            rowCount: 2,
            columnSpacing: 10,
            rowSpacing: 5,
          ),
        );
      final opened = await rt.dwg(source, name: 'minsert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.columnCount, 3);
      expect(insert.rowCount, 2);
      expect(insert.columnSpacing, closeTo(10, 1e-6));
      expect(insert.rowSpacing, closeTo(5, 1e-6));
    });

    test('a nested INSERT stays inside its owner block', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'INNER'))
        ..putBlock(const BlockRecord(name: 'OUTER'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 1),
          blockName: 'INNER',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'INNER', position: Vec2(2, 0)),
          blockName: 'OUTER',
        )
        ..addEntity(
          const InsertEntity(id: 3, blockName: 'OUTER', position: Vec2(40, 40)),
        );
      final opened = await rt.dwg(source, name: 'nested');
      expectMatchingSnapshots(source, opened, step: 'nested insert');
      expect(
        opened.entitiesOf('OUTER').whereType<InsertEntity>(),
        hasLength(1),
      );
      expect(
        opened.entities.whereType<InsertEntity>().where(
          (e) => e.blockName == 'OUTER',
        ),
        hasLength(1),
      );
    });

    test('an empty named block can still be inserted', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'EMPTY'))
        ..addEntity(
          const InsertEntity(id: 1, blockName: 'EMPTY', position: Vec2(8, 9)),
        );
      final opened = await rt.dwg(source, name: 'emptyblk');
      expect(opened.blocks.containsKey('EMPTY'), isTrue);
      expect(
        opened.entities.whereType<InsertEntity>().single.blockName,
        'EMPTY',
      );
    });

    test('two INSERTs of the same block stay independent', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'BOLT'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 1),
          blockName: 'BOLT',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'BOLT', position: Vec2(10, 0)),
        )
        ..addEntity(
          const InsertEntity(
            id: 3,
            blockName: 'BOLT',
            position: Vec2(20, 5),
            rotation: 0.5,
          ),
        );
      final opened = await rt.dwg(source, name: 'twoins');
      expectMatchingSnapshots(source, opened, step: 'two inserts');
      expect(opened.entities.whereType<InsertEntity>(), hasLength(2));
    });

    test('a block member on a named layer stays in the block', () async {
      final source = CadDocument()
        ..putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(3)))
        ..putBlock(const BlockRecord(name: 'TAG'))
        ..addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'NOTES'),
            start: Vec2.zero(),
            end: Vec2(2, 0),
          ),
          blockName: 'TAG',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'TAG', position: Vec2(40, 0)),
        );
      final opened = await rt.dwg(source, name: 'blklayer');
      expectMatchingSnapshots(source, opened, step: 'block layer');
      expect(
        opened.entitiesOf('TAG').whereType<LineEntity>().single.props.layer,
        'NOTES',
      );
    });

    test('an INSERT in paper space does not leak into the model', () async {
      final document = CadDocument();
      document.addLayout(
        const Layout(
          name: 'Sheet',
          blockName: '*Paper_Space',
          tabOrder: 1,
          paperWidth: 420,
          paperHeight: 297,
        ),
      );
      document.putBlock(const BlockRecord(name: 'MARK'));
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
        blockName: 'MARK',
      );
      document.addEntity(
        const InsertEntity(id: 2, blockName: 'MARK', position: Vec2(30, 20)),
        blockName: '*Paper_Space',
      );
      document.addEntity(const PointEntity(id: 3, position: Vec2(100, 0)));

      final opened = await rt.dwg(document, name: 'paperins');
      expectMatchingSnapshots(document, opened, step: 'paper insert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.position, const Vec2(30, 20));
      expect(
        sameOwner(opened.ownerOf(insert.id), '*Paper_Space'),
        isTrue,
        reason: 'paper INSERT must stay on the sheet, not *MODEL_SPACE',
      );
      expect(
        opened.entitiesOf(opened.modelSpaceBlockName).whereType<InsertEntity>(),
        isEmpty,
      );
    });

    test('a mirrored INSERT keeps a negative X scale', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'MARK'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 0)),
          blockName: 'MARK',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'MARK',
            position: Vec2(10, 0),
            scale: Vec2(-1, 1),
          ),
        );
      final opened = await rt.dwg(source, name: 'mirror');
      expectMatchingSnapshots(source, opened, step: 'mirrored insert');
      expect(
        opened.entities.whereType<InsertEntity>().single.scale.x,
        closeTo(-1, 1e-6),
      );
    });

    test('a three-level nested INSERT keeps each owner', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'A'))
        ..putBlock(const BlockRecord(name: 'B'))
        ..putBlock(const BlockRecord(name: 'C'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 1),
          blockName: 'A',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'A', position: Vec2(2, 0)),
          blockName: 'B',
        )
        ..addEntity(
          const InsertEntity(id: 3, blockName: 'B', position: Vec2(4, 0)),
          blockName: 'C',
        )
        ..addEntity(
          const InsertEntity(id: 4, blockName: 'C', position: Vec2(20, 0)),
        );
      final opened = await rt.dwg(source, name: 'nest3');
      expectMatchingSnapshots(source, opened, step: 'three-level nest');
      expect(opened.entitiesOf('B').whereType<InsertEntity>(), hasLength(1));
      expect(opened.entitiesOf('C').whereType<InsertEntity>(), hasLength(1));
    });

    test('an xref path is not yet written to the block header', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(
            const BlockRecord(
              name: 'BRACKET',
              xrefPath: r'C:\parts\bracket.dwg',
            ),
          )
          ..addEntity(
            const InsertEntity(
              id: 1,
              blockName: 'BRACKET',
              position: Vec2(5, 6),
            ),
          ),
        name: 'xref',
      );
      expect(opened.blocks.containsKey('BRACKET'), isTrue);
      expect(
        opened.blocks['BRACKET']!.xrefPath,
        isEmpty,
        reason: 'dwg_add_BLOCK_HEADER does not store xref PathName',
      );
    });

    test('an INSERT keeps an explicit indexed colour', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'DOT'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 0.5),
          blockName: 'DOT',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            props: EntityProps(color: CadColor.indexed(1)),
            blockName: 'DOT',
            position: Vec2(3, 3),
          ),
        );
      final opened = await rt.dwg(source, name: 'insaci');
      expectMatchingSnapshots(source, opened, step: 'insert ACI');
    });

    test('a MINSERT with only columns keeps the column count', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'CELL'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
          blockName: 'CELL',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'CELL',
            position: Vec2.zero(),
            columnCount: 4,
            columnSpacing: 3,
          ),
        );
      final opened = await rt.dwg(source, name: 'mcols');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.columnCount, 4);
      expect(insert.rowCount, 1);
      expect(insert.columnSpacing, closeTo(3, 1e-6));
    });

    test('a CIRCLE and SPLINE inside a named block stay there', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'BLOB'))
        ..addEntity(
          const CircleEntity(id: 1, center: Vec2.zero(), radius: 2),
          blockName: 'BLOB',
        )
        ..addEntity(
          SplineEntity(
            id: 2,
            controlPoints: Float64List.fromList([0, 0, 1, 2, 3, 2, 4, 0]),
            degree: 3,
            knots: const [0, 0, 0, 0, 1, 1, 1, 1],
          ),
          blockName: 'BLOB',
        )
        ..addEntity(
          const InsertEntity(id: 3, blockName: 'BLOB', position: Vec2(15, 0)),
        );
      final opened = await rt.dwg(source, name: 'blkmix');
      expectMatchingSnapshots(source, opened, step: 'block mix');
      expect(opened.entitiesOf('BLOB').whereType<CircleEntity>(), hasLength(1));
      expect(opened.entitiesOf('BLOB').whereType<SplineEntity>(), hasLength(1));
    });

    test('a block description is not yet written', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(
            const BlockRecord(name: 'NOTE', description: 'title block'),
          )
          ..addEntity(
            const InsertEntity(id: 1, blockName: 'NOTE', position: Vec2(1, 1)),
          ),
        name: 'blkdesc',
      );
      expect(opened.blocks.containsKey('NOTE'), isTrue);
      expect(
        opened.blocks['NOTE']!.description,
        isEmpty,
        reason: 'dwg_add_BLOCK_HEADER does not copy the preview comment',
      );
    });

    test(
      'an INSERT with one of two attributes keeps the written tag',
      () async {
        final source = CadDocument()
          ..putBlock(const BlockRecord(name: 'FORM'))
          ..addEntity(
            const AttdefEntity(
              id: 1,
              position: Vec2.zero(),
              tag: 'A',
              defaultValue: '1',
            ),
            blockName: 'FORM',
          )
          ..addEntity(
            const AttdefEntity(
              id: 2,
              position: Vec2(0, 4),
              tag: 'B',
              defaultValue: '2',
            ),
            blockName: 'FORM',
          )
          ..addEntity(
            const InsertEntity(
              id: 3,
              blockName: 'FORM',
              position: Vec2(9, 9),
              attributes: {'A': 'x'},
            ),
          );
        final opened = await rt.dwg(source, name: 'oneattr');
        final insert = opened.entities.whereType<InsertEntity>().single;
        expect(insert.attributes['A'], 'x');
        expect(
          opened.entitiesOf('FORM').whereType<AttdefEntity>(),
          hasLength(2),
        );
      },
    );

    test('a Y-mirrored INSERT keeps a negative Y scale', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'MARK'))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(2, 1)),
          blockName: 'MARK',
        )
        ..addEntity(
          const InsertEntity(
            id: 2,
            blockName: 'MARK',
            position: Vec2(8, 0),
            scale: Vec2(1, -1),
          ),
        );
      final opened = await rt.dwg(source, name: 'ymirror');
      expectMatchingSnapshots(source, opened, step: 'y-mirror');
    });

    test('a MINSERT with only rows keeps the row count', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: 'CELL'))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(1, 0)),
            blockName: 'CELL',
          )
          ..addEntity(
            const InsertEntity(
              id: 2,
              blockName: 'CELL',
              position: Vec2.zero(),
              rowCount: 4,
              rowSpacing: 3,
            ),
          ),
        name: 'mrows',
      );
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.rowCount, 4);
      expect(insert.columnCount, 1);
      expect(insert.rowSpacing, closeTo(3, 1e-6));
    });

    test('ARC, SOLID and MTEXT inside a named block stay there', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'MIX'))
        ..addEntity(
          const ArcEntity(
            id: 1,
            center: Vec2.zero(),
            radius: 2,
            startAngle: 0,
            endAngle: 1.2,
          ),
          blockName: 'MIX',
        )
        ..addEntity(
          const SolidEntity(
            id: 2,
            corners: [Vec2(3, 0), Vec2(5, 0), Vec2(5, 1), Vec2(3, 1)],
          ),
          blockName: 'MIX',
        )
        ..addEntity(
          const MTextEntity(id: 3, position: Vec2(0, 4), content: 'in'),
          blockName: 'MIX',
        )
        ..addEntity(
          const InsertEntity(id: 4, blockName: 'MIX', position: Vec2(20, 0)),
        );
      final opened = await rt.dwg(source, name: 'blkmix2');
      expectMatchingSnapshots(source, opened, step: 'block mix 2');
      expect(opened.entitiesOf('MIX').whereType<ArcEntity>(), hasLength(1));
      expect(opened.entitiesOf('MIX').whereType<SolidEntity>(), hasLength(1));
      expect(opened.entitiesOf('MIX').whereType<MTextEntity>(), hasLength(1));
    });

    test('a paper INSERT with attributes stays on the sheet', () async {
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
      document.putBlock(const BlockRecord(name: 'TITLE'));
      document.addEntity(
        const AttdefEntity(
          id: 1,
          position: Vec2.zero(),
          tag: 'NO',
          defaultValue: '01',
        ),
        blockName: 'TITLE',
      );
      document.addEntity(
        const InsertEntity(
          id: 2,
          blockName: 'TITLE',
          position: Vec2(40, 20),
          attributes: {'NO': '02'},
        ),
        blockName: '*Paper_Space',
      );
      final opened = await rt.dwg(document, name: 'patt');
      expectMatchingSnapshots(document, opened, step: 'paper attrib insert');
      final insert = opened.entities.whereType<InsertEntity>().single;
      expect(insert.attributes['NO'], '02');
      expect(sameOwner(opened.ownerOf(insert.id), '*Paper_Space'), isTrue);
    });

    test('a numbered block name survives', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: 'A1_B2'))
        ..addEntity(
          const PointEntity(id: 1, position: Vec2.zero()),
          blockName: 'A1_B2',
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'A1_B2', position: Vec2(7, 7)),
        );
      final opened = await rt.dwg(source, name: 'blknum');
      expectMatchingSnapshots(source, opened, step: 'numbered block');
      expect(opened.blocks.containsKey('A1_B2'), isTrue);
    });
  });
}
