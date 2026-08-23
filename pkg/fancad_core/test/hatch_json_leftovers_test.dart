import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('junk hatch loops cannot invent a boundary', () {
    final hatch = CadEntity.fromJson(const {
      'type': 'hatch',
      'loops': 'nope',
    }) as HatchEntity;
    expect(hatch.loops, isEmpty);
    final sink = PolylineSink();
    hatch.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });
}
