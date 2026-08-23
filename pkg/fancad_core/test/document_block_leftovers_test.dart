import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing block cannot invent members or emission', () {
    final document = CadDocument();
    expect(document.entityIdsOf('NOPE'), isNull);
    expect(document.entitiesOf('NOPE'), isEmpty);

    final sink = PolylineSink();
    document.emitBlock('NOPE', const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);
  });
}
