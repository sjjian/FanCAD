import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty or over-nested insert cannot invent block cells', () {
    const insert = InsertEntity(id: 1, blockName: '', position: Vec2.zero());
    final sink = PolylineSink();
    insert.emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.isEmpty, isTrue);

    const nested = InsertEntity(id: 2, blockName: 'CELL', position: Vec2.zero());
    nested.emit(const EmitContext(tolerance: 0.1, depth: 32), sink);
    expect(sink.isEmpty, isTrue);
  });
}
