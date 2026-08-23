import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('highlight ids accept strings, maps and nested lists, not junk', () {
    expect(
      CommandToolCatalog.highlightIdsOf({
        'id': '12',
        'selection': [
          {'id': 3.0},
          'nope',
          [4],
        ],
        'other': true,
      }),
      [12, 3, 4],
    );
  });

  test(
    'a destructive alias is advertised, and approval-required can be hidden',
    () {
      final registry = CommandRegistry()
        ..register(
          CommandDescriptor(
            id: 'edit.erase',
            title: 'Erase',
            description: 'Deletes objects.',
            aliases: const ['E'],
            risk: CommandRisk.destructive,
            handler: (_) async => const CommandResult.ok(),
          ),
        )
        ..register(
          CommandDescriptor(
            id: 'file.save',
            title: 'Save',
            aiExposure: AiExposure.approvalRequired,
            handler: (_) async => const CommandResult.ok(),
          ),
        );

      final all = const CommandToolCatalog().toolsOf(registry);
      expect(
        all.map((tool) => tool.name),
        containsAll(['edit_erase', 'file_save']),
      );
      final erase = all.firstWhere((tool) => tool.name == 'edit_erase');
      expect(erase.description, contains('Deletes objects.'));
      expect(erase.description, contains('Aliases: E.'));
      expect(erase.description, contains('Destructive: requires approval.'));

      final quiet = const CommandToolCatalog().toolsOf(
        registry,
        includeApprovalRequired: false,
      );
      expect(quiet.map((tool) => tool.name), ['edit_erase']);
    },
  );
}
