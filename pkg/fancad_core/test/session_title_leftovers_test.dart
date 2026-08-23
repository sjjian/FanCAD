import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a slash-only path cannot invent an empty tab title', () {
    final session = DocumentSession(
      id: '7',
      document: CadDocument(),
      filePath: '/',
    );
    expect(session.title, 'Drawing7');
    session.dispose();
  });
}
