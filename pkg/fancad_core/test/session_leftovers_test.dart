import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty stack cannot invent an undo or redo', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    expect(session.undo(), isFalse);
    expect(session.redo(), isFalse);
    expect(session.isDirty, isFalse);
    session.dispose();
  });

  test('an empty edit cannot invent a dirty session', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    final committed = session.edit('noop', (_) {});
    expect(committed, isNull);
    expect(session.isDirty, isFalse);
    expect(session.undo(), isFalse);
    session.dispose();
  });
}
