import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty external change cannot invent a notification', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    final changes = <DocumentChange>[];
    final sub = session.changes.listen(changes.add);

    session.notifyExternalChange(const DocumentChange());
    expect(changes, isEmpty);

    sub.cancel();
    session.dispose();
  });
}
