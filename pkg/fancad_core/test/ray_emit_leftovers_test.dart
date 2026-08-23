import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished direction cannot invent a ray', () {
    final sink = PolylineSink();
    const RayEntity(
      id: 1,
      origin: Vec2(3, 4),
      direction: Vec2.zero(),
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
  });
}
