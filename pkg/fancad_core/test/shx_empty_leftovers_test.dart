import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty font cannot invent layout strokes', () {
    final font = ShxFont(header: 'empty', glyphs: const {});
    expect(font.isEmpty, isTrue);
    expect(font.layout('ABC', origin: const Vec2.zero(), height: 10), isEmpty);
    expect(font.glyph(65), isNull);
  });
}
