import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('fewer than three corners cannot invent a solid fill', () {
    final sink = PolylineSink();
    const SolidEntity(
      id: 1,
      corners: [Vec2.zero(), Vec2(4, 0)],
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.fills, isEmpty);
    expect(sink.polylines, isEmpty);
  });
}
