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

  test('host tools merge after registry tools without becoming commands', () {
    final registry = CommandRegistry()
      ..register(
        CommandDescriptor(
          id: 'query.selection',
          title: 'Query Selection',
          risk: CommandRisk.readOnly,
          handler: (_) async => const CommandResult.ok(),
        ),
      );
    final tools = const CommandToolCatalog().toolsOf(
      registry,
      extra: [
        readSkillTool(
          InMemorySkillRegistry({
            'demo': const Skill(name: 'demo', description: 'd', body: 'b'),
          }),
        ).definition,
      ],
    );
    expect(tools.map((tool) => tool.name), ['query_selection', 'read_skill']);
    expect(registry.find('read_skill'), isNull);
  });

  test('a leftover cancel becomes a failed tool error the model can read', () {
    final command = CommandDescriptor(
      id: 'draw.polyline',
      title: 'Polyline',
      description: 'Draws a connected sequence of segments.',
      params: const [
        ParamSpec(name: 'points', type: ParamType.points, required: false),
      ],
      handler: (_) async => const CommandResult.ok(),
    );

    final leftover = encodeAssistantToolResult(
      const CommandResult.cancelled(),
      command,
    );
    expect(leftover['status'], 'failed');
    expect(leftover['error'], contains('draw_polyline({points?})'));
    expect(leftover['error'], contains('arguments were missing'));
    expect(leftover['error'], isNot(contains('Cancelled')));
    expect(leftover['message'], leftover['error']);

    final explicit = encodeAssistantToolResult(
      const CommandResult.failed(
        'Polyline needs points as [[x, y], [x, y], ...].',
      ),
      command,
    );
    expect(explicit['status'], 'failed');
    expect(explicit['error'], contains('[[x, y]'));
    expect(explicit['error'], isNot(contains('Cancelled')));
  });
}
