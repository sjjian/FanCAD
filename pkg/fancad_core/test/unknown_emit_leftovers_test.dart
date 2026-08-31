import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown entity without strokes cannot invent drawable geometry', () {
    final sink = PolylineSink();
    UnknownEntity(
      id: 1,
      originalType: 'PROXY',
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });

  test('an unknown entity emits imported fallback strokes', () {
    final sink = PolylineSink();
    UnknownEntity(
      id: 2,
      originalType: 'REGION',
      strokes: Float64List.fromList([0, 0, 4, 0, 4, 3, 0, 3]),
      strokeCounts: const [4],
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.polylines.first.length, 8);
  });
}
