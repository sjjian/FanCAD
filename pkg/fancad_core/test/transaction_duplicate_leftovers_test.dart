import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('duplicating a missing id cannot invent a copy', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    expect(transaction.duplicate([99], Mat3.translation(10, 0)), isEmpty);
    expect(transaction.isEmpty, isTrue);
  });
}
