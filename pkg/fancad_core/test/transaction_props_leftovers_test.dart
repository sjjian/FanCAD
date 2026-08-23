import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('identical props cannot invent a property edit', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    final id = transaction.add(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(4, 0)),
    );
    final current = document.entity(id)!;
    expect(transaction.setProps(id, current.props), isFalse);
    expect(transaction.setLayerOf([99], 'WALLS'), 0);
    expect(transaction.setVisibleOf([99], false), 0);
  });
}
