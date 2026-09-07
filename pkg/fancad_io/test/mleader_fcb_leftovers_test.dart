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
    expect(entity.attachment, 4);

    final aligned = CadDocument()
      ..addEntity(
        MLeaderEntity(
          id: 2,
          vertices: Float64List.fromList([0, 0, 8, 8, 14, 8]),
          content: 'NOTE',
          textPosition: const Vec2(14, 8),
          attachment: 6,
        ),
      );
    final restoredAligned =
        FcbReader(FcbWriter().write(aligned)).decode().document;
    expect(
      restoredAligned.entities.whereType<MLeaderEntity>().single.attachment,
      6,
    );
  });

  test('a CJK font-coded note stays attached through FCB', () {
    final original = CadDocument()
      ..addEntity(
        MLeaderEntity(
          id: 3,
          vertices: Float64List.fromList([0, 0, 8, 8, 14, 8]),
          content: r'{\F宋体|c134;注释}',
          textPosition: const Vec2(14, 8),
          textHeight: 35,
          attachment: 6,
        ),
      );
    final entity = FcbReader(FcbWriter().write(original))
        .decode()
        .document
        .entities
        .whereType<MLeaderEntity>()
        .single;
    expect(entity.content, r'{\F宋体|c134;注释}');
    expect(entity.content, isNot('{'));
    final sink = PolylineSink();
    entity.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.text, '注释');
    expect(sink.texts.single.fontFamily, '宋体');
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
