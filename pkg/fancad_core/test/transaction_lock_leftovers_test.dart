import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a locked layer cannot invent an erase or a move', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'LOCK', locked: true));
    final id = document
        .addEntity(
          const LineEntity(
            id: 1,
            props: EntityProps(layer: 'LOCK'),
            start: Vec2.zero(),
            end: Vec2(4, 0),
          ),
        )
        .id;
    final transaction = Transaction(document);
    expect(transaction.erase(id), isFalse);
    expect(transaction.transform(id, const Mat3.translation(1, 0)), isFalse);
    expect(transaction.isEmpty, isTrue);
    expect(transaction.skipped, [id, id]);
    expect(document.entity(id), isNotNull);
  });
}
