import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('rolling back an empty transaction cannot invent a change', () {
    final document = CadDocument();
    final transaction = Transaction(document, label: 'noop');
    expect(transaction.rollback().isEmpty, isTrue);
    expect(transaction.isCommitted, isTrue);
    expect(document.isEmpty, isTrue);
  });
}
