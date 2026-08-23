import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty spline cannot invent a stroke', () {
    final sink = PolylineSink();
    SplineEntity(
      id: 1,
      controlPoints: Float64List(0),
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
  });
}
