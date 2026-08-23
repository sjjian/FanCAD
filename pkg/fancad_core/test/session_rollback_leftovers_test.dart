import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a thrown edit cannot invent leftover geometry', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    expect(
      () => session.edit('boom', (transaction) {
        transaction.add(
          const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
        );
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(session.document.entities, isEmpty);
    expect(session.isDirty, isFalse);
    expect(session.undo(), isFalse);
    session.dispose();
  });
}
