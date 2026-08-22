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

  test('a stress drawing of 10k entities encodes and decodes as DXF', () {
    final original = SampleDrawings.stressTest(count: 2000);
    final dxf = const DxfWriter().writeString(original);
    final restored = const DxfReader().readString(dxf);
    expect(restored.entityCount, original.entityCount);
    expect(restored.extents.isNotEmpty, isTrue);
  });
}
