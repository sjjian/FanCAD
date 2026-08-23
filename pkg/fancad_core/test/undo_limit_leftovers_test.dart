import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a tiny undo limit cannot invent leftover history', () {
    final stack = UndoStack(limit: 1);
    final document = CadDocument();
    final first = Transaction(document, label: 'a')
      ..add(const LineEntity(id: 0, start: Vec2.zero(), end: Vec2(1, 0)));
    stack.push(first.commit()!);
    final second = Transaction(document, label: 'b')
      ..add(const LineEntity(id: 0, start: Vec2(2, 0), end: Vec2(3, 0)));
    stack.push(second.commit()!);
    expect(stack.depth, 1);
    expect(stack.nextUndoLabel, contains('line'));
  });
}
