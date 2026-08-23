import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a disposed session cannot invent leftover change events', () async {
    final session = DocumentSession(id: 't', document: CadDocument());
    final seen = <DocumentChange>[];
    final sub = session.changes.listen(seen.add);
    session.dispose();
    session.notifyExternalChange(const DocumentChange(tablesChanged: true));
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
    await sub.cancel();
  });
}
