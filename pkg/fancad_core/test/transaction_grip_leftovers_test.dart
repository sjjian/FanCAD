import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an out-of-range grip cannot invent a mutation', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    final id = transaction.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    expect(transaction.moveGrip(id, 99, const Vec2(1, 1)), isFalse);
    expect(transaction.moveGrip(99, 0, const Vec2(1, 1)), isFalse);
  });
}
