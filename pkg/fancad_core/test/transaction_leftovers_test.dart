import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing or identical entity cannot invent a mutation', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    const missing = LineEntity(id: 99, start: Vec2.zero(), end: Vec2(10, 0));

    expect(transaction.erase(99), isFalse);
    expect(transaction.modify(missing), isFalse);
    expect(transaction.eraseAll([99, 100]), 0);
    expect(transaction.isEmpty, isTrue);

    final id = transaction.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 0)),
    );
    final current = document.entity(id)!;
    expect(transaction.modify(current), isFalse);
    expect(transaction.transform(id, const Mat3.identity()), isFalse);
  });

  test('an empty commit cannot invent an undo record', () {
    final document = CadDocument();
    final transaction = Transaction(document, label: 'noop');
    expect(transaction.commit(), isNull);
    expect(transaction.isCommitted, isTrue);
  });
}
