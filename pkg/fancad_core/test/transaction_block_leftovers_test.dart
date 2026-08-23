import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing or layout block cannot invent a drop', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    expect(transaction.removeBlock('NOPE'), isFalse);
    expect(transaction.removeBlock('*Model_Space'), isFalse);
    expect(transaction.isEmpty, isTrue);
  });
}
