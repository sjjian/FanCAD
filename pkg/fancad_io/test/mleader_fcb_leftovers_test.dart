import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:test/test.dart';

void main() {
  test('a multileader survives FCB with its note attached', () {
    final original = CadDocument()
      ..addEntity(
        MLeaderEntity(
          id: 1,
          vertices: Float64List.fromList([0, 0, 8, 8, 14, 8]),
          content: 'QC50',
          textPosition: const Vec2(14, 8),
          textHeight: 3,
        ),
      );
    final restored = FcbReader(FcbWriter().write(original)).decode().document;
    final entity = restored.entities.whereType<MLeaderEntity>().single;
    expect(entity.content, 'QC50');
    expect(entity.textPosition, const Vec2(14, 8));
    expect(entity.vertices.length, 6);
    expect(entity.hasArrowHead, isTrue);
  });

  test('unknown fallback strokes survive FCB', () {
    final original = CadDocument()
      ..addEntity(
        UnknownEntity(
          id: 2,
          originalType: 'REGION',
          proxyBounds: const Bounds2(0, 0, 4, 3),
          strokes: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3]),
          strokeCounts: const [4],
        ),
      );
    final restored = FcbReader(FcbWriter().write(original)).decode().document;
    final entity = restored.entities.whereType<UnknownEntity>().single;
    expect(entity.originalType, 'REGION');
    expect(entity.strokes.length, 8);
    expect(entity.strokeCounts, const [4]);
    final sink = PolylineSink();
    entity.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
  });
}
