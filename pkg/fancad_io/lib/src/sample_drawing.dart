import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

/// Drawings generated in code for package tests.
///
/// Not part of the public `fancad_io` API. Performance work needs a drawing
/// whose entity count can be dialled up on demand.
class SampleDrawings {
  const SampleDrawings._();

  /// A small mechanical part that exercises most entity types, the layer and
  /// line type tables, a reusable block, a hatch and a dimension.
  static CadDocument mechanicalPart() {
    final document = CadDocument()
      ..putLineType(
        const LineTypeDef(
          name: 'CENTER',
          description: 'Center ____ _ ____ _ ____',
          pattern: [12.7, -2.54, 2.54, -2.54],
          patternLength: 20.32,
        ),
      )
      ..putLineType(
        const LineTypeDef(
          name: 'HIDDEN',
          description: 'Hidden __ __ __ __',
          pattern: [6.35, -3.175],
          patternLength: 9.525,
        ),
      )
      ..putLayer(
        const LayerDef(
          name: 'OUTLINE',
          color: CadColor.indexed(7),
          lineWeight: 50,
        ),
      )
      ..putLayer(
        const LayerDef(
          name: 'CENTER',
          color: CadColor.indexed(1),
          lineType: 'CENTER',
        ),
      )
      ..putLayer(
        const LayerDef(
          name: 'HIDDEN',
          color: CadColor.indexed(3),
          lineType: 'HIDDEN',
        ),
      )
      ..putLayer(const LayerDef(name: 'DIMENSIONS', color: CadColor.indexed(4)))
      ..putLayer(const LayerDef(name: 'HATCH', color: CadColor.rgb(0x3A6EA5)))
      ..putLayer(const LayerDef(name: 'NOTES', color: CadColor.indexed(2)));

    const outline = EntityProps(layer: 'OUTLINE');
    const centreLine = EntityProps(layer: 'CENTER');
    const hidden = EntityProps(layer: 'HIDDEN');
    const notes = EntityProps(layer: 'NOTES');

    // A bolt-hole block, so block references and the block table get used.
    const holeBlock = 'BOLT_HOLE';
    final holeEntities = <CadEntity>[
      CircleEntity(
        id: document.allocateId(),
        props: outline,
        center: const Vec2.zero(),
        radius: 3,
      ),
      LineEntity(
        id: document.allocateId(),
        props: centreLine,
        start: const Vec2(-4.5, 0),
        end: const Vec2(4.5, 0),
      ),
      LineEntity(
        id: document.allocateId(),
        props: centreLine,
        start: const Vec2(0, -4.5),
        end: const Vec2(0, 4.5),
      ),
    ];
    for (final entity in holeEntities) {
      document.registerImportedEntity(entity);
    }
    document.putBlock(
      BlockRecord(
        name: holeBlock,
        entityIds: [for (final entity in holeEntities) entity.id],
        description: 'M6 bolt hole with centre marks',
      ),
    );

    const width = 160.0;
    const height = 90.0;
    const fillet = 12.0;
    const centre = Vec2(width / 2, height / 2);
    // tan(90 degrees / 4) is the bulge factor of a quarter circle.
    final quarterBulge = math.tan(math.pi / 8);

    // Outer profile: a filleted rectangular plate, as a bulged polyline.
    document.addEntity(
      PolylineEntity(
        id: 0,
        props: outline,
        closed: true,
        vertices: Float64List.fromList([
          fillet,
          0,
          0,
          width - fillet,
          0,
          quarterBulge,
          width,
          fillet,
          0,
          width,
          height - fillet,
          quarterBulge,
          width - fillet,
          height,
          0,
          fillet,
          height,
          quarterBulge,
          0,
          height - fillet,
          0,
          0,
          fillet,
          quarterBulge,
        ]),
      ),
    );

    // Central bore with a hidden counterbore and centre lines.
    document
      ..addEntity(
        CircleEntity(id: 0, props: outline, center: centre, radius: 22),
      )
      ..addEntity(
        CircleEntity(id: 0, props: hidden, center: centre, radius: 28),
      )
      ..addEntity(
        LineEntity(
          id: 0,
          props: centreLine,
          start: Vec2(centre.x - 34, centre.y),
          end: Vec2(centre.x + 34, centre.y),
        ),
      )
      ..addEntity(
        LineEntity(
          id: 0,
          props: centreLine,
          start: Vec2(centre.x, centre.y - 34),
          end: Vec2(centre.x, centre.y + 34),
        ),
      );

    // Four bolt holes on a pitch circle, as block references.
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 + i * math.pi / 2;
      document.addEntity(
        InsertEntity(
          id: 0,
          props: outline,
          blockName: holeBlock,
          position: centre + Vec2.polar(angle, 36),
        ),
      );
    }

    // A slot: two half-arcs joined by two lines.
    document
      ..addEntity(
        ArcEntity(
          id: 0,
          props: outline,
          center: const Vec2(28, height / 2),
          radius: 7,
          startAngle: math.pi / 2,
          endAngle: math.pi * 3 / 2,
        ),
      )
      ..addEntity(
        ArcEntity(
          id: 0,
          props: outline,
          center: const Vec2(48, height / 2),
          radius: 7,
          startAngle: math.pi * 3 / 2,
          endAngle: math.pi / 2,
        ),
      )
      ..addEntity(
        LineEntity(
          id: 0,
          props: outline,
          start: const Vec2(28, height / 2 + 7),
          end: const Vec2(48, height / 2 + 7),
        ),
      )
      ..addEntity(
        LineEntity(
          id: 0,
          props: outline,
          start: const Vec2(28, height / 2 - 7),
          end: const Vec2(48, height / 2 - 7),
        ),
      );

    // An elliptical relief and a spline, to exercise curve tessellation.
    document
      ..addEntity(
        EllipseEntity(
          id: 0,
          props: outline,
          center: const Vec2(width - 32, height / 2),
          majorAxis: const Vec2(14, 0),
          ratio: 0.55,
        ),
      )
      ..addEntity(
        SplineEntity(
          id: 0,
          props: notes,
          controlPoints: Float64List.fromList([
            10,
            height + 18,
            40,
            height + 34,
            80,
            height + 6,
            120,
            height + 30,
            150,
            height + 14,
          ]),
          knots: const [0, 0, 0, 0, 0.5, 1, 1, 1, 1],
        ),
      );

    // A solid-filled pocket.
    document.addEntity(
      HatchEntity(
        id: 0,
        props: const EntityProps(layer: 'HATCH'),
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([
              width - 46,
              12,
              width - 12,
              12,
              width - 12,
              30,
              width - 46,
              30,
            ]),
          ),
        ],
      ),
    );

    // Annotation.
    document
      ..addEntity(
        DimensionEntity(
          id: 0,
          props: const EntityProps(layer: 'DIMENSIONS'),
          definitionPoints: const [Vec2(0, -14), Vec2(width, -14)],
          textPosition: const Vec2(width / 2, -14),
          measurement: width,
        ),
      )
      ..addEntity(
        TextEntity(
          id: 0,
          props: notes,
          position: const Vec2(0, -30),
          content: 'PLATE, 6 mm MILD STEEL',
          height: 5,
        ),
      )
      ..addEntity(
        MTextEntity(
          id: 0,
          props: notes,
          position: const Vec2(0, -40),
          content:
              'NOTES:\\P1. Deburr all edges.\\P2. Tolerances per ISO 2768-m.'
              r'\P3. Finish: anodised, matte black.',
          height: 3.5,
          rectangleWidth: 90,
        ),
      );

    document
      ..currentLayer = 'OUTLINE'
      // 4 = millimetres, per the DXF $INSUNITS table.
      ..setHeaderVariable(r'$INSUNITS', '4')
      ..setHeaderVariable(r'$LTSCALE', '1')
      ..setHeaderVariable(r'$ACADVER', 'FanCAD sample')
      ..reindex();
    return document;
  }

  /// A drawing of [count] entities laid out on a grid.
  ///
  /// This exists so render performance can be stated rather than guessed: a
  /// known entity count makes "n entities at m frames per second" a measurement
  /// instead of an impression.
  static CadDocument stressTest({int count = 100000}) {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'STRESS', color: CadColor.indexed(4)));
    final columns = math.sqrt(count).ceil();
    final random = math.Random(20260821);
    final entities = <CadEntity>[];
    for (var i = 0; i < count; i++) {
      final x = (i % columns) * 10.0;
      final y = (i ~/ columns) * 10.0;
      final props = EntityProps(
        layer: 'STRESS',
        color: CadColor.indexed(1 + (i % 7)),
      );
      entities.add(switch (i % 4) {
        0 => LineEntity(
          id: i + 1,
          props: props,
          start: Vec2(x, y),
          end: Vec2(x + 8, y + 8),
        ),
        1 => CircleEntity(
          id: i + 1,
          props: props,
          center: Vec2(x + 4, y + 4),
          radius: 3.5,
        ),
        2 => ArcEntity(
          id: i + 1,
          props: props,
          center: Vec2(x + 4, y + 4),
          radius: 4,
          startAngle: random.nextDouble() * math.pi,
          endAngle: math.pi + random.nextDouble() * math.pi,
        ),
        _ => PolylineEntity.fromPoints(
          id: i + 1,
          props: props,
          points: [
            Vec2(x, y + 2),
            Vec2(x + 3, y + 7),
            Vec2(x + 6, y + 1),
            Vec2(x + 9, y + 6),
          ],
        ),
      });
    }
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
}
