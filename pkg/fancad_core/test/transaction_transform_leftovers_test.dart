import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an identity transform cannot invent leftover moves', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    final id = transaction.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    expect(transaction.transformAll([id, 99], const Mat3.identity()), 0);
    expect(transaction.transform(99, Mat3.translation(1, 0)), isFalse);
  });
}
