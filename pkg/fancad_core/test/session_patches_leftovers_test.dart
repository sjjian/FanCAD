import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty patch list cannot invent a dirty session', () {
    final session = DocumentSession(id: 't', document: CadDocument());
    expect(session.applyPatches('ai', const []), isNull);
    expect(session.isDirty, isFalse);
    session.dispose();
  });
}
