import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('clearing the stack cannot invent leftover undo', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    session.edit('draw', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    expect(session.history.canUndo, isTrue);
    session.history.clear();
    expect(session.history.canUndo, isFalse);
    expect(session.history.canRedo, isFalse);
    expect(session.undo(), isFalse);
    session.dispose();
  });
}
