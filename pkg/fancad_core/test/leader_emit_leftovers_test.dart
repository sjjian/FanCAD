import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a lone vertex cannot invent a leader stroke', () {
    final sink = PolylineSink();
    LeaderEntity(
      id: 1,
      vertices: Float64List.fromList([0, 0]),
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
    expect(sink.fills, isEmpty);
  });
}
