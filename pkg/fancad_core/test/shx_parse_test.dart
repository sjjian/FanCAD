import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

Uint8List _u16(int value) => Uint8List.fromList([value & 0xFF, (value >> 8) & 0xFF]);

Uint8List _shx({
  String header = 'AutoCAD-86 shapes 1.0',
  int low = 0,
  int high = 255,
  required List<(int code, String name, List<int> shape)> glyphs,
}) {
  final out = <int>[...latin1.encode(header), 0x1A, ..._u16(low), ..._u16(high), ..._u16(glyphs.length)];
  for (final (code, name, shape) in glyphs) {
    final payload = <int>[...latin1.encode(name), 0, ...shape];
    out.addAll(_u16(code));
    out.addAll(_u16(payload.length));
    out.addAll(payload);
  }
  return Uint8List.fromList(out);
}

void main() {
  test('parse reads the header table and a named glyph', () {
    final font = ShxFont.parse(
      _shx(
        glyphs: [
          (
            0,
            '',
            [8, 0, 8, 8, 0, 3, 0],
          ),
          (
            65,
            'A',
            [
              1,
              8, 4, 0,
              2,
              8, 0, 4,
              1,
              8, 4, 0,
              0,
            ],
          ),
        ],
      ),
    );

    expect(font.isEmpty, isFalse);
    expect(font.header, contains('AutoCAD-86'));
    expect(font.above, 8);
    expect(font.below, 11);
    expect(font.glyph(65)?.name, 'A');
    expect(font.glyph(0x141)?.name, 'A');

    final strokes = font.layout(
      'A',
      origin: const Vec2(1, 2),
      height: 8,
      rotation: 0,
      widthFactor: 1,
    );
    expect(strokes, isNotEmpty);
    expect(strokes.first.length, greaterThanOrEqualTo(2));
  });

  test('decode walks scale, vector, arc-skip and vertical-only opcodes', () {
    final font = ShxFont.parse(
      _shx(
        glyphs: [
          (
            66,
            'B',
            [
              3, 2,
              4, 2,
              5,
              6,
              9, 2, 0, 0, 0,
              0x0A, 1,
              0x0B, 1, 2, 3, 4, 5,
              0x0C, 3, 0, 0,
              0x0E,
              0x14,
              0x0E,
              0x14,
              0,
            ],
          ),
        ],
      ),
    );

    final glyph = font.glyph(66)!;
    expect(glyph.commands, isNotEmpty);
    expect(glyph.commands.any((draw) => draw.penDown), isTrue);

    final rotated = font.layout(
      'B',
      origin: const Vec2.zero(),
      height: 10,
      rotation: 1.5707963267948966,
      widthFactor: 2,
    );
    expect(rotated, isNotEmpty);
  });

  test('a zero-count table or nameless payload cannot invent a font metric', () {
    final emptyTable = ShxFont.parse(_shx(low: 0, high: 0, glyphs: const []));
    expect(emptyTable.isEmpty, isTrue);
    expect(emptyTable.above, 1);
    expect(emptyTable.below, 0);

    final nameless = ShxFont.parse(
      _shx(
        glyphs: [
          (67, '', [8, 1, 0, 0]),
        ],
      ),
    );
    expect(nameless.glyph(67)?.name, isEmpty);
    expect(nameless.glyph(67)?.commands, isNotEmpty);
  });
}
