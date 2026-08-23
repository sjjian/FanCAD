import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('coincident definition points cannot invent a dimension line', () {
    const graphics = DimensionGraphics();
    const context = EmitContext(tolerance: 0.1);
    final sink = PolylineSink();

    graphics.emit(
      const DimensionEntity(
        id: 1,
        definitionPoints: [Vec2.zero(), Vec2.zero()],
        measurement: 4,
      ),
      context,
      sink,
    );

    expect(sink.polylines, isEmpty);
    expect(sink.fills, isEmpty);
    expect(sink.texts.single.text, '4.00');
  });
}
