import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty polyline cannot invent a stroke', () {
    final sink = PolylineSink();
    PolylineEntity(
      id: 1,
      vertices: Float64List(0),
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
  });
}
