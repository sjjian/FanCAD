import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a one-point loop cannot invent a hatch fill', () {
    final sink = PolylineSink();
    HatchEntity(
      id: 1,
      loops: [HatchLoop(vertices: Float64List.fromList([0, 0]))],
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, isEmpty);
    expect(sink.polylines, isEmpty);
  });
}
