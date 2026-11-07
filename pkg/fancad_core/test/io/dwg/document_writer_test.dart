import 'dart:typed_data';

import 'package:fancad_core/src/core.dart';
import 'package:fancad_core/src/io/dwg/aci_palette.dart';
import 'package:fancad_core/src/io/dwg/dwg_document.dart';
import 'package:fancad_core/src/io/dwg/dwg_reader.dart';
import 'package:fancad_core/src/io/dwg/writer/cad_document_writer.dart';
import 'package:fancad_core/src/io/dwg/writer/template_layout.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  group('CadDocument R2000 writer', () {
    test('round-trips the supported entity types', () {
      final document = drawing(
        layers: const [
          LayerDef(name: 'Walls', color: CadColor.indexed(1)),
          LayerDef(name: 'Dims', color: CadColor.indexed(2)),
        ],
        entities: [
          const LineEntity(
            id: 0,
            props: EntityProps(layer: 'Walls'),
            start: Vec2.zero(),
            end: Vec2(10, 5),
          ),
          const CircleEntity(id: 0, center: Vec2(20, 20), radius: 5),
          const ArcEntity(
            id: 0,
            center: Vec2(40, 20),
            radius: 5,
            startAngle: 0,
            endAngle: 1.5,
          ),
          const EllipseEntity(
            id: 0,
            center: Vec2(60, 20),
            majorAxis: Vec2(10, 0),
            ratio: 0.5,
          ),
          const PointEntity(id: 0, position: Vec2(1, 2)),
          const TextEntity(
            id: 0,
            props: EntityProps(layer: 'Dims'),
            position: Vec2(10, 30),
            content: 'Hello',
            height: 4,
          ),
          PolylineEntity.fromPoints(
            id: 0,
            points: const [Vec2(0, 0), Vec2(10, 0), Vec2(10, 10)],
            closed: true,
          ),
          const SolidEntity(
            id: 0,
            corners: [Vec2(0, 0), Vec2(5, 0), Vec2(5, 5), Vec2(0, 5)],
          ),
          SplineEntity(
            id: 0,
            knots: [0, 0, 0, 0, 1, 1, 1, 1],
            controlPoints: Float64List.fromList([0, 0, 10, 20, 20, 20, 30, 0]),
          ),
          const MTextEntity(id: 0, position: Vec2(10, 40), content: 'note'),
          const AttribEntity(
            id: 0,
            position: Vec2(10, 50),
            tag: 'TAG',
            value: 'Value',
          ),
          const AttdefEntity(
            id: 0,
            position: Vec2(10, 60),
            tag: 'TAG2',
            prompt: 'Prompt?',
            defaultValue: 'Default',
          ),
          const RayEntity(id: 0, origin: Vec2.zero(), direction: Vec2(1, 1)),
          const XLineEntity(id: 0, origin: Vec2(5, 5), direction: Vec2(0, 1)),
          LeaderEntity(
            id: 0,
            vertices: Float64List.fromList([0, 0, 10, 10, 20, 10]),
          ),
          const DimensionEntity(
            id: 0,
            definitionPoints: [Vec2(0, 0), Vec2(10, 0), Vec2(5, 5)],
            textPosition: Vec2(5, 6),
            measurement: 10,
            dimensionType: 0,
          ),
          HatchEntity(
            id: 0,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
              ),
            ],
          ),
          const ImageEntity(
            id: 0,
            reference: 'logo.png',
            origin: Vec2(50, 50),
            uVector: Vec2(20, 0),
            vVector: Vec2(0, 10),
          ),
          MLeaderEntity(
            id: 0,
            vertices: Float64List.fromList([0, 0, 10, 10, 20, 10]),
            content: 'Callout',
            textPosition: const Vec2(20, 10),
          ),
          WipeoutEntity(
            id: 0,
            origin: const Vec2(100, 100),
            uVector: const Vec2(20, 0),
            vVector: const Vec2(0, 10),
            clipVertices: Float64List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
          ),
        ],
      );

      expect(canWriteR2000Document(document), isTrue);
      final bytes = writeR2000Document(document);
      final parsed = DwgReader.readBytes(bytes);
      expect(parsed.entities, hasLength(20));
      expect(
        parsed.entities.map((entity) => entity.typeName),
        containsAll([
          'LINE',
          'CIRCLE',
          'ARC',
          'ELLIPSE',
          'POINT',
          'TEXT',
          'LWPOLYLINE',
          'SOLID',
          'SPLINE',
          'MTEXT',
          'ATTRIB',
          'ATTDEF',
          'RAY',
          'XLINE',
          'LEADER',
          'DIMENSION_LINEAR',
          'HATCH',
          'IMAGE',
          'MULTILEADER',
          'WIPEOUT',
        ]),
      );

      final reopened = dwgToDocument(parsed);
      expect(reopened.entities, hasLength(20));
      expect(reopened.entities.whereType<LineEntity>().single.end, Vec2(10, 5));
      expect(reopened.entities.whereType<TextEntity>().single.content, 'Hello');
      expect(
        reopened.entities.whereType<TextEntity>().single.props.layer,
        'Dims',
      );
      expect(
        reopened.layers.values.map((layer) => layer.name),
        containsAll(['0', 'Walls', 'Dims']),
      );
      expect(
        reopened.entities.whereType<DimensionEntity>().single.measurement,
        10,
      );
      expect(reopened.entities.whereType<HatchEntity>(), hasLength(1));
      expect(
        reopened.entities.whereType<ImageEntity>().single.reference,
        'logo.png',
      );
      final mleader = reopened.entities.whereType<MLeaderEntity>().single;
      expect(mleader.content, 'Callout');
      expect(mleader.vertices, hasLength(6));
      expect(mleader.textPosition, const Vec2(20, 10));
      final wipeout = reopened.entities.whereType<WipeoutEntity>().single;
      expect(wipeout.origin, const Vec2(100, 100));
      expect(wipeout.uVector, const Vec2(20, 0));
      expect(wipeout.vVector, const Vec2(0, 10));
      expect(wipeout.clipVertices, [0, 0, 1, 0, 1, 1, 0, 1]);
    });

    test('writes block definitions and inserts', () {
      final document = drawing(
        blocks: const [
          BlockRecord(name: 'B', basePoint: Vec2(1, 2), entityIds: []),
        ],
        entities: const [
          InsertEntity(
            id: 0,
            blockName: 'B',
            position: Vec2(5, 5),
            scale: Vec2(2, 2),
            rotation: 0.5,
            attributes: {'TAG': 'Custom'},
          ),
        ],
        owned: {
          'B': [
            const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
            const CircleEntity(id: 0, center: Vec2(5, 5), radius: 3),
            const AttdefEntity(
              id: 0,
              position: Vec2(1, 1),
              tag: 'TAG',
              defaultValue: 'Default',
            ),
          ],
        },
      );
      expect(canWriteR2000Document(document), isTrue);
      final bytes = writeR2000Document(document);
      final parsed = DwgReader.readBytes(bytes);
      expect(parsed.blocks.values.map((block) => block.name), contains('B'));
      final insert = parsed.entities.firstWhere(
        (entity) => entity.typeName == 'INSERT',
      );
      expect(insert.blockHandle, isNonZero);
      expect(parsed.blocks[insert.blockHandle]?.name, 'B');
      final blockEntities = parsed.entities.where(
        (entity) =>
            entity.ownerHandle == insert.blockHandle &&
            entity.typeName != 'ATTRIB' &&
            entity.typeName != 'SEQEND',
      );
      expect(blockEntities, hasLength(3));
      final attrib = parsed.entities.firstWhere(
        (entity) => entity.typeName == 'ATTRIB',
      );
      expect(attrib.text, 'Custom');
      expect(attrib.ownerHandle, insert.handle);

      final reopened = dwgToDocument(parsed);
      expect(reopened.blocks.keys, contains('B'));
      expect(reopened.blocks['B']!.basePoint, Vec2(1, 2));
      expect(reopened.entitiesOf('B'), hasLength(3));
      final reopenedInsert = reopened.entities.whereType<InsertEntity>().single;
      expect(reopenedInsert.attributes['TAG'], 'Custom');
    });

    test('writes named line types and assigns them', () {
      final document = CadDocument()
        ..putLineType(
          const LineTypeDef(
            name: 'DASHED',
            description: 'Dashed',
            pattern: [12, -6],
            patternLength: 18,
          ),
        )
        ..putLayer(const LayerDef(name: 'Dashed', lineType: 'DASHED'))
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(layer: 'Dashed', lineType: 'DASHED'),
            start: Vec2.zero(),
            end: Vec2(10, 0),
          ),
        );
      expect(canWriteR2000Document(document), isTrue);
      final bytes = writeR2000Document(document);
      final layout = R2000TemplateLayout.read(bytes);
      expect(layout.lineTypes.keys, contains('DASHED'));
      final parsed = DwgReader.readBytes(bytes);
      expect(parsed.entities, hasLength(1));
      expect(parsed.entities.single.text, isEmpty);
    });

    test('writes named text styles', () {
      final document = CadDocument()
        ..putTextStyle(
          const TextStyleDef(
            name: 'RomanS',
            fontFamily: 'romans',
            widthFactor: 0.8,
          ),
        )
        ..addEntity(
          const TextEntity(
            id: 0,
            position: Vec2.zero(),
            content: 'Hello',
            styleName: 'RomanS',
          ),
        );
      expect(canWriteR2000Document(document), isTrue);
      final layout = R2000TemplateLayout.read(writeR2000Document(document));
      expect(layout.textStyles.keys, contains('ROMANS'));
      expect(layout.textStyles.keys, contains('STANDARD'));
    });

    test('writes paper-space entities', () {
      final document =
          drawing(
              entities: const [
                LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
              ],
            )
            ..putBlock(
              const BlockRecord(name: '*Paper_Space0', isLayoutBlock: true),
            )
            ..addLayout(const Layout(name: 'Sheet', blockName: '*Paper_Space0'))
            ..addEntity(
              const TextEntity(id: 0, position: Vec2(10, 10), content: 'Paper'),
              blockName: '*Paper_Space0',
            );

      expect(canWriteR2000Document(document), isTrue);
      final parsed = DwgReader.readBytes(writeR2000Document(document));
      expect(
        parsed.entities.where((entity) => entity.entmode == 1),
        hasLength(1),
      );
      expect(
        parsed.entities.where((entity) => entity.entmode == 2),
        hasLength(1),
      );
    });

    test('round-trips a MINSERT block array', () {
      final document = drawing(
        blocks: const [BlockRecord(name: 'COLUMN')],
        owned: {
          'COLUMN': [
            const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 1)),
          ],
        },
        entities: const [
          InsertEntity(
            id: 0,
            blockName: 'COLUMN',
            position: Vec2(5, 5),
            columnCount: 3,
            rowCount: 2,
            columnSpacing: 10,
            rowSpacing: 20,
          ),
        ],
      );
      expect(canWriteR2000Document(document), isTrue);
      final reopened = dwgToDocument(
        DwgReader.readBytes(writeR2000Document(document)),
      );
      final insert = reopened.entities.whereType<InsertEntity>().single;
      expect(insert.columnCount, 3);
      expect(insert.rowCount, 2);
      expect(insert.columnSpacing, 10);
      expect(insert.rowSpacing, 20);
    });

    test('round-trips a text style name and font', () {
      final document = drawing(
        textStyles: const [
          TextStyleDef(name: 'TITLE', fontFamily: 'arial.ttf'),
        ],
        entities: const [
          TextEntity(
            id: 0,
            position: Vec2.zero(),
            content: 'Title',
            styleName: 'TITLE',
          ),
        ],
      );
      expect(canWriteR2000Document(document), isTrue);
      final reopened = dwgToDocument(
        DwgReader.readBytes(writeR2000Document(document)),
      );
      expect(
        (reopened.entities.whereType<TextEntity>().single).styleName,
        'TITLE',
      );
      expect(reopened.textStyles['TITLE']?.fontFamily, 'arial.ttf');
    });

    test('preserves entity linetype scale, weight and colour', () {
      final document = drawing(
        entities: const [
          LineEntity(
            id: 0,
            props: EntityProps(
              lineTypeScale: 2.5,
              lineWeight: 50,
              color: CadColor.indexed(3),
            ),
            start: Vec2.zero(),
            end: Vec2(10, 0),
          ),
        ],
      );
      expect(canWriteR2000Document(document), isTrue);
      final line = DwgReader.readBytes(
        writeR2000Document(document),
      ).entities.single;
      expect(line.lineTypeScale, closeTo(2.5, 1e-12));
      expect(line.lineWeight, 50);
      expect(line.colorIndex, 3);
    });

    test('approximates a true colour with an ACI on R2000', () {
      final document = drawing(
        entities: const [
          LineEntity(
            id: 0,
            props: EntityProps(color: CadColor.rgb(0x123456)),
            start: Vec2.zero(),
            end: Vec2(10, 0),
          ),
        ],
      );
      final line = DwgReader.readBytes(
        writeR2000Document(document),
      ).entities.single;
      expect(line.colorIndex, nearestAciIndexForRgb(0x123456));
      expect(line.colorIndex, isNot(256));
    });

    test('keeps an unused dashed linetype through a save', () {
      final document = drawing(
        lineTypes: const [
          LineTypeDef(name: 'DASHED', pattern: [5, -5], patternLength: 10),
        ],
      );
      expect(canWriteR2000Document(document), isTrue);
      final reopened = dwgToDocument(
        DwgReader.readBytes(writeR2000Document(document)),
      );
      final dashed = reopened.lineTypes['DASHED'];
      expect(dashed, isNotNull);
      expect(dashed!.pattern, [5, -5]);
      expect(dashed.patternLength, 10);
    });

    test('round-trips a layer line weight through the flag word', () {
      final document = drawing(
        layers: const [LayerDef(name: 'Walls', lineWeight: 50)],
      );
      expect(canWriteR2000Document(document), isTrue);
      final parsed = DwgReader.readBytes(writeR2000Document(document));
      expect(
        parsed.layers.values
            .firstWhere((layer) => layer.name == 'Walls')
            .lineWeight,
        11,
      );
      final reopened = dwgToDocument(
        DwgReader.readBytes(writeR2000Document(document)),
      );
      expect(reopened.layers['Walls']!.lineWeight, 50);
    });

    test('round-trips a non-Standard dimension style', () {
      final document = drawing(
        dimStyles: const [
          DimStyleDef(
            name: 'ISO-25',
            textHeight: 3,
            arrowSize: 4,
            decimalPlaces: 3,
          ),
        ],
        entities: const [
          DimensionEntity(
            id: 0,
            styleName: 'ISO-25',
            definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(10, 5)],
          ),
        ],
      );
      expect(canWriteR2000Document(document), isTrue);
      final reopened = dwgToDocument(
        DwgReader.readBytes(writeR2000Document(document)),
      );
      expect(
        reopened.entities.whereType<DimensionEntity>().single.styleName,
        'ISO-25',
      );
      final style = reopened.dimStyles['ISO-25'];
      expect(style, isNotNull);
      expect(style!.textHeight, 3);
      expect(style.arrowSize, 4);
      expect(style.decimalPlaces, 3);
    });

    test('rejects a sheet whose viewport would be lost', () {
      final document =
          drawing(
            blocks: const [
              BlockRecord(name: '*Paper_Space0', isLayoutBlock: true),
            ],
          )..addLayout(
            const Layout(
              name: 'Sheet',
              blockName: '*Paper_Space0',
              viewports: [
                PaperViewport(
                  paperBounds: Bounds2(0, 0, 100, 100),
                  modelCenter: Vec2.zero(),
                ),
              ],
            ),
          );
      expect(canWriteR2000Document(document), isFalse);
    });

    test('approximates a true-colour layer with an ACI on R2000', () {
      final document = drawing(
        layers: const [LayerDef(name: 'RGB', color: CadColor.rgb(0x123456))],
      );
      expect(canWriteR2000Document(document), isTrue);
      final reopened = dwgToDocument(
        DwgReader.readBytes(writeR2000Document(document)),
      );
      expect(
        reopened.layers['RGB']!.color,
        CadColor.indexed(nearestAciIndexForRgb(0x123456)),
      );
    });

    test('rejects customising a table record baked into the template', () {
      final style = drawing(
        textStyles: const [
          TextStyleDef(name: 'Standard', fontFamily: 'arial.ttf'),
        ],
      );
      expect(canWriteR2000Document(style), isFalse);
      final dashed = drawing(
        lineTypes: const [
          LineTypeDef(name: 'Continuous', pattern: [5, -5], patternLength: 10),
        ],
      );
      expect(canWriteR2000Document(dashed), isFalse);
    });

    test('rejects an entity with transparency', () {
      final document = drawing(
        entities: const [
          LineEntity(
            id: 0,
            start: Vec2.zero(),
            end: Vec2(5, 0),
            props: EntityProps(transparency: 40),
          ),
        ],
      );
      expect(canWriteR2000Document(document), isFalse);
    });

    test('rejects header settings the template cannot store', () {
      final dashed = drawing()..setHeaderVariable(r'$LTSCALE', '20');
      expect(canWriteR2000Document(dashed), isFalse);
      final points = drawing()..setHeaderVariable(r'$PDMODE', '34');
      expect(canWriteR2000Document(points), isFalse);
      final same = drawing()..setHeaderVariable(r'$LTSCALE', '1');
      expect(canWriteR2000Document(same), isTrue);
    });

    test('rejects documents the writer cannot represent', () {
      final document = drawing(
        entities: const [
          InsertEntity(id: 0, blockName: 'B', position: Vec2.zero()),
        ],
      );
      expect(canWriteR2000Document(document), isFalse);
    });
  });
}
