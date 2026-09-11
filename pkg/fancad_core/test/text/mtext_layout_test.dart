import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('stripMTextFormatting', () {
    test('keeps readable text and turns \\P into a line break', () {
      expect(stripMTextFormatting(r'A\P\~B\{'), 'A\n B{');
      expect(stripMTextFormatting(r'\C1;red'), 'red');
      expect(stripMTextFormatting(r'\Xno-semi'), 'no-semi');
      expect(stripMTextFormatting(r'A\{'), 'A{');
      expect(stripMTextFormatting(r'A\P\P'), 'A\n\n');
      expect(stripMTextFormatting(r'\X99;Hi'), 'Hi');
      expect(stripMTextFormatting(r'A\PB'), 'A\nB');
      expect(stripMTextFormatting(r'A\pi-2;B'), 'AB');
      expect(stripMTextFormatting(r'{\fArial|b1;Bold}\Pnext'), 'Bold\nnext');
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

    test('wrapping splits a paragraph that already contains a break', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'Hello\Pworld {\fArial|b1;bold} text',
          height: 2.5,
          rectangleWidth: 20,
        ),
      );
      expect(runs, isNotEmpty);
      expect(runs.any((run) => run.text.contains('Hello')), isTrue);
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

    test('empty or whitespace content cannot invent a wrapped note', () {
      final empty = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: ''),
      );
      expect(empty, hasLength(1));
      expect(empty.single.text, isEmpty);
      final spaces = const MTextLayout().layout(
        const MTextEntity(
          id: 2,
          position: Vec2.zero(),
          content: '   ',
          rectangleWidth: 8,
          height: 2.5,
        ),
      );
      expect(spaces.every((run) => run.text.trim().isEmpty), isTrue);
    });

    test('an unclosed code cannot invent leftover formatting', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'Hi\C'),
      );
      expect(runs.map((run) => run.text).join(), 'Hi');
      expect(runs.every((run) => run.color == null), isTrue);
    });

    test('an unknown directive cannot invent leftover formatting', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'\X99;Hi'),
      );
      expect(runs.single.text, 'Hi');
      expect(runs.single.color, isNull);
      expect(runs.single.font, isEmpty);
      expect(runs.single.bold, isFalse);
      expect(runs.single.height, 2.5);
    });

    test('relative height multiplies the entity height', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'\H2x;big',
          height: 2.5,
        ),
      );
      expect(runs.single.height, closeTo(5, 1e-9));
    });

    test('width, oblique and tracking attach to the run', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'\W0.8;\Q15;\T1.5;Hi',
          height: 2.5,
        ),
      );
      expect(runs.single.text, 'Hi');
      expect(runs.single.widthFactor, closeTo(0.8, 1e-9));
      expect(
        runs.single.obliqueAngle,
        closeTo(15 * 3.141592653589793 / 180, 1e-9),
      );
      expect(runs.single.tracking, closeTo(1.5, 1e-9));
    });

    test('a CJK font switch is not part of the dimension note', () {
      const raw = r'{\F宋体|c134;型材1}';
      expect(stripMTextFormatting(raw), '型材1');
      expect(decodeDrawnText(raw), '型材1');
      expect(
        const MTextLayout()
            .layout(
              const MTextEntity(
                id: 1,
                position: Vec2.zero(),
                content: raw,
                height: 2.5,
              ),
            )
            .single
            .text,
        '型材1',
      );
    });

    test('an in-place edit keeps paragraph codes around the glyphs', () {
      expect(replaceMTextPlain(r'\pxqc;外墙', '内墙'), r'\pxqc;内墙');
      expect(replaceMTextPlain(r'{\F宋体|c134;型材1}', '型材2'), r'{\F宋体|c134;型材2}');
      expect(replaceMTextPlain(r'\pxqc;外墙', '外墙'), r'\pxqc;外墙');
      expect(replaceMTextPlain(r'A\PB', 'A\nC'), r'A\PC');
    });

    test('a paragraph indent cannot leak into the glyph string', () {
      const entity = MTextEntity(
        id: 1,
        position: Vec2(100, 50),
        content: r'\pi-167.41;XDFB-J01',
        height: 60,
      );
      final runs = const MTextLayout().layout(entity);
      expect(runs.single.text, 'XDFB-J01');
      expect(runs.single.origin.x, closeTo(100 - 167.41, 1e-9));
      expect(stripMTextFormatting(r'\pi-167.41;XDFB-J01'), 'XDFB-J01');
    });

    test('a \\P row sits a full AutoCAD line below the previous', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2(10, 50),
          content: r'A\PB',
          height: 12,
        ),
      );
      expect(runs.map((run) => run.text), ['A', 'B']);
      expect(runs.last.origin.y, closeTo(50 - 12 * 5 / 3, 1e-9));
    });

    test('a second-paragraph indent cannot land on the previous row', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2(600, 80),
          content: r'\pi-200;第一行很长的工艺说明\P\pi-40;板背贴板号',
          height: 30,
        ),
      );
      expect(runs.map((run) => run.text), ['第一行很长的工艺说明', '板背贴板号']);
      expect(runs.first.origin.x, closeTo(400, 1e-9));
      expect(runs.last.origin.x, closeTo(560, 1e-9));
      expect(runs.last.origin.y, closeTo(80 - 30 * 5 / 3, 1e-9));
    });

    test('hugging top-right keeps the column on the insertion', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2(100, 50),
          content: r'A\PBBBB',
          height: 10,
          attachment: 3,
        ),
      );
      expect(runs.map((run) => run.text), ['A', 'BBBB']);
      expect(runs.first.origin.x, closeTo(100, 1e-9));
      expect(runs.last.origin.x, closeTo(100, 1e-9));
    });

    test('a hugging right leader note sits on the landing', () {
      final runs = const MTextLayout(hugToAttachment: true).layout(
        const MTextEntity(
          id: 1,
          position: Vec2(100, 50),
          content: '注释',
          height: 10,
          attachment: 6,
        ),
      );
      expect(runs.single.text, '注释');
      expect(runs.single.origin.x, closeTo(100 - 2 * 10 * 0.6, 1e-9));
    });

    test('a defined top-right box still sits on the insertion', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2(100, 50),
          content: r'A\PBBBB',
          height: 10,
          rectangleWidth: 40,
          attachment: 3,
        ),
      );
      expect(runs.map((run) => run.text), ['A', 'BBBB']);
      expect(runs.first.origin.x + 10 * 0.6, closeTo(100, 1e-9));
      expect(runs.last.origin.x + 4 * 10 * 0.6, closeTo(100, 1e-9));
    });

    test('a hugging centre label stays on its point', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2(100, 50),
          content: 'Hi',
          height: 10,
          attachment: 5,
        ),
      );
      expect(runs.single.origin.x, closeTo(100 - 2 * 10 * 0.6 / 2, 1e-9));
    });

    test('capital \\P still breaks; lowercase \\p never does', () {
      final broken = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'A\PB'),
      );
      expect(broken.map((run) => run.text), ['A', 'B']);

      final indented = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'A\pi-2;B'),
      );
      expect(indented.map((run) => run.text).join(), 'AB');
      expect(indented.first.origin.x, closeTo(-2, 1e-9));
    });

    test('a brace restores the height of the following glyph', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'{\H2x;A}B',
          height: 2.5,
        ),
      );
      expect(runs.map((run) => run.text), ['A', 'B']);
      expect(runs.first.height, closeTo(5, 1e-9));
      expect(runs.last.height, closeTo(2.5, 1e-9));
    });

    test('a unicode escape cannot leak U+', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'\U+00B0C'),
      );
      expect(runs.single.text, '°C');
      expect(stripMTextFormatting(r'\U+00B0'), '°');
    });

    test('underline codes do not appear in the string', () {
      final runs = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'\Ltext\l'),
      );
      expect(runs.single.text, 'text');
      expect(runs.single.underline, isTrue);
      expect(stripMTextFormatting(r'\Ltext\l'), 'text');
    });

    test('line alignment and paragraph justify stay on the run', () {
      final aligned = const MTextLayout().layout(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: r'{\A2;\H5;T}{\A0;\H2;b}',
          height: 2,
        ),
      );
      expect(aligned.map((run) => run.text), ['T', 'b']);
      expect(aligned.first.origin.y, greaterThan(aligned.last.origin.y));

      final centered = const MTextLayout().layout(
        const MTextEntity(id: 1, position: Vec2.zero(), content: r'\pxqc;Hi'),
      );
      expect(centered.single.hAlign, TextHAlign.center);
    });
  });

  test('MTEXT wrapping uses a supplied measured width', () {
    final runs =
        MTextLayout(
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
      TextHAlign hOf(int attachment) => MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'A',
        attachment: attachment,
      ).hAlign;
      TextVAlign vOf(int attachment) => MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'A',
        attachment: attachment,
      ).vAlign;

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
      const MTextEntity(
        id: 2,
        position: Vec2.zero(),
        content: '',
      ).emit(const EmitContext(tolerance: 0.1), emptySink);
      expect(emptySink.texts, isEmpty);

      final sink = PolylineSink();
      text.emit(const EmitContext(tolerance: 0.1), sink);
      expect(sink.texts.map((run) => run.text), ['Hello', 'world']);
      expect(sink.texts.every((run) => !run.isMultiline), isTrue);
      expect(sink.texts.first.hAlign, TextHAlign.left);
      expect(sink.texts.first.vAlign, TextVAlign.top);
      expect(sink.texts.first.origin.x, closeTo(text.position.x, 1e-9));
      expect(
        sink.texts.last.origin.x,
        closeTo(sink.texts.first.origin.x, 1e-9),
      );
      expect(sink.texts.last.origin.y, lessThan(sink.texts.first.origin.y));

      expect(text.grips(), const [Vec2(2, 3)]);
      expect(text.withGrip(0, const Vec2(8, 1)).position, const Vec2(8, 1));
      final scaled = text.transformed(const Mat3.scaling(2, 2));
      expect(scaled.height, 5);
      expect(scaled.attachment, 3);
    });
  });
}
