import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty stack cannot invent undo or redo labels', () {
    final stack = UndoStack();
    expect(stack.nextUndoLabel, isNull);
    expect(stack.nextRedoLabel, isNull);
    expect(stack.undo(CadDocument()), isNull);
    expect(stack.redo(CadDocument()), isNull);
    expect(stack.depth, 0);
  });
}
