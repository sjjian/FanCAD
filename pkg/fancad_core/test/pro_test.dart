import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a hatch pattern produces strokes inside the boundary', () {
    final hatch = HatchEntity(
      id: 1,
      solid: false,
      patternName: 'ANSI31',
      loops: [
        HatchLoop(
          vertices: Float64List.fromList([0, 0, 20, 0, 20, 20, 0, 20]),
        ),
      ],
    );
    final strokes = const HatchGenerator().generate(hatch);
    expect(strokes, isNotEmpty);
    for (final stroke in strokes) {
      expect(stroke.length, greaterThanOrEqualTo(4));
    }
  });

  test('MTEXT wrapping splits a long paragraph', () {
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

  test('an empty SHX buffer is rejected without throwing', () {
    final font = ShxFont.parse(Uint8List(0));
    expect(font.isEmpty, isTrue);
  });

  test('a plot of a line is a well-formed PDF', () {
    final document = CadDocument();
    final session = DocumentSession(id: 't', document: document);
    session.edit('line', (transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 5)),
      );
    });
    final pdf = const Plotter().toPdf(document);
    final text = utf8.decode(pdf, allowMalformed: true);
    expect(pdf[0], 0x25); // %
    expect(text, startsWith('%PDF'));
    expect(text, contains('%%EOF'));
    expect(text, contains(' m\n'));
    expect(text, contains('\nS\n'));
    expect(text, contains('/MediaBox'));
  });

  test('a paper layout plot uses the sheet as the PDF page', () {
    final document = CadDocument();
    document.addLayout(
      const Layout(
        name: 'A3',
        blockName: '*Paper_Space',
        tabOrder: 1,
        paperWidth: 420,
        paperHeight: 297,
        viewports: [
          PaperViewport(
            paperBounds: Bounds2(20, 20, 200, 160),
            modelCenter: Vec2(5, 2.5),
            scale: 1,
          ),
        ],
      ),
    );
    document.setActiveLayout('A3');
    document.addEntity(
      const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(10, 5)),
    );

    final text = utf8.decode(
      const Plotter().toPdf(document),
      allowMalformed: true,
    );
    // 420 mm × 297 mm in points (72/25.4).
    expect(text, contains('1190.55'));
    expect(text, contains('841.88'));
    expect(text, contains('W n'));
  });

  test('a plot of a line is a well-formed SVG', () {
    final document = CadDocument();
    final session = DocumentSession(id: 't', document: document);
    session.edit('line', (transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 5)),
      );
    });
    final svg = const Plotter().toSvg(document);
    expect(svg, startsWith('<?xml'));
    expect(svg, contains('<svg'));
    expect(svg, contains('<path'));
    expect(svg, contains('</svg>'));
  });

  test('coalescing undo entries makes one turn one undo', () {
    final document = CadDocument();
    final session = DocumentSession(id: 't', document: document);
    session.edit('a', (t) {
      t.add(LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(1, 0)));
    });
    session.edit('b', (t) {
      t.add(LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(0, 1)));
    });
    expect(session.history.depth, 2);
    session.history.coalesceLast(2, label: 'Assistant turn');
    expect(session.history.depth, 1);
    session.undo();
    expect(document.entities, isEmpty);
  });
}
