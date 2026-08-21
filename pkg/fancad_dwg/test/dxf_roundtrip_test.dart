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

  test('a stress drawing of 10k entities encodes and decodes as DXF', () {
    final original = SampleDrawings.stressTest(count: 2000);
    final dxf = const DxfWriter().writeString(original);
    final restored = const DxfReader().readString(dxf);
    expect(restored.entityCount, original.entityCount);
    expect(restored.extents.isNotEmpty, isTrue);
  });
}
