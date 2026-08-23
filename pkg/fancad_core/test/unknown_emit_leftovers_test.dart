import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown entity cannot invent drawable geometry', () {
    final sink = PolylineSink();
    const UnknownEntity(
      id: 1,
      originalType: 'PROXY',
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });
}
