import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
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

  test('top-right attachment shifts the box, not each row', () {
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
    expect(runs.first.origin.x, closeTo(runs.last.origin.x, 1e-9));
    expect(runs.first.origin.x, closeTo(100 - 4 * 10 * 0.6, 1e-9));
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
    expect(stripMTextFormatting(r'A\PB'), 'A\nB');
    expect(stripMTextFormatting(r'A\pi-2;B'), 'AB');
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

  test('a stacked fraction emits two runs and a bar', () {
    final sink = PolylineSink();
    const MTextEntity(
      id: 1,
      position: Vec2.zero(),
      content: r'\S1#2;',
      height: 10,
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.map((run) => run.text), ['1', '2']);
    expect(sink.polylines, hasLength(1));
    expect(sink.polylines.single.length, 4);
  });

  test('underline codes do not appear in the string', () {
    final runs = const MTextLayout().layout(
      const MTextEntity(id: 1, position: Vec2.zero(), content: r'\Ltext\l'),
    );
    expect(runs.single.text, 'text');
    expect(runs.single.underline, isTrue);
    expect(stripMTextFormatting(r'\Ltext\l'), 'text');

    final sink = PolylineSink();
    const MTextEntity(
      id: 2,
      position: Vec2.zero(),
      content: r'\Ltext\l',
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.underline, isTrue);
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
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: r'\pxqc;Hi',
      ),
    );
    expect(centered.single.hAlign, TextHAlign.center);
  });

  test('an inline colour rides with the run', () {
    final sink = PolylineSink();
    const MTextEntity(
      id: 1,
      position: Vec2.zero(),
      content: r'\C3;Hi',
    ).emit(const EmitContext(tolerance: 0.1), sink);
    expect(sink.texts.single.text, 'Hi');
  });
}
