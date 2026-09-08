import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

ShxFont _glyphA() => ShxFont(
  header: 'txt',
  above: 1,
  glyphs: {
    65: const ShxGlyph(
      code: 65,
      name: 'A',
      commands: [
        ShxDraw(to: Vec2.zero(), penDown: true),
        ShxDraw(to: Vec2(1, 1), penDown: true),
      ],
    ),
  },
);

void main() {
  test('empty text cannot invent a glyph', () {
    final sink = emit(
      const TextEntity(id: 1, position: Vec2.zero(), content: '', height: 2.5),
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isEmpty);
  });

  test('an SHX table strokes a style instead of emitting TextGeometry', () {
    final sink = PolylineSink();
    const TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'A',
      height: 10,
    ).emit(
      EmitContext(tolerance: 0.1, shxFonts: ShxFontTable({'txt': _glyphA()})),
      sink,
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isNotEmpty);
  });

  test('an empty SHX table still emits TextGeometry', () {
    final sink = emit(
      const TextEntity(id: 1, position: Vec2.zero(), content: 'A', height: 10),
    );
    expect(sink.texts.single.text, 'A');
    expect(sink.polylines, isEmpty);
  });

  test('a CJK note on an SHX style is not stroked as missing shapes', () {
    final sink = PolylineSink();
    const TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: '注释',
      height: 10,
    ).emit(
      EmitContext(tolerance: 0.1, shxFonts: ShxFontTable({'txt': _glyphA()})),
      sink,
    );
    expect(sink.texts.single.text, '注释');
  });

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
    final sink = emit(
      const TextEntity(
        id: 1,
        position: Vec2.zero(),
        content: '%%c10',
      ),
    );
    expect(sink.texts.single.text, 'Ø10');
  });
}
