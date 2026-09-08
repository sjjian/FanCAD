import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  test('empty mtext cannot invent a glyph', () {
    expect(
      emit(
        const MTextEntity(
          id: 1,
          position: Vec2.zero(),
          content: '',
          height: 2.5,
        ),
      ).texts,
      isEmpty,
    );
  });

  test('an MTEXT run keeps a box anchor after emit', () {
    final sink = emit(
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: 'Note',
        attachment: 1,
      ),
    );
    expect(sink.texts.single.anchor, TextAnchor.box);
    expect(sink.texts.single.vAlign, TextVAlign.top);
  });

  test('a stacked fraction emits two runs and a bar', () {
    final sink = emit(
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: r'\S1#2;',
        height: 10,
      ),
    );
    expect(sink.texts.map((run) => run.text), ['1', '2']);
    expect(sink.polylines, hasLength(1));
    expect(sink.polylines.single.length, 4);
  });

  test('underline codes do not appear in the string', () {
    final sink = emit(
      const MTextEntity(
        id: 2,
        position: Vec2.zero(),
        content: r'\Ltext\l',
      ),
    );
    expect(sink.texts.single.underline, isTrue);
  });

  test('an inline colour rides with the run', () {
    final sink = emit(
      const MTextEntity(
        id: 1,
        position: Vec2.zero(),
        content: r'\C3;Hi',
      ),
    );
    expect(sink.texts.single.text, 'Hi');
  });
}
