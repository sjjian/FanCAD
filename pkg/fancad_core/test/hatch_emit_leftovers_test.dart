import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty hatch cannot invent a fill', () {
    final sink = PolylineSink();
    const HatchEntity(id: 1, loops: []).emit(
      const EmitContext(tolerance: 0.1),
      sink,
    );
    expect(sink.fills, isEmpty);
    expect(sink.polylines, isEmpty);
  });
}
