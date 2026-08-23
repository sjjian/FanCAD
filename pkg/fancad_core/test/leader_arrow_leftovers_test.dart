import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a leader without an arrow cannot invent a fill', () {
    final sink = PolylineSink();
    LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0, 4, 0]),
      hasArrowHead: false,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isNotEmpty);
    expect(sink.fills, isEmpty);
  });
}
