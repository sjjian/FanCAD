import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
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
          execute: (id, args, {tab}) async => const CommandResult.ok(),
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
