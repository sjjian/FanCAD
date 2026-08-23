import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty transaction summary stays the label', () {
    final committed = CommittedTransaction(
      label: 'Edit',
      source: ChangeSource.user,
      forward: const [],
      inverse: const [],
      change: const DocumentChange(),
      timestamp: DateTime.utc(2026, 1, 1),
    );
    expect(committed.summarize(), 'Edit');
    expect(committed.patchCount, 0);
  });

  test('repeated patches collapse and mixed patches keep the label', () {
    const line = LineEntity(id: 1, start: Vec2.zero(), end: Vec2(10, 0));
    final add = AddEntityPatch(entity: line, blockName: '*Model_Space');
    final one = CommittedTransaction(
      label: 'Draw',
      source: ChangeSource.command,
      forward: [add],
      inverse: const [],
      change: const DocumentChange(added: [1]),
      timestamp: DateTime.utc(2026, 1, 1),
    );
    expect(one.summarize(), add.describe());

    final two = CommittedTransaction(
      label: 'Draw',
      source: ChangeSource.command,
      forward: [add, add],
      inverse: const [],
      change: const DocumentChange(added: [1, 2]),
      timestamp: DateTime.utc(2026, 1, 1),
    );
    expect(two.summarize(), '${add.describe()} x2');

    final mixed = CommittedTransaction(
      label: 'Edit',
      source: ChangeSource.user,
      forward: [
        add,
        RemoveEntityPatch(entity: line, blockName: '*Model_Space'),
      ],
      inverse: const [],
      change: const DocumentChange(),
      timestamp: DateTime.utc(2026, 1, 1),
    );
    expect(mixed.summarize(), 'Edit (2 changes)');
  });
}
