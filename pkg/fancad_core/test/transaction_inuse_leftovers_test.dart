import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a layer still in use cannot invent a drop', () {
    final document = CadDocument();
    final transaction = Transaction(document);
    transaction.putLayer(const LayerDef(name: 'WALLS'));
    transaction.add(
      const LineEntity(
        id: 0,
        props: EntityProps(layer: 'WALLS'),
        start: Vec2.zero(),
        end: Vec2(4, 0),
      ),
    );
    expect(transaction.removeLayer('WALLS'), isFalse);
  });
}
