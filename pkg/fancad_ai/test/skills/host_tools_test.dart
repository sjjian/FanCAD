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

  test('ask refuses fewer than two options', () {
    expect(
      parseSessionQuestion({
        'question': 'Radius?',
        'options': ['5'],
      }),
      isNull,
    );

    final ok = parseSessionQuestion({
      'question': 'Radius?',
      'options': ['5', '10'],
    });
    expect(ok, isNotNull);
    expect(ok!.options, hasLength(2));
    expect(ok.multiple, isFalse);
    expect(ok.allowCustom, isTrue);

    final multi = parseSessionQuestion({
      'question': 'Which?',
      'options': ['A', 'B', 'C'],
      'multiple': true,
    });
    expect(multi?.multiple, isTrue);
  });

  test('encodeAskAnswer packs one or many picks', () {
    expect(
      encodeAskAnswer(
        selected: const [SessionAskOption(id: 'a', label: 'A')],
      ),
      {'status': 'ok', 'id': 'a', 'label': 'A'},
    );
    expect(
      encodeAskAnswer(
        selected: const [
          SessionAskOption(id: 'a', label: 'A'),
          SessionAskOption(id: 'b', label: 'B'),
        ],
        custom: 'also this',
      ),
      {
        'status': 'ok',
        'multiple': true,
        'id': 'a',
        'label': 'A',
        'ids': ['a', 'b', 'custom'],
        'labels': ['A', 'B', 'also this'],
      },
    );
    expect(encodeAskAnswer(selected: const []), isNull);
  });
}
