import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
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

    expect(stripMTextFormatting(r'A\{'), 'A{');
    expect(stripMTextFormatting(r'A\P\P'), 'A\n\n');
  });
}
