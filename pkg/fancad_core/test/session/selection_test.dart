import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('SelectionSet', () {
    test('add, toggle and replace keep a single current set', () {
      final selection = SelectionSet();
      expect(selection.isEmpty, isTrue);
      expect(selection.add(1), isTrue);
      expect(selection.add(1), isFalse);
      expect(selection.addAll([1, 2, 3]), 2);
      expect(selection.ids, {1, 2, 3});
      expect(selection.isSingle, isFalse);
      expect(selection.contains(2), isTrue);
      expect(selection.toggle(2), isFalse);
      expect(selection.contains(2), isFalse);
      expect(selection.toggle(2), isTrue);
      selection.replace([4]);
      expect(selection.single, 4);
      expect(selection.length, 1);
      selection.replace([4]);
      expect(selection.ids, {4});
    });

    test('viewport selection clears entity ids and grips', () {
      final selection = SelectionSet()
        ..add(9)
        ..activeGrips[9] = 0;
      selection.selectViewports([0, 2]);
      expect(selection.ids, isEmpty);
      expect(selection.viewportIndices, {0, 2});
      expect(selection.activeGrips, isEmpty);
      selection.selectViewports([0, 2]);
      expect(selection.add(1), isTrue);
      expect(selection.viewportIndices, isEmpty);
      expect(selection.toString(), 'SelectionSet(1)');
    });

    test('remove, prune and clear drop ids that no longer exist', () {
      final selection = SelectionSet()..addAll([1, 2, 3]);
      expect(selection.remove(2), isTrue);
      expect(selection.remove(2), isFalse);
      expect(selection.removeAll([1, 9]), 1);
      selection.prune((id) => id == 3);
      expect(selection.ids, {3});
      selection.selectViewports([0, 5]);
      selection.pruneViewports(2);
      expect(selection.viewportIndices, {0});
      selection.clear();
      expect(selection.isEmpty, isTrue);
      selection.dispose();
    });

    test('changes fire once per mutation', () {
      final selection = SelectionSet();
      final sizes = <int>[];
      final sub = selection.changes.listen((ids) => sizes.add(ids.length));
      selection.add(1);
      selection.addAll([2]);
      selection.clear();
      expect(sizes, [1, 2, 0]);
      sub.cancel();
    });

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

    test('toggling the same id twice cannot invent a leftover pick', () {
      final selection = SelectionSet();
      expect(selection.toggle(7), isTrue);
      expect(selection.toggle(7), isFalse);
      expect(selection.ids, isEmpty);
      expect(selection.single, isNull);
      selection.dispose();
    });

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
  });
}
