import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an identical viewport set cannot invent a selection change', () {
    final selection = SelectionSet()..selectViewports([0, 1]);
    final sizes = <int>[];
    final sub = selection.changes.listen((ids) => sizes.add(ids.length));

    selection.selectViewports([0, 1]);
    expect(selection.viewportIndices, {0, 1});
    expect(sizes, isEmpty);

    sub.cancel();
    selection.dispose();
  });
}
