import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
  test('highlight ids accept strings, maps and nested lists, not junk', () {
    expect(
      highlightIdsOf({
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
    expect(
      leftover['error'],
      contains('fancad({action: run, path: draw.polyline, args: {points?}})'),
    );
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

  test('host tools stay out of the command registry', () {
    final registry = CommandRegistry()
      ..register(
        CommandDescriptor(
          id: 'query.selection',
          title: 'Query Selection',
          risk: CommandRisk.readOnly,
          handler: (_) async => const CommandResult.ok(),
        ),
      );
    expect(registry.find('read_skill'), isNull);
    expect(registry.find('skill.read'), isNull);

    final catalog = OperationCatalog()
      ..addProvider(
        CommandOperationProvider(
          registry: registry,
          execute: (id, args) async => const CommandResult.ok(),
        ),
      )
      ..addProvider(
        HostOperationProvider([
          readSkillTool(
            InMemorySkillRegistry({
              'demo': const Skill(name: 'demo', description: 'd', body: 'b'),
            }),
          ),
        ]),
      );
    expect(catalog.find('skill.read'), isNotNull);
    expect(catalog.find('query.selection'), isNotNull);
  });
}
