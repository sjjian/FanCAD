import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('setting the current layer to itself cannot invent a patch', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    transaction.setCurrentLayer('0');
    expect(transaction.isEmpty, isTrue);
    transaction.setCurrentDimStyle('Standard');
    expect(transaction.isEmpty, isTrue);
  });
}
