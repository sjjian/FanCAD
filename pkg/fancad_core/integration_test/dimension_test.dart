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
  nativeGroup('DWG dimension', () {
    late Roundtrip rt;

    setUpAll(() {
      rt = Roundtrip();
    });

    test(
      'linear definition points stay off the text so a host can regen ticks',
      () async {
        const x1 = Vec2(50, 50);
        const x2 = Vec2(60, 50);
        const def = Vec2(55, 54);
        const text = Vec2(55, 58);
        const dimLayer = EntityProps(layer: '标注线');

        final opened = await rt.dwg(
          drawing(
            layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
            blocks: const [BlockRecord(name: '*D1', isAnonymous: true)],
            entities: const [
              DimensionEntity(
                id: 2,
                props: dimLayer,
                blockName: '*D1',
                measurement: 10,
                definitionPoints: [x1, x2, def],
                textPosition: text,
              ),
            ],
            owned: const {
              '*D1': [LineEntity(id: 1, props: dimLayer, start: x1, end: x2)],
            },
          ),
          name: 'dimpts',
        );

        final dim = opened.entities.whereType<DimensionEntity>().single;
        expect(dim.definitionPoints, hasLength(3));
        expect(dim.definitionPoints[0], closeVec(x1));
        expect(dim.definitionPoints[1], closeVec(x2));
        expect(dim.definitionPoints[2], closeVec(def));
        expect(
          dim.definitionPoints.every(
            (point) =>
                (point.x - text.x).abs() < 1e-6 &&
                (point.y - text.y).abs() < 1e-6,
          ),
          isFalse,
          reason: 'GstarCAD regenerates ticks from the origins, not the note',
        );

        final dimBlock = opened.blocks.keys.cast<String>().firstWhere(
          (name) => name.toUpperCase() == '*D1',
          orElse: () => '',
        );
        expect(dimBlock, isNotEmpty);
        expect(opened.blocks[dimBlock]!.isAnonymous, isTrue);
        expect(
          dim.dimensionType & 32,
          isNot(0),
          reason: 'DXF 32 marks the *D as this dimension\'s exclusive block',
        );
        expect(opened.entitiesOf(dimBlock).whereType<LineEntity>(), isNotEmpty);
      },
      timeout: Roundtrip.timeout,
    );

    test(
      'a CJK font-coded dimension note still paints the glyphs',
      () async {
        const raw = r'{\F宋体|c134;型材1}';
        const dimLayer = EntityProps(layer: '标注线');
        final opened = await rt.dwg(
          drawing(
            layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
            blocks: const [BlockRecord(name: '*D1', isAnonymous: true)],
            entities: const [
              DimensionEntity(
                id: 2,
                props: dimLayer,
                blockName: '*D1',
                measurement: 10,
                overrideText: raw,
                definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
                textPosition: Vec2(5, 3),
              ),
            ],
            owned: const {
              '*D1': [
                MTextEntity(
                  id: 1,
                  position: Vec2(5, 3),
                  content: raw,
                  height: 2.5,
                ),
              ],
            },
          ),
          name: 'dimcjk',
        );

        final dim = opened.entities.whereType<DimensionEntity>().single;
        final sink = emit(dim, document: opened);
        final painted = sink.texts.map((item) => item.text).join();
        expect(painted, contains('型材1'));
        expect(
          painted.contains(r'\F') ||
              painted.contains(r'\f') ||
              painted.contains('{'),
          isFalse,
          reason: 'MTEXT font codes must not remain in the painted string',
        );
      },
      timeout: Roundtrip.timeout,
    );

    test(
      'an aligned dimension keeps its *D block and first two points',
      () async {
        final source = CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 6)),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 1,
              measurement: 10,
              definitionPoints: [Vec2(0, 0), Vec2(8, 6), Vec2(4, 8)],
              textPosition: Vec2(4, 8),
            ),
          );
        final opened = await rt.dwg(source, name: 'dimalign');
        final dim = opened.entities.whereType<DimensionEntity>().single;
        expect(dim.blockName, '*D1');
        expect(dim.measurement, closeTo(10, 1e-6));
        expect(dim.definitionPoints, hasLength(3));
        expect(dim.definitionPoints[1], const Vec2(8, 6));
        expect(dim.definitionPoints[2], const Vec2(4, 8));
        expect(opened.entitiesOf('*D1').whereType<LineEntity>(), hasLength(1));
      },
    );

    test('a radius dimension keeps its *D block and measurement', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const CircleEntity(id: 1, center: Vec2.zero(), radius: 5),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 4,
              measurement: 5,
              definitionPoints: [Vec2(0, 0), Vec2(5, 0)],
              textPosition: Vec2(6, 1),
            ),
          ),
        name: 'dimrad',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(5, 1e-6));
      expect(opened.entitiesOf('*D1').whereType<CircleEntity>(), hasLength(1));
    });

    test('a diameter dimension keeps its *D block and measurement', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const CircleEntity(id: 1, center: Vec2.zero(), radius: 4),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 3,
              measurement: 8,
              definitionPoints: [Vec2(-4, 0), Vec2(4, 0)],
              textPosition: Vec2(0, 2),
            ),
          ),
        name: 'dimdia',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(8, 1e-6));
    });

    test('an angular dimension keeps its *D block', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(4, 0)),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 5,
              measurement: 1.5708,
              definitionPoints: [Vec2(4, 0), Vec2(0, 4), Vec2(0, 0)],
              textPosition: Vec2(2, 2),
            ),
          ),
        name: 'dimang',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(opened.entitiesOf('*D1').whereType<LineEntity>(), hasLength(1));
    });

    test('an ordinate dimension keeps its *D block', () async {
      final opened = await rt.dwg(
        CadDocument()
          ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
          ..addEntity(
            const LineEntity(id: 1, start: Vec2(0, 0), end: Vec2(0, 8)),
            blockName: '*D1',
          )
          ..addEntity(
            const DimensionEntity(
              id: 2,
              blockName: '*D1',
              dimensionType: 6,
              measurement: 8,
              definitionPoints: [Vec2(0, 0), Vec2(0, 8)],
              textPosition: Vec2(2, 8),
            ),
          ),
        name: 'dimord',
      );
      final dim = opened.entities.whereType<DimensionEntity>().single;
      expect(dim.blockName, '*D1');
      expect(dim.measurement, closeTo(8, 1e-6));
    });

    test('a CJK font-coded dimension note still paints the glyphs', () async {
      const raw = r'{\F宋体|c134;型材1}';
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(5, 3),
            content: raw,
            height: 2.5,
          ),
          blockName: '*D1',
        )
        ..addEntity(
          const DimensionEntity(
            id: 2,
            blockName: '*D1',
            measurement: 10,
            overrideText: raw,
            definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 3)],
            textPosition: Vec2(5, 3),
          ),
        );
      final opened = await rt.dwg(source, name: 'dimcjk');
      final sink = PolylineSink();
      opened.entities.whereType<DimensionEntity>().single.emit(
        opened.emitContext(tolerance: 0.1),
        sink,
      );
      expect(sink.texts, isNotEmpty);
      expect(sink.texts.map((item) => item.text).join(), contains('型材1'));
      expect(sink.texts.every((item) => !item.text.contains(r'\F')), isTrue);
    });

    test('dimension override text survives', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          blockName: '*D1',
        )
        ..addEntity(
          const DimensionEntity(
            id: 2,
            blockName: '*D1',
            measurement: 10,
            overrideText: '10 mm',
            definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 3)],
            textPosition: Vec2(5, 3),
          ),
        );
      final opened = await rt.dwg(source, name: 'dimtext');
      expectMatchingSnapshots(source, opened, step: 'dim override');
      expect(
        opened.entities.whereType<DimensionEntity>().single.overrideText,
        '10 mm',
      );
    });

    test('two *D blocks keep their own members', () async {
      final source = CadDocument()
        ..putBlock(const BlockRecord(name: '*D1', isAnonymous: true))
        ..putBlock(const BlockRecord(name: '*D2', isAnonymous: true))
        ..addEntity(
          const LineEntity(id: 1, start: Vec2(0, 0), end: Vec2(10, 0)),
          blockName: '*D1',
        )
        ..addEntity(
          const LineEntity(id: 2, start: Vec2(0, 1), end: Vec2(20, 1)),
          blockName: '*D2',
        )
        ..addEntity(
          const DimensionEntity(
            id: 3,
            blockName: '*D1',
            measurement: 10,
            definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 2)],
            textPosition: Vec2(5, 2),
          ),
        )
        ..addEntity(
          const DimensionEntity(
            id: 4,
            blockName: '*D2',
            measurement: 20,
            definitionPoints: [Vec2(0, 1), Vec2(20, 1), Vec2(10, 3)],
            textPosition: Vec2(10, 3),
          ),
        );
      final opened = await rt.dwg(source, name: 'twodim');
      expectMatchingSnapshots(source, opened, step: 'two *D blocks');
      expect(opened.entitiesOf('*D1').whereType<LineEntity>().single.end.x, 10);
      expect(opened.entitiesOf('*D2').whereType<LineEntity>().single.end.x, 20);
    });

    test(
      'a title-block INSERT stays in model space beside an overlapping *D',
      () async {
        const dimLayer = EntityProps(layer: '标注线');
        final source = drawing(
          layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
          blocks: const [
            BlockRecord(name: 'bk'),
            BlockRecord(name: '*D1', isAnonymous: true),
          ],
          entities: [
            const InsertEntity(id: 4, blockName: 'bk', position: Vec2.zero()),
            const DimensionEntity(
              id: 5,
              props: dimLayer,
              blockName: '*D1',
              measurement: 10,
              definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 4)],
              textPosition: Vec2(5, 8),
            ),
            LeaderEntity(
              id: 6,
              vertices: Float64List.fromList([0, 20, 12, 28]),
            ),
            HatchEntity(
              id: 7,
              loops: [
                HatchLoop(
                  vertices: Float64List.fromList([
                    40,
                    0,
                    50,
                    0,
                    50,
                    10,
                    40,
                    10,
                  ]),
                ),
              ],
            ),
          ],
          owned: const {
            'bk': [
              LineEntity(id: 1, start: Vec2.zero(), end: Vec2(80, 0)),
              LineEntity(id: 2, start: Vec2.zero(), end: Vec2(0, 40)),
              MTextEntity(
                id: 3,
                position: Vec2(10, 10),
                content: 'XDFB-J15',
                height: 2.5,
              ),
            ],
            '*D1': [
              LineEntity(
                id: 10,
                props: dimLayer,
                start: Vec2.zero(),
                end: Vec2(10, 0),
              ),
            ],
          },
        );

        final opened = await rt.dwg(source, name: 'title');
        final insert = opened.entities.whereType<InsertEntity>().singleWhere(
          (entity) => entity.blockName == 'bk',
        );
        expectOwner(opened, insert, opened.modelSpaceBlockName);

        for (final entity in opened.entities.whereType<InsertEntity>()) {
          if (entity.blockName != 'bk') continue;
          final owner = opened.ownerOf(entity.id) ?? '';
          expect(owner.startsWith('*D'), isFalse);
        }

        for (final entity in opened.entities) {
          if (entity is! LeaderEntity && entity is! HatchEntity) continue;
          final owner = opened.ownerOf(entity.id) ?? '';
          expect(
            owner.startsWith('*D'),
            isFalse,
            reason: '${entity.kind}#${entity.id}',
          );
        }
      },
      timeout: Roundtrip.timeout,
    );

    test('two DIMENSION entities keep distinct *D blocks', () async {
      const dimLayer = EntityProps(layer: '标注线');
      final source = drawing(
        layers: const [LayerDef(name: '标注线', color: CadColor.indexed(1))],
        blocks: const [
          BlockRecord(name: '*D1', isAnonymous: true),
          BlockRecord(name: '*D2', isAnonymous: true),
        ],
        entities: const [
          DimensionEntity(
            id: 1,
            props: dimLayer,
            blockName: '*D1',
            measurement: 10,
            definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 4)],
            textPosition: Vec2(5, 8),
          ),
          DimensionEntity(
            id: 2,
            props: dimLayer,
            blockName: '*D2',
            measurement: 20,
            definitionPoints: [Vec2(30, 0), Vec2(50, 0), Vec2(40, 4)],
            textPosition: Vec2(40, 8),
          ),
        ],
        owned: const {
          '*D1': [
            LineEntity(
              id: 3,
              props: dimLayer,
              start: Vec2.zero(),
              end: Vec2(10, 0),
            ),
          ],
          '*D2': [
            LineEntity(
              id: 4,
              props: dimLayer,
              start: Vec2(30, 0),
              end: Vec2(50, 0),
            ),
          ],
        },
      );

      final opened = await rt.dwg(source, name: 'twodim');
      final dims = opened.entities.whereType<DimensionEntity>().toList();
      expect(dims, hasLength(2));
      expect(dims[0].blockName, isNotEmpty);
      expect(dims[1].blockName, isNot(dims[0].blockName));
    }, timeout: Roundtrip.timeout);

    test(
      'an unreferenced *D does not take model-space leaders',
      () async {
        final source = drawing(
          blocks: const [BlockRecord(name: '*D9', isAnonymous: true)],
          entities: [
            LeaderEntity(
              id: 1,
              vertices: Float64List.fromList([0, 20, 12, 28]),
            ),
          ],
          owned: const {
            '*D9': [
              LineEntity(id: 2, start: Vec2(100, 100), end: Vec2(110, 100)),
            ],
          },
        );

        final opened = await rt.dwg(source, name: 'orphand');
        final leader = opened.entities.whereType<LeaderEntity>().single;
        expectOwner(opened, leader, opened.modelSpaceBlockName);
        final referenced = {
          for (final entity in opened.entities)
            if (entity is DimensionEntity && entity.blockName.isNotEmpty)
              entity.blockName,
        };
        expect(referenced, isEmpty);
        expect(
          opened
              .entitiesOf(opened.modelSpaceBlockName)
              .whereType<LeaderEntity>(),
          isNotEmpty,
        );
      },
      timeout: Roundtrip.timeout,
    );
  });
}
