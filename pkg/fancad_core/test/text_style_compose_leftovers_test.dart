import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a STYLE width factor multiplies the entity factor', () {
    final document = CadDocument()
      ..putTextStyle(
        const TextStyleDef(name: 'Notes', widthFactor: 0.8, height: 0),
      );
    document.addEntity(
      const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'AB',
        height: 10,
        widthFactor: 2,
        styleName: 'Notes',
      ),
    );
    final sink = PolylineSink();
    document.entities.first.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.widthFactor, closeTo(1.6, 1e-9));
    expect(sink.texts.single.height, closeTo(10, 1e-9));
  });

  test('a STYLE fixed height wins over the entity height', () {
    final document = CadDocument()
      ..putTextStyle(const TextStyleDef(name: 'Title', height: 5));
    document.addEntity(
      const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'T',
        height: 99,
        styleName: 'Title',
      ),
    );
    final sink = PolylineSink();
    document.entities.first.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.height, closeTo(5, 1e-9));
  });

  test('oblique on the style adds to the entity', () {
    final document = CadDocument()
      ..putTextStyle(const TextStyleDef(name: 'Slant', obliqueAngle: 0.1));
    document.addEntity(
      const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'S',
        obliqueAngle: 0.2,
        styleName: 'Slant',
      ),
    );
    final sink = PolylineSink();
    document.entities.first.emit(document.emitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.obliqueAngle, closeTo(0.3, 1e-9));
  });

  test('percent codes expand before a glyph is emitted', () {
    expect(expandDxfTextCodes('%%d %%c %%p %%065'), '° Ø ± A');
    final sink = PolylineSink();
    const TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: '%%c10',
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.text, 'Ø10');
  });
}
