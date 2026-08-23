import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an importer push cannot invent an undo entry', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    session.edit('load', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    }, source: ChangeSource.importer);
    expect(session.history.canUndo, isFalse);
    expect(session.undo(), isFalse);
    session.dispose();
  });
}
