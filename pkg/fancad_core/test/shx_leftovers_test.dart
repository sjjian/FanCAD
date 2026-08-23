import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a truncated table after the SHX header cannot invent glyphs', () {
    final bytes = Uint8List.fromList([
      ...latin1.encode('AutoCAD-86 shapes 1.0'),
      0x1A,
      1,
      2,
    ]);
    final font = ShxFont.parse(bytes);
    expect(font.header, contains('AutoCAD-86'));
    expect(font.isEmpty, isTrue);
    expect(font.glyph(65), isNull);
  });

  test('an unknown code uses the fallback glyph instead of inventing strokes', () {
    final font = ShxFont(
      header: 'txt',
      above: 0,
      glyphs: {
        0x3F: const ShxGlyph(
          code: 0x3F,
          name: 'Q',
          commands: [
            ShxDraw(to: Vec2.zero(), penDown: true),
            ShxDraw(to: Vec2(1, 1), penDown: true),
          ],
        ),
      },
    );

    expect(font.glyph(65), isNull);
    expect(font.glyph(0x3F)?.name, 'Q');
    final strokes = font.layout('A', origin: const Vec2.zero(), height: 10);
    expect(strokes, isNotEmpty);
    expect(strokes.first.last, const Vec2(10, 10));
  });
}
