import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a vanished radius cannot invent an arc stroke', () {
    final sink = PolylineSink();
    const ArcEntity(
      id: 1,
      center: Vec2.zero(),
      radius: 0,
      startAngle: 0,
      endAngle: 1.5,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.polylines, isEmpty);
  });
}
