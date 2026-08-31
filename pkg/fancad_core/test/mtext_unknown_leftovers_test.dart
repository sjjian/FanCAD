import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown directive cannot invent leftover formatting', () {
    final runs = const MTextLayout().layout(
      const MTextEntity(id: 1, position: Vec2.zero(), content: r'\X99;Hi'),
    );
    expect(runs.single.text, 'Hi');
    expect(runs.single.color, isNull);
    expect(runs.single.font, isEmpty);
    expect(runs.single.bold, isFalse);
    expect(runs.single.height, 2.5);

    expect(stripMTextFormatting(r'\X99;Hi'), 'Hi');
  });
}
