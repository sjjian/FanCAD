import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
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
      // 2.5 units at 0.5 pixels per unit is just over a pixel tall.
      const tiny = CadViewport(center: Vec2.zero(), scale: 0.5, size: size);
      final small = newBuilder().build(document, tiny);
      expect(small.texts, isEmpty);
      expect(small.fillBatches, isNotEmpty);

      const near = CadViewport(center: Vec2.zero(), scale: 20, size: size);
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
  });

  group('RenderScene reuse', () {
    test('a small pan can reuse the scene by translating it', () {
      final document = gridDocument(500);
      const view = CadViewport(center: Vec2(100, 0), scale: 2, size: size);
      final scene = newBuilder().build(document, view);

      final nudged = view.panned(const Offset(20, 10));
      expect(scene.canReuseFor(nudged), isTrue);
      final delta = scene.translationFor(nudged);
      expect(delta.dx, closeTo(20, 1e-9));
      expect(delta.dy, closeTo(10, 1e-9));
    });

    test('a zoom cannot reuse the scene', () {
      final document = gridDocument(50);
      const view = CadViewport(center: Vec2.zero(), scale: 2, size: size);
      final scene = newBuilder().build(document, view);
      expect(scene.canReuseFor(view.copyWith(scale: 4)), isFalse);
    });

    test('a pan beyond the overscan cannot reuse the scene', () {
      final document = gridDocument(500);
      const view = CadViewport(center: Vec2(100, 0), scale: 2, size: size);
      final scene = newBuilder().build(document, view);
      expect(scene.canReuseFor(view.panned(const Offset(5000, 0))), isFalse);
    });
  });

  group('TessellationCache', () {
    test('curves hit the cache on a repeated build', () {
      final document = CadDocument();
      for (var i = 0; i < 200; i++) {
        document.addEntity(
          CircleEntity(id: 0, center: Vec2(i * 10, 0), radius: 4),
        );
      }
      final cache = TessellationCache();
      final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
      final view = CadViewport.fit(document.extents, size);

      builder.build(document, view);
      final firstMisses = cache.misses;
      expect(firstMisses, greaterThan(0));

      cache.resetStatistics();
      builder.build(document, view);
      expect(cache.misses, 0);
      expect(cache.hits, firstMisses);
    });

    test('straight geometry is not cached', () {
      final cache = TessellationCache();
      final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
      final document = gridDocument(100);
      builder.build(document, CadViewport.fit(document.extents, size));
      expect(cache.entryCount, 0);
    });

    test('invalidation drops only the affected entities', () {
      final document = CadDocument();
      final ids = [
        for (var i = 0; i < 20; i++)
          document
              .addEntity(
                CircleEntity(id: 0, center: Vec2(i * 10, 0), radius: 4),
              )
              .id,
      ];
      final cache = TessellationCache();
      final builder = SceneBuilder(palette: AciPalette.dark, cache: cache);
      final view = CadViewport.fit(document.extents, size);
      builder.build(document, view);
      final before = cache.entryCount;

      cache.invalidate([ids.first]);
      expect(cache.entryCount, before - 1);
    });

    test('the cache stays inside its budget', () {
      final document = CadDocument();
      for (var i = 0; i < 400; i++) {
        document.addEntity(
          CircleEntity(id: 0, center: Vec2(i * 20, 0), radius: 9),
        );
      }
      // A budget far too small for the whole drawing.
      final cache = TessellationCache(budget: 2000);
      SceneBuilder(palette: AciPalette.dark, cache: cache).build(
        document,
        CadViewport.fit(document.extents, size),
      );
      expect(cache.totalWeight, lessThanOrEqualTo(2000));
    });

    test('tolerance bucketing reuses entries across a small zoom change', () {
      const a = CadViewport(center: Vec2.zero(), scale: 100, size: size);
      final b = a.copyWith(scale: 105);
      expect(
        TessellationCache.toleranceBucket(a.tolerance),
        TessellationCache.toleranceBucket(b.tolerance),
      );
      // A large zoom change must land in a different band.
      expect(
        TessellationCache.toleranceBucket(a.copyWith(scale: 1600).tolerance),
        isNot(TessellationCache.toleranceBucket(a.tolerance)),
      );
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

  group('AciPalette', () {
    test('index 7 follows the background', () {
      expect(AciPalette.dark.indexed(7).computeLuminance(), greaterThan(0.5));
      expect(AciPalette.light.indexed(7).computeLuminance(), lessThan(0.5));
    });

    test('the primaries are the colours CAD users expect', () {
      expect(AciPalette.dark.indexed(1), const Color(0xFFFF0000));
      expect(AciPalette.dark.indexed(3), const Color(0xFF00FF00));
      expect(AciPalette.dark.indexed(5).b, greaterThan(0.5));
    });

    test('near-black is lifted so it stays visible on a dark canvas', () {
      final lifted = AciPalette.dark.colorOf(const CadColor.rgb(0x050505));
      expect(lifted.computeLuminance(), greaterThan(0.01));
      // On a light canvas it must be left exactly as authored.
      expect(
        AciPalette.light.colorOf(const CadColor.rgb(0x050505)),
        const Color(0xFF050505),
      );
    });
  });
}
