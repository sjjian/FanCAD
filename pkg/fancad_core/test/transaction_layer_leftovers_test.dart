import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('layer 0 or a missing name cannot invent a drop', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    expect(transaction.removeLayer('0'), isFalse);
    expect(transaction.removeLayer('NOPE'), isFalse);
    expect(transaction.isEmpty, isTrue);
  });
}
