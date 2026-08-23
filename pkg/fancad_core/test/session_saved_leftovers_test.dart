import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('marking saved cannot invent leftover dirty state', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    session.edit('draw', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    });
    expect(session.isDirty, isTrue);
    session.markSaved('/tmp/a.dwg');
    expect(session.isDirty, isFalse);
    expect(session.filePath, '/tmp/a.dwg');
    session.dispose();
  });
}
