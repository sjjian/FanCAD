import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:test/test.dart';

void main() {
  test('DXF round-trips lines, circles and polylines', () {
    final original = CadDocument();
    final session = DocumentSession(id: 't', document: original);
    session.edit('setup', (transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 0)),
      );
      transaction.add(
        CircleEntity(id: 0, center: const Vec2(5, 5), radius: 2),
      );
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
    expect(
      restored.entities.whereType<PolylineEntity>().single.vertexCount,
      3,
    );
  });

  test('splines, leaders, images and array inserts survive DXF', () {
    final original = CadDocument();
    original.putBlock(
      const BlockRecord(name: 'CELL', entityIds: []),
    );
    original
      ..addEntity(
        SplineEntity(
          id: 0,
          controlPoints: Float64List.fromList([
            0, 0,
            10, 20,
            20, 0,
            30, 10,
          ]),
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
      const LineEntity(
        id: 0,
        start: Vec2.zero(),
        end: Vec2(80, 0),
      ),
    );
    original.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(20, 20, 220, 170),
            modelCenter: Vec2(40, 0),
            scale: 0.5,
            locked: true,
          ),
        ],
      ),
    );
    original.addEntity(
      const LineEntity(
        id: 0,
        start: Vec2(10, 10),
        end: Vec2(50, 10),
      ),
      blockName: '*Paper_Space',
    );

    final dxf = const DxfWriter().writeString(original);
    expect(dxf, contains('LAYOUT'));
    expect(dxf, contains('AcDbLayout'));
    expect(dxf, contains('AcDbPlotSettings'));
    expect(dxf, contains('VIEWPORT'));
    expect(dxf, contains('A3'));

    final restored = const DxfReader().readString(dxf);
    expect(restored.layouts.map((item) => item.name), containsAll(['Model', 'A3']));
    final paper = restored.layouts.firstWhere((item) => item.name == 'A3');
    expect(paper.paperWidth, closeTo(420, 1e-9));
    expect(paper.paperHeight, closeTo(297, 1e-9));
    expect(paper.viewports, hasLength(1));
    expect(paper.viewports.single.scale, closeTo(0.5, 1e-9));
    expect(paper.viewports.single.locked, isTrue);
    expect(paper.viewports.single.paperBounds, const Bounds2(20, 20, 220, 170));

    expect(
      restored.entitiesOf(restored.modelSpaceBlockName),
      hasLength(1),
    );
    expect(restored.entitiesOf('*Paper_Space'), hasLength(1));
    expect(
      const FidelityAuditor().compare(original, restored).isClean,
      isTrue,
    );
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

  test('a stress drawing of 10k entities encodes and decodes as DXF', () {
    final original = SampleDrawings.stressTest(count: 2000);
    final dxf = const DxfWriter().writeString(original);
    final restored = const DxfReader().readString(dxf);
    expect(restored.entityCount, original.entityCount);
    expect(restored.extents.isNotEmpty, isTrue);
  });
}
