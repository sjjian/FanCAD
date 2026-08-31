import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_io/src/sample_drawing.dart';
import 'package:test/test.dart';

void main() {
  test('a constant-width polyline keeps its width through DXF', () {
    final original = CadDocument()
      ..addEntity(
        PolylineEntity(
          id: 0,
          vertices: Float64List.fromList([0, 0, 0, 10, 0, 0]),
          constantWidth: 2.5,
        ),
      );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('\n43\n2.5\n'));

    final restored = const DxfReader().readString(dxf);
    expect(
      restored.entities.whereType<PolylineEntity>().single.constantWidth,
      closeTo(2.5, 1e-9),
    );
  });

  test('DXF round-trips lines, circles and polylines', () {
    final original = CadDocument();
    final session = DocumentSession(id: 't', document: original);
    session.edit('setup', (transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 0)),
      );
      transaction.add(CircleEntity(id: 0, center: const Vec2(5, 5), radius: 2));
      transaction.add(
        PolylineEntity.fromPoints(
          id: 0,
          points: const [Vec2(0, 0), Vec2(1, 0), Vec2(1, 1)],
          closed: true,
        ),
      );
    });

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('LINE'));
    expect(dxf, contains('CIRCLE'));
    expect(dxf, contains('LWPOLYLINE'));

    final restored = const DxfReader().readString(dxf);
    final report = const FidelityAuditor().compare(original, restored);
    expect(report.isClean, isTrue, reason: report.summary);
    expect(restored.entities.whereType<PolylineEntity>().single.vertexCount, 3);
  });

  test('splines, leaders, images and array inserts survive DXF', () {
    final original = CadDocument();
    original.putBlock(const BlockRecord(name: 'CELL', entityIds: []));
    original
      ..addEntity(
        SplineEntity(
          id: 0,
          controlPoints: Float64List.fromList([0, 0, 10, 20, 20, 0, 30, 10]),
          knots: const [0, 0, 0, 0, 1, 1, 1, 1],
        ),
      )
      ..addEntity(
        LeaderEntity(
          id: 0,
          vertices: Float64List.fromList([0, 0, 8, 4, 16, 4]),
          hasArrowHead: true,
        ),
      )
      ..addEntity(
        const ImageEntity(
          id: 0,
          reference: 'photo.png',
          origin: Vec2(1, 2),
          uVector: Vec2(10, 0),
          vVector: Vec2(0, 6),
        ),
      )
      ..addEntity(
        const InsertEntity(
          id: 0,
          blockName: 'CELL',
          position: Vec2(40, 0),
          columnCount: 3,
          rowCount: 2,
          columnSpacing: 5,
          rowSpacing: 4,
        ),
      );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('SPLINE'));
    expect(dxf, contains('LEADER'));
    expect(dxf, contains('IMAGE'));
    expect(dxf, contains('MINSERT'));
    expect(dxf, isNot(contains('\nPOINT\n')));

    final restored = const DxfReader().readString(dxf);
    final report = const FidelityAuditor().compare(original, restored);
    expect(report.isClean, isTrue, reason: report.summary);

    final spline = restored.entities.whereType<SplineEntity>().single;
    expect(spline.controlPointCount, 4);
    expect(spline.knots, const [0, 0, 0, 0, 1, 1, 1, 1]);

    final leader = restored.entities.whereType<LeaderEntity>().single;
    expect(leader.vertices.length, 6);
    expect(leader.hasArrowHead, isTrue);

    final image = restored.entities.whereType<ImageEntity>().single;
    expect(image.reference, 'photo.png');
    expect(image.origin, const Vec2(1, 2));

    final insert = restored.entities.whereType<InsertEntity>().single;
    expect(insert.isArray, isTrue);
    expect(insert.columnCount, 3);
    expect(insert.rowCount, 2);
    expect(insert.columnSpacing, closeTo(5, 1e-12));
  });

  test('paper layouts and viewports survive DXF', () {
    final original = CadDocument();
    original.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(80, 0)),
    );
    original.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
        plotRotation: 270,
        plotWindow: Bounds2(8, 9, 88, 49),
        plotScale: 0.25,
        plotFit: true,
        plotOffsetX: 2,
        plotOffsetY: 3,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(20, 20, 220, 170),
            modelCenter: Vec2(40, 0),
            scale: 0.5,
            locked: true,
            frozenLayers: ['DIMS'],
          ),
        ],
      ),
    );
    original.addEntity(
      const LineEntity(id: 0, start: Vec2(10, 10), end: Vec2(50, 10)),
      blockName: '*Paper_Space',
    );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('LAYOUT'));
    expect(dxf, contains('AcDbLayout'));
    expect(dxf, contains('AcDbPlotSettings'));
    expect(dxf, contains('VIEWPORT'));
    expect(dxf, contains('A3'));

    final restored = const DxfReader().readString(dxf);
    expect(
      restored.layouts.map((item) => item.name),
      containsAll(['Model', 'A3']),
    );
    final paper = restored.layouts.firstWhere((item) => item.name == 'A3');
    expect(paper.paperWidth, closeTo(420, 1e-9));
    expect(paper.paperHeight, closeTo(297, 1e-9));
    expect(paper.plotRotation, 270);
    expect(paper.plotWindow, const Bounds2(8, 9, 88, 49));
    expect(paper.plotScale, closeTo(0.25, 1e-9));
    expect(paper.plotFit, isTrue);
    expect(paper.plotOffsetX, closeTo(2, 1e-9));
    expect(paper.plotOffsetY, closeTo(3, 1e-9));
    expect(paper.viewports, hasLength(1));
    expect(paper.viewports.single.scale, closeTo(0.5, 1e-9));
    expect(paper.viewports.single.locked, isTrue);
    expect(paper.viewports.single.frozenLayers, ['DIMS']);
    expect(paper.viewports.single.paperBounds, const Bounds2(20, 20, 220, 170));

    expect(restored.entitiesOf(restored.modelSpaceBlockName), hasLength(1));
    expect(restored.entitiesOf('*Paper_Space'), hasLength(1));
    expect(const FidelityAuditor().compare(original, restored).isClean, isTrue);
  });

  test('an xref block keeps its path through DXF', () {
    final original = CadDocument();
    final foreign = CadDocument()
      ..addEntity(
        const LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0)),
      );
    final session = DocumentSession(id: 't', document: original);
    session.edit('Attach xref', (transaction) {
      const XrefResolver().attach(
        host: original,
        foreign: foreign,
        path: r'C:\parts\bracket.dxf',
        at: const Vec2(5, 6),
        transaction: transaction,
      );
    });

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains(r'C:\parts\bracket.dxf'));
    expect(dxf, contains('INSERT'));

    final restored = const DxfReader().readString(dxf);
    expect(restored.blocks['BRACKET']!.isXref, isTrue);
    expect(restored.blocks['BRACKET']!.xrefPath, r'C:\parts\bracket.dxf');
    expect(restored.blocks['BRACKET']!.entityIds, hasLength(1));
    final insert = restored.activeEntities.whereType<InsertEntity>().single;
    expect(insert.blockName, 'BRACKET');
    expect(insert.position, const Vec2(5, 6));
  });

  test('dimension styles survive DXF', () {
    final original = CadDocument()
      ..putDimStyle(
        const DimStyleDef(
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
      );
    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('DIMSTYLE'));
    expect(dxf, contains('ARCH'));

    final restored = const DxfReader().readString(dxf);
    final style = restored.namedDimStyle('ARCH')!;
    expect(style.textHeight, closeTo(5, 1e-9));
    expect(style.arrowSize, closeTo(4, 1e-9));
    expect(style.extensionLineOffset, closeTo(1, 1e-9));
    expect(style.extensionLineExtend, closeTo(2, 1e-9));
    expect(style.textGap, closeTo(0.8, 1e-9));
    expect(style.scale, closeTo(2, 1e-9));
    expect(style.decimalPlaces, 0);
    expect(style.textStyle, 'Standard');
  });

  test('a hatch keeps its pattern, scale and boundary through DXF', () {
    final original = CadDocument();
    original.addEntity(
      HatchEntity(
        id: 0,
        loops: [
          HatchLoop(
            vertices: Float64List.fromList([0, 0, 20, 0, 20, 10, 0, 10]),
          ),
        ],
        patternName: 'ANSI31',
        solid: false,
        patternScale: 2,
        patternAngle: math.pi / 2,
      ),
    );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('HATCH'));
    expect(dxf, contains('ANSI31'));

    final restored = const DxfReader().readString(dxf);
    final hatch = restored.entities.whereType<HatchEntity>().single;
    expect(hatch.patternName, 'ANSI31');
    expect(hatch.solid, isFalse);
    expect(hatch.patternScale, closeTo(2, 1e-9));
    expect(hatch.patternAngle, closeTo(math.pi / 2, 1e-9));
    expect(hatch.loops, hasLength(1));
    expect(hatch.loops.single.pointCount, 4);
    expect(hatch.loops.single.vertices[0], closeTo(0, 1e-9));
    expect(hatch.loops.single.vertices[2], closeTo(20, 1e-9));
  });

  test('a dimension keeps its style and definition points through DXF', () {
    final original = CadDocument()
      ..putDimStyle(const DimStyleDef(name: 'ARCH', decimalPlaces: 0))
      ..currentDimStyle = 'ARCH';
    original.addEntity(
      Construct.linearDimension(
        const Vec2(0, 0),
        const Vec2(10, 0),
        const Vec2(5, 4),
        styleName: 'ARCH',
      )!,
    );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains(r'$DIMSTYLE'));
    expect(dxf, contains('DIMENSION'));

    final restored = const DxfReader().readString(dxf);
    expect(restored.currentDimStyle, 'ARCH');
    final dim = restored.entities.whereType<DimensionEntity>().single;
    expect(dim.styleName, 'ARCH');
    expect(dim.measurement, closeTo(10, 1e-9));
    expect(dim.definitionPoints, hasLength(3));
    expect(dim.definitionPoints[0], const Vec2(0, 0));
    expect(dim.definitionPoints[1], const Vec2(10, 0));
    expect(dim.definitionPoints[2], const Vec2(5, 4));
  });

  test('a non-plottable layer stays off the plot through DXF', () {
    final original = CadDocument()
      ..putLayer(const LayerDef(name: 'VIEWPORT-FRAME', plottable: false));

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('290'));

    final restored = const DxfReader().readString(dxf);
    expect(restored.layers['VIEWPORT-FRAME']?.plottable, isFalse);
    expect(restored.layers['0']?.plottable, isTrue);
  });

  test('text styles survive DXF', () {
    final original = CadDocument()
      ..putTextStyle(
        const TextStyleDef(
          name: 'TITLE',
          fontFamily: 'Arial',
          height: 3.5,
          widthFactor: 0.8,
          obliqueAngle: 0.2,
          backwards: true,
        ),
      )
      ..addEntity(
        const TextEntity(
          id: 0,
          position: Vec2(1, 2),
          content: 'A',
          styleName: 'TITLE',
        ),
      );

    final restored = const DxfReader().readString(
      const DxfWriter().writeString(original),
    );
    final style = restored.textStyles['TITLE'];
    expect(style, isNotNull);
    expect(style!.fontFamily, 'Arial');
    expect(style.height, closeTo(3.5, 1e-12));
    expect(style.widthFactor, closeTo(0.8, 1e-12));
    expect(style.obliqueAngle, closeTo(0.2, 1e-12));
    expect(style.backwards, isTrue);
    expect(restored.entities.whereType<TextEntity>().single.styleName, 'TITLE');
  });

  test('entity and layer line weights survive DXF', () {
    final original = CadDocument()
      ..putLayer(const LayerDef(name: 'THICK', lineWeight: 50))
      ..addEntity(
        const LineEntity(
          id: 0,
          start: Vec2.zero(),
          end: Vec2(5, 0),
          props: EntityProps(layer: 'THICK', lineWeight: 25),
        ),
      );

    final restored = const DxfReader().readString(
      const DxfWriter().writeString(original),
    );
    expect(restored.layers['THICK']?.lineWeight, 50);
    expect(
      restored.entities.whereType<LineEntity>().single.props.lineWeight,
      25,
    );
  });

  test('a hidden entity stays off through DXF', () {
    final original = CadDocument()
      ..addEntity(
        const LineEntity(
          id: 0,
          start: Vec2.zero(),
          end: Vec2(4, 0),
          props: EntityProps(visible: false),
        ),
      );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('\n60\n1\n'));

    final restored = const DxfReader().readString(dxf);
    expect(restored.entities.single.props.visible, isFalse);
  });

  test('a hidden layer stays off through DXF', () {
    final original = CadDocument()
      ..putLayer(
        const LayerDef(
          name: 'CONSTRUCTION',
          color: CadColor.indexed(3),
          visible: false,
        ),
      )
      ..addEntity(
        const LineEntity(
          id: 0,
          start: Vec2.zero(),
          end: Vec2(4, 0),
          props: EntityProps(layer: 'CONSTRUCTION'),
        ),
      );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('\n-3\n'));

    final restored = const DxfReader().readString(dxf);
    final layer = restored.layers['CONSTRUCTION'];
    expect(layer, isNotNull);
    expect(layer!.visible, isFalse);
    expect(layer.color.value, 3);
  });

  test('line type dash patterns survive DXF', () {
    final original = CadDocument()
      ..putLineType(
        const LineTypeDef(
          name: 'CENTER',
          description: 'Center ____ _ ____',
          pattern: [24, -6, 6, -6],
          patternLength: 42,
        ),
      )
      ..putLayer(const LayerDef(name: 'AXIS', lineType: 'CENTER'))
      ..addEntity(
        const LineEntity(
          id: 0,
          start: Vec2.zero(),
          end: Vec2(10, 0),
          props: EntityProps(layer: 'AXIS'),
        ),
      );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('LTYPE'));
    expect(dxf, contains('CENTER'));

    final restored = const DxfReader().readString(dxf);
    final center = restored.lineTypes['CENTER'];
    expect(center, isNotNull);
    expect(center!.pattern, const [24, -6, 6, -6]);
    expect(center.patternLength, closeTo(42, 1e-12));
    expect(restored.layers['AXIS']?.lineType, 'CENTER');
  });

  test('unknown entities are not written as a point at the origin', () {
    final original = CadDocument();
    original
      ..addEntity(
        UnknownEntity(
          id: 0,
          originalType: 'ACAD_PROXY',
          proxyBounds: const Bounds2(10, 10, 20, 20),
        ),
      )
      ..addEntity(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(5, 0)));

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('LINE'));
    expect(dxf, isNot(contains('\nPOINT\n')));

    final restored = const DxfReader().readString(dxf);
    expect(restored.entities.whereType<PointEntity>(), isEmpty);
    expect(restored.entities.whereType<LineEntity>(), hasLength(1));
  });

  test('a stress drawing of 10k entities encodes and decodes as DXF', () {
    final original = SampleDrawings.stressTest(count: 2000);
    final dxf = const DxfWriter().writeString(original);
    final restored = const DxfReader().readString(dxf);
    expect(restored.entityCount, original.entityCount);
    expect(restored.extents.isNotEmpty, isTrue);
  });
}
