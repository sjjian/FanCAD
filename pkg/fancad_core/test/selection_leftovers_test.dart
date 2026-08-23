import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a no-op mutation cannot invent a selection change', () {
    final selection = SelectionSet()..addAll([1, 2]);
    final sizes = <int>[];
    final sub = selection.changes.listen((ids) => sizes.add(ids.length));

    expect(selection.addAll([1, 2]), 0);
    selection.replace([1, 2]);
    selection.prune((id) => true);
    selection.pruneViewports(8);
    selection.clear();
    selection.clear();
    expect(sizes, [0]);

    sub.cancel();
    selection.dispose();
  });

  test(
    'adding an existing id while viewports are selected still clears them',
    () {
      final selection = SelectionSet()
        ..add(1)
        ..selectViewports([0]);
      expect(selection.add(1), isTrue);
      expect(selection.ids, {1});
      expect(selection.viewportIndices, isEmpty);
      selection.dispose();
    },
  );

  test('stale grips cannot survive a replace that drops their entity', () {
    final selection = SelectionSet()
      ..add(9)
      ..activeGrips[9] = 2;
    selection.replace([4]);
    expect(selection.activeGrips.containsKey(9), isFalse);
    expect(selection.ids, {4});
    selection.dispose();
  });
}
