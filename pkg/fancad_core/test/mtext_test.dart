import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('stripMTextFormatting', () {
    test('keeps readable text and turns \\P into a line break', () {
      expect(stripMTextFormatting(r'A\P\~B\{'), 'A\n B{');
      expect(stripMTextFormatting(r'\C1;red'), 'red');
      expect(stripMTextFormatting(r'\Xno-semi'), 'no-semi');
    });
  });

  group('MTextLayout', () {
    test('width 0 keeps a paragraph on one run', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2(3, 4),
          content: r'Hello\Pworld',
          height: 2.5,
        ),
      );
      expect(runs.map((run) => run.text), ['Hello', 'world']);
      expect(runs.first.origin, const Vec2(3, 4));
      expect(runs.last.origin.y, lessThan(4));
    });

    test('a narrow column wraps on word boundaries', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: 'one two three',
          height: 2.5,
          rectangleWidth: 8,
        ),
      );
      expect(runs.length, greaterThan(1));
      expect(runs.every((run) => run.text.split(' ').length <= 2), isTrue);
    });

    test('font and colour codes attach to the following run', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'{\fArial|b1|i1;\C3;Hi}',
          height: 2.5,
        ),
      );
      expect(runs, isNotEmpty);
      expect(runs.first.text, 'Hi');
      expect(runs.first.bold, isTrue);
      expect(runs.first.italic, isTrue);
      expect(runs.first.font, 'Arial');
      expect(runs.first.color, 3);
    });

    test('a height override applies to that span', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'\H5;big',
          height: 2.5,
        ),
      );
      expect(runs.single.height, 5);
    });
  });

  group('ShxFont', () {
    test('truncated or headerless buffers stay empty', () {
      expect(ShxFont.parse(Uint8List.fromList([1, 2, 3])).isEmpty, isTrue);
      final noSub = Uint8List.fromList(List<int>.filled(30, 65));
      expect(ShxFont.parse(noSub).isEmpty, isTrue);
    });

    test('missing glyphs advance the cursor without throwing', () {
      final font = ShxFont(header: 'txt', glyphs: const {});
      expect(
        font.layout('AB', origin: const Vec2.zero(), height: 10),
        isEmpty,
      );
    });

    test('a stroked glyph produces a polyline at the requested height', () {
      final font = ShxFont(
        header: 'txt',
        above: 1,
        glyphs: {
          65: const ShxGlyph(
            code: 65,
            name: 'A',
            commands: [
              ShxDraw(to: Vec2(0, 0), penDown: true),
              ShxDraw(to: Vec2(1, 1), penDown: true),
            ],
          ),
        },
      );
      final strokes = font.layout(
        'A',
        origin: const Vec2.zero(),
        height: 10,
      );
      expect(strokes, isNotEmpty);
      expect(strokes.first.length, greaterThanOrEqualTo(2));
      expect(font.glyph(65)?.name, 'A');
      expect(font.measureWidth('A', height: 10), closeTo(10, 1e-9));
      expect(font.measureWidth('AA', height: 10), closeTo(20, 1e-9));
    });
  });

  test('MTEXT wrapping uses a supplied measured width', () {
    final runs = MTextLayout(
      measureWidth: (text, height) => text.length * height,
    ).layout(
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'aa bb',
        height: 10,
        rectangleWidth: 25,
      ),
    );
    expect(runs.map((run) => run.text), ['aa', 'bb']);
  });

  group('MTextEntity', () {
    test('attachment points map to the nine AutoCAD corners', () {
      TextHAlign hOf(int attachment) =>
          MTextEntity(id: 1, position: Vec2.zero(), content: 'A', attachment: attachment)
              .hAlign;
      TextVAlign vOf(int attachment) =>
          MTextEntity(id: 1, position: Vec2.zero(), content: 'A', attachment: attachment)
              .vAlign;

      expect(hOf(1), TextHAlign.left);
      expect(vOf(1), TextVAlign.top);
      expect(hOf(5), TextHAlign.center);
      expect(vOf(5), TextVAlign.middle);
      expect(hOf(9), TextHAlign.right);
      expect(vOf(9), TextVAlign.bottom);
      expect(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'A\PB',
        ).plainText,
        'A\nB',
      );
    });

    test('empty content is silent and a grip moves the insertion', () {
      const text = MTextEntity(
        id: 1,
        position: Vec2(2, 3),
        content: r'Hello\Pworld',
        height: 2.5,
        attachment: 3,
      );
      final emptySink = PolylineSink();
      const MTextEntity(id: 2, position: Vec2.zero(), content: '').emit(
        const EmitContext(tolerance: 0.1),
        emptySink,
      );
      expect(emptySink.texts, isEmpty);

      final sink = PolylineSink();
      text.emit(const EmitContext(tolerance: 0.1), sink);
      expect(sink.texts.map((run) => run.text), ['Hello', 'world']);
      expect(sink.texts.every((run) => !run.isMultiline), isTrue);
      expect(sink.texts.first.hAlign, TextHAlign.right);
      expect(sink.texts.first.vAlign, TextVAlign.top);
      expect(sink.texts.last.origin.y, lessThan(sink.texts.first.origin.y));

      expect(text.grips(), const [Vec2(2, 3)]);
      expect(
        text.withGrip(0, const Vec2(8, 1)).position,
        const Vec2(8, 1),
      );
      final scaled = text.transformed(const Mat3.scaling(2, 2));
      expect(scaled.height, 5);
      expect(scaled.attachment, 3);
    });
  });
}
