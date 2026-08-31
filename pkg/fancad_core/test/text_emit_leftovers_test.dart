import 'package:fancad_core/fancad_core.dart';
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
    final sink = PolylineSink();
    const TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: '',
      height: 2.5,
    ).emit(const EmitContext(tolerance: 0.1), sink);
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
      EmitContext(
        tolerance: 0.1,
        shxFonts: ShxFontTable({'txt': _glyphA()}),
      ),
      sink,
    );
    expect(sink.texts, isEmpty);
    expect(sink.polylines, isNotEmpty);
  });

  test('an empty SHX table still emits TextGeometry', () {
    final sink = PolylineSink();
    const TextEntity(
      id: 1,
      position: Vec2.zero(),
      content: 'A',
      height: 10,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.text, 'A');
    expect(sink.polylines, isEmpty);
  });
}
