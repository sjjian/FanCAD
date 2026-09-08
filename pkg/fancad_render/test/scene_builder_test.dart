import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(1000, 800);

  /// A square grid of identically styled lines, ten drawing units apart.
  ///
  /// Square rather than a long strip so that fitting it to a landscape viewport
  /// leaves the lines several pixels long, which is what keeps them out of the
  /// renderer's collapse-to-a-pixel path.
  CadDocument gridDocument(int count, {String layer = '0'}) {
    final document = CadDocument()
      ..putLayer(LayerDef(name: layer, color: const CadColor.indexed(2)));
    final columns = math.sqrt(count).ceil();
    final entities = <CadEntity>[
      for (var i = 0; i < count; i++)
        LineEntity(
          id: i + 1,
          props: EntityProps(layer: layer),
          start: Vec2((i % columns) * 10, (i ~/ columns) * 10),
          end: Vec2((i % columns) * 10 + 8, (i ~/ columns) * 10 + 8),
        ),
    ];
    for (final entity in entities) {
      document.registerImportedEntity(entity);
    }
    document
      ..putBlock(
        BlockRecord(
          name: document.modelSpaceBlockName,
          entityIds: [for (final entity in entities) entity.id],
          isLayoutBlock: true,
        ),
      )
      ..reindex();
    return document;
  }

  SceneBuilder newBuilder() => SceneBuilder(palette: AciPalette.dark);

  group('SceneBuilder', () {
    test('merges same-styled geometry into one batch', () {
      final document = gridDocument(500);
      final view = CadViewport.fit(document.extents, size);
      final scene = newBuilder().build(document, view);

      expect(scene.entityCount, greaterThan(0));
      // 500 lines, one colour, one line weight: exactly one draw call.
      expect(scene.lineBatches, hasLength(1));
      expect(scene.lineBatches.single.segmentCount, scene.segmentCount);
    });

    test('splits batches by colour', () {
      final document = CadDocument();
      for (var i = 0; i < 30; i++) {
        document.addEntity(
          LineEntity(
            id: 0,
            props: EntityProps(color: CadColor.indexed(1 + i % 3)),
            start: Vec2(i.toDouble(), 0),
            end: Vec2(i.toDouble(), 10),
          ),
        );
      }
      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );
      expect(scene.lineBatches, hasLength(3));
    });

    test('culls geometry outside the overscanned region', () {
      final document = gridDocument(2500);
      // Zoomed in on one corner of a 50 by 50 grid.
      const view = CadViewport(center: Vec2(30, 30), scale: 20, size: size);
      final scene = newBuilder().build(document, view);
      expect(scene.entityCount, greaterThan(0));
      expect(scene.entityCount, lessThan(200));
    });

    test('hidden layers contribute nothing', () {
      final document = gridDocument(50, layer: 'OFF')
        ..putLayer(
          const LayerDef(name: 'OFF', visible: false),
        );
      final scene = newBuilder().build(
        document,
        const CadViewport(center: Vec2(30, 30), scale: 4, size: size),
      );
      expect(scene.entityCount, 0);
      expect(scene.lineBatches, isEmpty);
    });

    test('a frozen layer is treated as off', () {
      final document = gridDocument(50, layer: 'FROZEN')
        ..putLayer(const LayerDef(name: 'FROZEN', frozen: true));
      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );
      expect(scene.entityCount, 0);
    });

    test('layer isolation restricts what is drawn', () {
      final document = CadDocument()
        ..putLayer(const LayerDef(name: 'A'))
        ..putLayer(const LayerDef(name: 'B'))
        ..addEntity(
          LineEntity(
            id: 0,
            props: const EntityProps(layer: 'A'),
            start: const Vec2.zero(),
            end: const Vec2(10, 10),
          ),
        )
        ..addEntity(
          LineEntity(
            id: 0,
            props: const EntityProps(layer: 'B'),
            start: const Vec2.zero(),
            end: const Vec2(10, -10),
          ),
        );
      final view = CadViewport.fit(document.extents, size);
      expect(newBuilder().build(document, view).entityCount, 2);
      expect(
        newBuilder().build(document, view, onlyLayers: {'A'}).entityCount,
        1,
      );
    });

    test('dashed line types become multiple segments', () {
      final document = CadDocument()
        ..putLineType(
          const LineTypeDef(
            name: 'DASHED',
            pattern: [5, -5],
            patternLength: 10,
          ),
        )
        ..putLayer(
          const LayerDef(name: 'D', lineType: 'DASHED'),
        )
        ..addEntity(
          LineEntity(
            id: 0,
            props: const EntityProps(layer: 'D'),
            start: const Vec2.zero(),
            end: const Vec2(200, 0),
          ),
        );
      final scene = newBuilder().build(
        document,
        const CadViewport(center: Vec2(100, 0), scale: 4, size: size),
      );
      // A 200 unit line at 4 pixels per unit with a 10 unit pattern is 20
      // dashes, not one segment.
      expect(scene.segmentCount, greaterThan(10));
    });

    test('a dash pattern too fine to see is drawn solid', () {
      final document = CadDocument()
        ..putLineType(
          const LineTypeDef(
            name: 'FINE',
            pattern: [0.01, -0.01],
            patternLength: 0.02,
          ),
        )
        ..putLayer(const LayerDef(name: 'F', lineType: 'FINE'))
        ..addEntity(
          LineEntity(
            id: 0,
            props: const EntityProps(layer: 'F'),
            start: const Vec2.zero(),
            end: const Vec2(100, 0),
          ),
        );
      final scene = newBuilder().build(
        document,
        const CadViewport(center: Vec2(50, 0), scale: 1, size: size),
      );
      expect(scene.segmentCount, 1);
    });

    test('hatches produce fills, not strokes', () {
      final document = CadDocument()
        ..addEntity(
          HatchEntity(
            id: 0,
            loops: [
              HatchLoop(
                vertices: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10]),
              ),
            ],
          ),
        );
      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );
      expect(scene.fillBatches, hasLength(1));
      expect(scene.lineBatches, isEmpty);
    });

    test('text below the legibility threshold degrades to a bar', () {
      final document = CadDocument()
        ..addEntity(
          TextEntity(
            id: 0,
            position: const Vec2.zero(),
            content: 'REVISION B',
            height: 2.5,
          ),
        );
      // 2.5 units at 0.25 pixels per unit is below one physical pixel.
      const tiny = CadViewport(center: Vec2.zero(), scale: 0.25, size: size);
      final small = newBuilder().build(document, tiny);
      expect(small.texts, isEmpty);
      expect(small.fillBatches, isNotEmpty);

      // Small CAD labels remain useful above a pixel instead of becoming
      // opaque grey bars.
      const near = CadViewport(center: Vec2.zero(), scale: 0.5, size: size);
      final large = newBuilder().build(document, near);
      expect(large.texts, hasLength(1));
      expect(large.texts.single.text, 'REVISION B');
    });

    test('block references are expanded', () {
      final document = CadDocument();
      final member = document.allocateId();
      document
        ..registerImportedEntity(
          CircleEntity(id: member, center: const Vec2.zero(), radius: 5),
        )
        ..putBlock(BlockRecord(name: 'DOT', entityIds: [member]))
        ..addEntity(
          InsertEntity(id: 0, blockName: 'DOT', position: const Vec2(50, 50)),
        );
      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );
      expect(scene.segmentCount, greaterThan(8));
    });

    test('an unusable viewport yields an empty scene rather than throwing', () {
      final scene = newBuilder().build(
        gridDocument(10),
        const CadViewport(center: Vec2.zero(), scale: 1, size: Size.zero),
      );
      expect(scene.drawCallCount, 0);
    });

    test('an invisible entity cannot invent scene strokes', () {
      const view = CadViewport(
        center: Vec2(5, 0),
        scale: 10,
        size: Size(200, 200),
      );
      final document = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(visible: false),
            start: Vec2.zero(),
            end: Vec2(10, 0),
          ),
        );
      final scene = newBuilder().build(document, view);
      expect(scene.entityCount, 0);
      expect(scene.lineBatches, isEmpty);
    });

    test('a visible line still lands in a batch', () {
      const view = CadViewport(
        center: Vec2(5, 0),
        scale: 10,
        size: Size(200, 200),
      );
      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        );
      final scene = newBuilder().build(document, view);
      expect(scene.entityCount, 1);
      expect(scene.lineBatches, hasLength(1));
    });

    test('a NaN neighbour cannot empty the scene', () {
      const view = CadViewport(
        center: Vec2(5, 0),
        scale: 10,
        size: Size(200, 200),
      );
      final document = CadDocument()
        ..addEntity(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
        )
        ..addEntity(
          const LineEntity(
            id: 1,
            start: Vec2(-1e41, 0),
            end: Vec2(-1e41, double.nan),
          ),
        );
      final scene = newBuilder().build(document, view);
      expect(scene.entityCount, 1);
      expect(scene.lineBatches, hasLength(1));
    });

    test('a paper millimetre stroke does not grow past its paper width', () {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(lineWeight: 50),
            start: Vec2.zero(),
            end: Vec2(40, 0),
          ),
        );
      const strokeSize = Size(200, 200);
      const paper = 0.50 / 25.4 * 96;

      final atOne = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 1, size: strokeSize),
      );
      final atTwo = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 2, size: strokeSize),
      );
      expect(atOne.lineBatches, hasLength(1));
      expect(atTwo.lineBatches, hasLength(1));
      expect(atOne.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
      expect(atTwo.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
    });

    test('a paper millimetre stroke is physical pixels, not logical ones', () {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(lineWeight: 50),
            start: Vec2.zero(),
            end: Vec2(40, 0),
          ),
        );
      const strokeSize = Size(200, 200);
      const paper = 0.50 / 25.4 * 96;

      final onePixel = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 1, size: strokeSize),
      );
      final retina = newBuilder().build(
        document,
        const CadViewport(
          center: Vec2(20, 0),
          scale: 1,
          size: strokeSize,
          devicePixelRatio: 2,
        ),
      );

      // Half a millimetre of ink is half a millimetre on both displays, which
      // means twice as many pixels on the denser one. Reporting the same number
      // for both is what made a Retina hairline draw two pixels wide.
      expect(onePixel.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
      expect(retina.lineBatches.single.key.strokeWidth, closeTo(paper * 2, 1e-9));
    });

    test('a paper millimetre stroke shrinks when the viewport shrinks', () {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(lineWeight: 100),
            start: Vec2.zero(),
            end: Vec2(40, 0),
          ),
        );
      const strokeSize = Size(200, 200);
      const paper = 1.00 / 25.4 * 96;

      final atOne = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 1, size: strokeSize),
      );
      final atHalf = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 0.5, size: strokeSize),
      );
      expect(atOne.lineBatches.single.key.strokeWidth, closeTo(paper, 1e-9));
      expect(
        atHalf.lineBatches.single.key.strokeWidth,
        closeTo(paper * 0.5, 1e-9),
      );
    });

    test('a hairline stays the hairline sentinel after a zoom change', () {
      final document = CadDocument()
        ..addEntity(
          const LineEntity(
            id: 0,
            props: EntityProps(lineWeight: 0),
            start: Vec2.zero(),
            end: Vec2(40, 0),
          ),
        );
      const strokeSize = Size(200, 200);

      final near = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 1, size: strokeSize),
      );
      final far = newBuilder().build(
        document,
        const CadViewport(center: Vec2(20, 0), scale: 10, size: strokeSize),
      );
      expect(near.lineBatches.single.key.strokeWidth, 0);
      expect(far.lineBatches.single.key.strokeWidth, 0);
    });

    test('a sub-pixel insert still leaves a mark so it does not vanish', () {
      final document = CadDocument();
      document.addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(8, 0)),
        blockName: 'TICK',
      );
      document
        ..putBlock(
          const BlockRecord(name: 'TICK', entityIds: [1]),
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'TICK', position: Vec2(100, 100)),
        );
      // Zoomed so the 8-unit tick is well under the 1.5 px collapse size.
      const view = CadViewport(
        center: Vec2(100, 100),
        scale: 0.1,
        size: Size(200, 200),
      );
      final scene = newBuilder().build(document, view);
      expect(
        scene.lineBatches.isNotEmpty || scene.pointBatches.isNotEmpty,
        isTrue,
      );
    });

    test('a visible insert collapses members smaller than a pixel', () {
      final document = CadDocument();
      // A 200-unit frame stays several pixels at this zoom; the 4-unit ticks
      // inside it are well under 1.5 px and must not dump as linework.
      document
        ..addEntity(
          const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(200, 0)),
          blockName: 'CELL',
        )
        ..addEntity(
          const LineEntity(id: 2, start: Vec2(200, 0), end: Vec2(200, 200)),
          blockName: 'CELL',
        )
        ..addEntity(
          const LineEntity(id: 3, start: Vec2(200, 200), end: Vec2(0, 200)),
          blockName: 'CELL',
        )
        ..addEntity(
          const LineEntity(id: 4, start: Vec2.zero(), end: Vec2(0, 200)),
          blockName: 'CELL',
        );
      for (var i = 0; i < 40; i++) {
        document.addEntity(
          LineEntity(
            id: 10 + i,
            start: Vec2(10.0 + i * 4, 10),
            end: Vec2(12.0 + i * 4, 12),
          ),
          blockName: 'CELL',
        );
      }
      document
        ..putBlock(
          BlockRecord(
            name: 'CELL',
            entityIds: [1, 2, 3, 4, for (var i = 0; i < 40; i++) 10 + i],
          ),
        )
        ..addEntity(
          const InsertEntity(id: 100, blockName: 'CELL', position: Vec2.zero()),
        );
      const view = CadViewport(
        center: Vec2(100, 100),
        scale: 0.2,
        size: Size(200, 200),
      );
      final scene = newBuilder().build(document, view);
      expect(scene.lineBatches, isNotEmpty);
      expect(scene.segmentCount, lessThan(10));
      expect(scene.pointBatches, isNotEmpty);
    });

    test('an insert cached against a miss clip still draws later', () {
      final document = CadDocument();
      document.addEntity(
        const LineEntity(id: 1, start: Vec2(-40, 0), end: Vec2(40, 0)),
        blockName: 'FRAME',
      );
      document
        ..putBlock(
          const BlockRecord(name: 'FRAME', entityIds: [1]),
        )
        ..addEntity(
          const InsertEntity(id: 2, blockName: 'FRAME', position: Vec2.zero()),
        );
      final cache = TessellationCache();
      final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
      const miss = CadViewport(
        center: Vec2(400, 0),
        scale: 1,
        size: Size(80, 80),
      );
      builder.build(document, miss);
      const hit = CadViewport(
        center: Vec2.zero(),
        scale: 1,
        size: Size(80, 80),
      );
      final scene = builder.build(document, hit);
      expect(scene.lineBatches, isNotEmpty);
      expect(scene.lineBatches.single.segmentCount, greaterThan(0));
    });

    test('MTEXT attachment 1 stays on the box, not a baseline lift', () {
      const view = CadViewport(
        center: Vec2(20, 20),
        scale: 1,
        size: Size(200, 200),
      );
      final document = CadDocument()
        ..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(10, 30),
            content: 'Note',
            height: 8,
            attachment: 1,
          ),
        );
      final scene = newBuilder().build(document, view);
      expect(scene.texts, isNotEmpty);
      expect(scene.texts.single.boxAnchor, isTrue);
      expect(scene.texts.single.vAlign, TextVAlign.top.index);
    });

    test('an MTEXT underline reaches the text item', () {
      const view = CadViewport(
        center: Vec2(20, 20),
        scale: 1,
        size: Size(200, 200),
      );
      final document = CadDocument()
        ..addEntity(
          const MTextEntity(
            id: 1,
            position: Vec2(10, 30),
            content: r'\LNote\l',
            height: 8,
          ),
        );
      final scene = newBuilder().build(document, view);
      expect(scene.texts, isNotEmpty);
      expect(scene.texts.single.underline, isTrue);
      expect(scene.texts.single.text, 'Note');
    });
  });

  group('paper space', () {
    test('a layout viewport draws the model onto the sheet', () {
      final document = CadDocument();
      document.addEntity(
        LineEntity(
          id: 0,
          start: const Vec2(0, 0),
          end: const Vec2(80, 0),
        ),
        blockName: document.modelSpaceBlockName,
      );
      document.addLayout(
        Layout(
          name: 'Layout1',
          blockName: '*Paper_Space',
          tabOrder: 1,
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2(40, 0),
              scale: 1,
            ),
          ],
        ),
      );
      expect(document.setActiveLayout('Layout1'), isTrue);

      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );

      expect(scene.entityCount, greaterThan(0));
      expect(scene.lineBatches, isNotEmpty);
      expect(document.extents.width, closeTo(297, 1e-9));
      expect(document.extents.height, closeTo(210, 1e-9));
    });

    test('an off viewport keeps its frame and hides the model', () {
      final document = CadDocument();
      document.addEntity(
        LineEntity(
          id: 0,
          start: const Vec2(0, 0),
          end: const Vec2(80, 0),
        ),
        blockName: document.modelSpaceBlockName,
      );
      document.addLayout(
        Layout(
          name: 'Layout1',
          blockName: '*Paper_Space',
          tabOrder: 1,
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2(40, 0),
              scale: 1,
              isOn: false,
            ),
          ],
        ),
      );
      expect(document.setActiveLayout('Layout1'), isTrue);

      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );

      expect(scene.entityCount, 0);
      expect(scene.lineBatches, isNotEmpty);
    });

    test('a viewport-frozen layer is not drawn through the window', () {
      final document = CadDocument();
      document.putLayer(const LayerDef(name: 'DIMS'));
      document.addEntity(
        LineEntity(
          id: 0,
          props: const EntityProps(layer: 'DIMS'),
          start: const Vec2(0, 0),
          end: const Vec2(80, 0),
        ),
        blockName: document.modelSpaceBlockName,
      );
      document.addLayout(
        Layout(
          name: 'Layout1',
          blockName: '*Paper_Space',
          tabOrder: 1,
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2(40, 0),
              scale: 1,
              frozenLayers: ['DIMS'],
            ),
          ],
        ),
      );
      expect(document.setActiveLayout('Layout1'), isTrue);

      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );

      expect(scene.entityCount, 0);
      expect(scene.lineBatches, isNotEmpty);
    });

    test('model space does not composite paper viewports', () {
      final document = CadDocument();
      document.addEntity(
        LineEntity(
          id: 0,
          start: const Vec2(0, 0),
          end: const Vec2(80, 0),
        ),
      );
      document.addLayout(
        Layout(
          name: 'Layout1',
          blockName: '*Paper_Space',
          tabOrder: 1,
          viewports: const [
            PaperViewport(
              paperBounds: Bounds2(10, 10, 200, 150),
              modelCenter: Vec2(40, 0),
            ),
          ],
        ),
      );

      final scene = newBuilder().build(
        document,
        CadViewport.fit(document.extents, size),
      );

      expect(document.activeLayout.isModelSpace, isTrue);
      expect(scene.entityCount, 1);
    });
  });
}
