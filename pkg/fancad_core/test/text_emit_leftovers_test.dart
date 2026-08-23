import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('empty text cannot invent a glyph', () {
    final sink = PolylineSink();
    const TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: '',
      height: 2.5,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts, isEmpty);
  });
}
