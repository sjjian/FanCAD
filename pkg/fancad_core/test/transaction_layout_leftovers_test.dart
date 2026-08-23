import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('model space or a missing tab cannot invent a drop', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    expect(transaction.removeLayout('NOPE'), isFalse);
    expect(transaction.removeLayout('Model'), isFalse);
    expect(transaction.isEmpty, isTrue);
  });
}
