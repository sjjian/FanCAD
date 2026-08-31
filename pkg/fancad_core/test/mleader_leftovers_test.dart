import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a lone vertex cannot invent a multileader stroke', () {
    final sink = PolylineSink();
    MLeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0]),
      content: 'NOTE',
      textHeight: 2.5,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
  });

  test('a multileader emits its path and note as one object', () {
    final sink = PolylineSink();
    final entity = MLeaderEntity(
      id: 2,
      vertices: Float64List.fromList([0, 0, 10, 10, 16, 10]),
      content: 'J15',
      textPosition: const Vec2(16, 10),
      textHeight: 2.5,
    );
    entity.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.texts, isNotEmpty);
    expect(sink.texts.single.text, 'J15');
    expect(entity.grips().last, const Vec2(16, 10));

    final moved = entity.withGrip(3, const Vec2(20, 12));
    expect(moved.textPosition, const Vec2(20, 12));
    expect(moved.vertices, entity.vertices);
  });

  test('Construct.mleader keeps the note on the same entity', () {
    expect(
      Construct.mleader(const [Vec2.zero(), Vec2(4, 0)], textHeight: 0),
      isNull,
    );
    final created = Construct.mleader(
      const [Vec2.zero(), Vec2(10, 4)],
      annotation: 'QC',
    );
    expect(created, isNotNull);
    expect(created!.content, 'QC');
    expect(created.vertices.length, greaterThanOrEqualTo(6));
  });
}
