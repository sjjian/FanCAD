import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a suppressed override cannot invent dimension text', () {
    final sink = PolylineSink();
    const graphics = DimensionGraphics();
    graphics.emit(
      const DimensionEntity(
        id: 1,
        definitionPoints: [],
        measurement: 4,
        overrideText: ' ',
      ),
      const EmitContext(tolerance: 0.1),
      sink,
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isEmpty);
  });
}
