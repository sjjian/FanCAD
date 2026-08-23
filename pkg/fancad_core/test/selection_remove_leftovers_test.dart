import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('removing a missing id cannot invent a selection change', () {
    final selection = SelectionSet()..add(1);
    final sizes = <int>[];
    final sub = selection.changes.listen((ids) => sizes.add(ids.length));

    expect(selection.remove(99), isFalse);
    expect(selection.removeAll([99, 100]), 0);
    expect(selection.ids, {1});
    expect(sizes, isEmpty);

    sub.cancel();
    selection.dispose();
  });
}
