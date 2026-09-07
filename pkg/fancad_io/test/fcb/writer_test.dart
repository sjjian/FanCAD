import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_io/src/sample_drawing.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

import '../support/roundtrip.dart';

void main() {
  final rt = Roundtrip();

  test('an empty document cannot invent entities on a write-read trip', () {
    final encoded = FcbWriter().write(CadDocument());
    final view = ByteData.sublistView(encoded);
    expect(view.getUint32(0, Endian.little), fcbMagic);
    expect(view.getUint16(4, Endian.little), fcbVersion);

    final result = FcbReader(encoded).decode();
    expect(result.entityCount, 0);
    expect(result.document.entityCount, 0);
    expect(result.diagnostics, isEmpty);
    expect(result.toString(), contains('0 entities'));
  });

  test('a second write of the empty drawing stays byte identical', () {
    final first = FcbWriter().write(CadDocument());
    final second = FcbWriter().write(FcbReader(first).decode().document);
    expect(second, first);
  });

  test('dimension source ids survive a write-read trip', () {
    final restored = rt.fcb(
      drawing(
        entities: const [
          DimensionEntity(
            id: 1,
            definitionPoints: [Vec2.zero(), Vec2(10, 0), Vec2(5, 3)],
            textPosition: Vec2(5, 3),
            measurement: 10,
            sourceIds: [7, 8],
          ),
        ],
      ),
    );
    final dim = restored.entity(1)! as DimensionEntity;
    expect(dim.sourceIds, [7, 8]);
    expect(dim.measurement, 10);
  });

  test('attdef and insert attributes survive a write-read trip', () {
    final restored = rt.fcb(
      drawing(
        blocks: const [BlockRecord(name: 'TITLE')],
        entities: const [
          InsertEntity(
            id: 2,
            blockName: 'TITLE',
            position: Vec2(10, 0),
            attributes: {'NO': 'A-01'},
          ),
        ],
        owned: const {
          'TITLE': [
            AttdefEntity(
              id: 1,
              position: Vec2(2, 3),
              tag: 'NO',
              prompt: 'Number',
              defaultValue: 'A-00',
              height: 3,
              constant: true,
            ),
          ],
        },
      ),
    );
    final def = restored.entity(1)! as AttdefEntity;
    expect(def.tag, 'NO');
    expect(def.prompt, 'Number');
    expect(def.defaultValue, 'A-00');
    expect(def.constant, isTrue);
    final insert = restored.entity(2)! as InsertEntity;
    expect(insert.attributes, {'NO': 'A-01'});
  });

  test('a distant _Oblique definition reseats onto its geometry', () {
    final restored = rt.fcb(
      drawing(
        blocks: const [BlockRecord(name: '_Oblique')],
        entities: const [
          InsertEntity(
            id: 2,
            blockName: '_Oblique',
            position: Vec2(10, 20),
            scale: Vec2(15, 15),
          ),
        ],
        owned: const {
          '_Oblique': [
            LineEntity(
              id: 1,
              start: Vec2(161481, -377618),
              end: Vec2(161481, -378589),
            ),
          ],
        },
      ),
    );
    final base = restored.blocks['_Oblique']!.basePoint;
    expect(base.x, closeTo(161481, 1));
    expect(base.y, closeTo(-378589, 1));
    expect(restored.extents.minX, closeTo(10, 1));
    expect(restored.extents.maxX, lessThan(100));
  });

  test('anonymous dimension blocks with distinct names all survive FCB', () {
    final restored = rt.fcb(
      drawing(
        blocks: const [
          BlockRecord(name: '*D\$aa', isAnonymous: true),
          BlockRecord(name: '*D\$bb', isAnonymous: true),
        ],
        entities: const [
          DimensionEntity(
            id: 3,
            blockName: '*D\$aa',
            textPosition: Vec2(5, 2),
            measurement: 10,
          ),
          DimensionEntity(
            id: 4,
            blockName: '*D\$bb',
            textPosition: Vec2(25, 2),
            measurement: 10,
          ),
        ],
        owned: const {
          '*D\$aa': [
            LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
          ],
          '*D\$bb': [
            LineEntity(id: 2, start: Vec2(20, 0), end: Vec2(30, 0)),
          ],
        },
      ),
    );
    expect(restored.blocks['*D\$aa']?.entityIds, [1]);
    expect(restored.blocks['*D\$bb']?.entityIds, [2]);
    expect(
      restored.entities.whereType<DimensionEntity>().map((d) => d.blockName),
      containsAll(['*D\$aa', '*D\$bb']),
    );
  });

  eachCase([
    (
      name: 'a multileader survives FCB with its note attached',
      content: 'QC50',
      height: 3.0,
      attachment: 4,
      painted: 'QC50',
      fontFamily: null,
    ),
    (
      name: 'a CJK font-coded note stays attached through FCB',
      content: r'{\F宋体|c134;注释}',
      height: 35.0,
      attachment: 6,
      painted: '注释',
      fontFamily: '宋体',
    ),
  ], (c) {
    final entity = rt
        .fcb(
          drawingOf(
            MLeaderEntity(
              id: 1,
              vertices: Float64List.fromList([0, 0, 8, 8, 14, 8]),
              content: c.content,
              textPosition: const Vec2(14, 8),
              textHeight: c.height,
              attachment: c.attachment,
            ),
          ),
        )
        .entities
        .whereType<MLeaderEntity>()
        .single;
    expect(entity.content, c.content);
    expect(entity.content, isNot('{'));
    expect(entity.textPosition, const Vec2(14, 8));
    expect(entity.vertices.length, 6);
    expect(entity.attachment, c.attachment);
    final sink = emit(entity);
    expect(sink.texts.single.text, c.painted);
    if (c.fontFamily != null) {
      expect(sink.texts.single.fontFamily, c.fontFamily);
    }
  });

  test('unknown fallback strokes survive FCB', () {
    final entity = rt
        .fcb(
          drawingOf(
            UnknownEntity(
              id: 2,
              originalType: 'REGION',
              proxyBounds: const Bounds2(0, 0, 4, 3),
              strokes: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3]),
              strokeCounts: const [4],
            ),
          ),
        )
        .entities
        .whereType<UnknownEntity>()
        .single;
    expect(entity.originalType, 'REGION');
    expect(entity.strokes.length, 8);
    expect(entity.strokeCounts, const [4]);
    expect(emit(entity).polylines, isNotEmpty);
  });

  // The FCB format is a contract between C and Dart, so writing a document
  // and reading it back must preserve everything the renderer and the editor
  // depend on.
  group('a mechanical part survives a write-read trip', () {
    late CadDocument original;
    late Uint8List encoded;
    late CadDocument restored;

    setUpAll(() {
      original = SampleDrawings.mechanicalPart();
      encoded = FcbWriter().write(original);
      restored = FcbReader(encoded).decode().document;
    });

    test('the buffer starts with the expected magic and version', () {
      final view = ByteData.view(encoded.buffer, encoded.offsetInBytes);
      expect(view.getUint32(0, Endian.little), fcbMagic);
      expect(view.getUint16(4, Endian.little), fcbVersion);
    });

    test('entity count and identity survive', () {
      expect(restored.entityCount, original.entityCount);
      final originalIds = original.entities.map((e) => e.id).toList()..sort();
      final restoredIds = restored.entities.map((e) => e.id).toList()..sort();
      expect(restoredIds, originalIds);
    });

    test('entity kinds survive', () {
      for (final entity in original.entities) {
        expect(
          restored.entity(entity.id)?.kind,
          entity.kind,
          reason: 'entity ${entity.id}',
        );
      }
    });

    test('geometry survives to within double precision', () {
      for (final entity in original.entities) {
        final other = restored.entity(entity.id)!;
        final a = entity.computeBounds(blocks: original);
        final b = other.computeBounds(blocks: restored);
        if (a.isEmpty && b.isEmpty) continue;
        expect(b.minX, closeTo(a.minX, 1e-9), reason: '${entity.kind} minX');
        expect(b.minY, closeTo(a.minY, 1e-9), reason: '${entity.kind} minY');
        expect(b.maxX, closeTo(a.maxX, 1e-9), reason: '${entity.kind} maxX');
        expect(b.maxY, closeTo(a.maxY, 1e-9), reason: '${entity.kind} maxY');
      }
    });

    test('entity attributes survive', () {
      for (final entity in original.entities) {
        final other = restored.entity(entity.id)!;
        expect(other.props.layer, entity.props.layer);
        expect(other.props.color, entity.props.color);
        expect(other.props.lineWeight, entity.props.lineWeight);
        expect(other.props.visible, entity.props.visible);
      }
    });

    test('the layer table survives, including line type links', () {
      expect(restored.layers.keys.toSet(), original.layers.keys.toSet());
      for (final layer in original.layers.values) {
        final other = restored.layer(layer.name)!;
        expect(other.color, layer.color, reason: layer.name);
        expect(other.lineType, layer.lineType, reason: layer.name);
        expect(other.lineWeight, layer.lineWeight, reason: layer.name);
        expect(other.visible, layer.visible, reason: layer.name);
      }
    });

    test('the line type table survives, including dash patterns', () {
      for (final lineType in original.lineTypes.values) {
        final other = restored.lineTypes[lineType.name]!;
        expect(other.pattern, lineType.pattern, reason: lineType.name);
        expect(
          other.patternLength,
          closeTo(lineType.patternLength, 1e-12),
          reason: lineType.name,
        );
      }
    });

    test('blocks keep their members and draw order', () {
      for (final block in original.blocks.values) {
        final other = restored.blocks[block.name];
        expect(other, isNotNull, reason: block.name);
        expect(other!.entityIds, block.entityIds, reason: block.name);
        expect(other.isLayoutBlock, block.isLayoutBlock, reason: block.name);
      }
    });

    test('block references still resolve, so extents match', () {
      expect(restored.extents.minX, closeTo(original.extents.minX, 1e-9));
      expect(restored.extents.minY, closeTo(original.extents.minY, 1e-9));
      expect(restored.extents.maxX, closeTo(original.extents.maxX, 1e-9));
      expect(restored.extents.maxY, closeTo(original.extents.maxY, 1e-9));
    });

    test('header variables survive', () {
      expect(restored.headerVariables[r'$INSUNITS'], '4');
      expect(restored.headerVariables[r'$LTSCALE'], '1');
    });

    test('a second round trip is byte identical', () {
      // Idempotence is the strongest available check that nothing is being
      // silently defaulted on the way through.
      expect(FcbWriter().write(restored), encoded);
    });
  });

  test('a hatch keeps the definition lines the file resolved for it', () {
    // These ride behind the boundary points in the same geometry run, so
    // the reader has to find where one ends and the other begins.
    final restored = rt.fcb(
      drawing(
        entities: [
          HatchEntity(
            id: 0,
            solid: false,
            patternName: 'ANSI31',
            patternAngle: 0.7853981633974483,
            patternScale: 5,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 23, 0, 23, 1483, 0, 1483]),
              ),
              HatchLoop(
                vertices: Float64List.fromList([4, 4, 8, 4, 8, 8, 4, 8]),
                isOuter: false,
              ),
            ],
            patternLines: const [
              HatchPatternLine(
                angle: 3.141592653589793,
                originX: 45236.355,
                originY: -40545.868,
                deltaY: -15.875,
              ),
              HatchPatternLine(angle: 0, deltaY: 3.5, dashes: [2, -1]),
            ],
          ),
        ],
      ),
    );
    final hatch = restored.entities.whereType<HatchEntity>().single;
    expect(hatch.loops, hasLength(2));
    expect(hatch.loops.last.isOuter, isFalse);
    expect(hatch.loops.first.vertices[2], closeTo(23, 1e-9));
    expect(hatch.patternLines, hasLength(2));
    expect(hatch.patternLines[0].originY, closeTo(-40545.868, 1e-9));
    expect(hatch.patternLines[0].deltaY, closeTo(-15.875, 1e-9));
    expect(hatch.patternLines[0].dashes, isEmpty);
    expect(hatch.patternLines[1].dashes, [
      closeTo(2, 1e-9),
      closeTo(-1, 1e-9),
    ]);
  });

  test('paper viewports survive a write-read trip', () {
    final document = CadDocument()
      ..addLayout(
        const Layout(
          name: 'Layout1',
          blockName: '*Paper_Space',
          tabOrder: 1,
          plotRotation: 90,
          plotWindow: Bounds2(5, 6, 55, 46),
          plotScale: 0.5,
          plotFit: true,
          plotOffsetX: 3,
          plotOffsetY: 4,
          viewports: [
            PaperViewport(
              paperBounds: Bounds2(10, 20, 210, 170),
              modelCenter: Vec2(40, 5),
              scale: 0.1,
              rotation: 0.2,
              locked: true,
              layer: '0',
              frozenLayers: ['DIMS'],
            ),
            PaperViewport(
              paperBounds: Bounds2(220, 20, 290, 90),
              modelCenter: Vec2.zero(),
              scale: 1,
              isOn: false,
            ),
          ],
        ),
      );

    final layout = rt.fcb(document).layouts.firstWhere(
      (item) => item.name == 'Layout1',
    );
    expect(layout.plotRotation, 90);
    expect(layout.plotWindow, const Bounds2(5, 6, 55, 46));
    expect(layout.plotScale, closeTo(0.5, 1e-12));
    expect(layout.plotFit, isTrue);
    expect(layout.plotOffsetX, closeTo(3, 1e-12));
    expect(layout.plotOffsetY, closeTo(4, 1e-12));
    expect(layout.viewports, hasLength(2));

    final first = layout.viewports[0];
    expect(first.paperBounds, const Bounds2(10, 20, 210, 170));
    expect(first.modelCenter, const Vec2(40, 5));
    expect(first.scale, closeTo(0.1, 1e-12));
    expect(first.rotation, closeTo(0.2, 1e-12));
    expect(first.isOn, isTrue);
    expect(first.locked, isTrue);
    expect(first.layer, '0');
    expect(first.frozenLayers, ['DIMS']);

    final second = layout.viewports[1];
    expect(second.paperBounds, const Bounds2(220, 20, 290, 90));
    expect(second.isOn, isFalse);
    expect(second.locked, isFalse);
  });

  test('dimension styles survive a write-read trip', () {
    final style = rt
        .fcb(
          drawing(
            dimStyles: const [
              DimStyleDef(
                name: 'ARCH',
                textHeight: 5,
                arrowSize: 4,
                extensionLineOffset: 1,
                extensionLineExtend: 2,
                textGap: 0.8,
                scale: 2,
                decimalPlaces: 0,
                textStyle: 'Standard',
              ),
            ],
          ),
        )
        .namedDimStyle('ARCH')!;
    expect(style.textHeight, closeTo(5, 1e-12));
    expect(style.arrowSize, closeTo(4, 1e-12));
    expect(style.extensionLineOffset, closeTo(1, 1e-12));
    expect(style.extensionLineExtend, closeTo(2, 1e-12));
    expect(style.textGap, closeTo(0.8, 1e-12));
    expect(style.scale, closeTo(2, 1e-12));
    expect(style.decimalPlaces, 0);
    expect(style.textStyle, 'Standard');
  });

  test('a polyline keeps constant width', () {
    final restored = rt.fcb(
      drawing(
        entities: [
          PolylineEntity(
            id: 0,
            vertices: Float64List.fromList([0, 0, 0, 10, 0, 0]),
            constantWidth: 0.5,
          ),
        ],
      ),
    );
    expect(
      restored.entities.whereType<PolylineEntity>().single.constantWidth,
      closeTo(0.5, 1e-12),
    );
  });

  test('a large document stays within a sane size', () {
    final document = SampleDrawings.stressTest(count: 20000);
    final bytes = FcbWriter().write(document);
    final decoded = FcbReader(bytes).decode();
    expect(decoded.entityCount, 20000);
    expect(decoded.document.entityCount, 20000);
    // A budget rather than an exact figure: the point is to notice if the
    // encoding ever regresses into something bloated.
    expect(bytes.lengthInBytes / 20000, lessThan(300));
  });
}
