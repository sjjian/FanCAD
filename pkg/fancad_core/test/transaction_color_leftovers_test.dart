import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing id cannot invent a color or linetype edit', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    expect(transaction.setColorOf([99], const CadColor.indexed(3)), 0);
    expect(transaction.setLineTypeOf([99], 'DASHED'), 0);
    expect(transaction.setLineWeightOf([99], 25), 0);
    expect(transaction.isEmpty, isTrue);
  });
}
