import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing layer stays plottable and editable', () {
    final document = CadDocument();
    expect(document.isLayerPlottable('Notes'), isTrue);
    expect(document.isLayerEditable('Notes'), isTrue);

    document.putLayer(const LayerDef(name: 'Notes', plottable: false));
    expect(document.isLayerPlottable('Notes'), isFalse);

    document.putLayer(const LayerDef(name: 'Ice', frozen: true));
    expect(document.isLayerPlottable('Ice'), isFalse);
    expect(document.isLayerEditable('Ice'), isFalse);
  });

  test('a hidden entity or missing id cannot invent a pick or a remove', () {
    final document = CadDocument();
    const hidden = LineEntity(
      id: 1,
      props: EntityProps(visible: false),
      start: Vec2.zero(),
      end: Vec2(10, 0),
    );
    expect(document.isSelectable(hidden), isFalse);
    expect(document.removeEntity(99), isNull);
    expect(document.entity(99), isNull);
  });

  test('a locked layer can still be selected', () {
    final document = CadDocument()
      ..putLayer(const LayerDef(name: 'Lock', locked: true));
    const line = LineEntity(
      id: 1,
      props: EntityProps(layer: 'Lock'),
      start: Vec2.zero(),
      end: Vec2(10, 0),
    );
    expect(document.isLayerEditable('Lock'), isFalse);
    expect(document.isSelectable(line), isTrue);
  });
}
