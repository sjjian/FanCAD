import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an importer edit cannot invent a dirty flag', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    final committed = session.edit('load', (transaction) {
      transaction.add(
        const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
      );
    }, source: ChangeSource.importer);
    expect(committed, isNotNull);
    expect(session.isDirty, isFalse);
    session.dispose();
  });
}
