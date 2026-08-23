import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a short undo run cannot invent a coalesced turn', () {
    final stack = UndoStack();
    stack.coalesceLast(2);
    expect(stack.depth, 0);
    stack.coalesceLast(1);
    expect(stack.depth, 0);
  });
}
