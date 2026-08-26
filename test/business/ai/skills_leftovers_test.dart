import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled skills parse and read_skill returns the body', () async {
    final skills = bundledSkillRegistry();
    final names = skills.listSummaries().map((item) => item.name).toSet();
    expect(
      names,
      containsAll([
        'inspect-drawing',
        'edit-selection',
        'annotate',
        'plugin-author',
      ]),
    );

    final tool = readSkillTool(skills);
    final ok = await tool.execute({'name': 'annotate'});
    expect(ok['status'], 'ok');
    expect(ok['body'], contains('draw_dimAligned'));

    final missing = await tool.execute({'name': 'no-such-skill'});
    expect(missing['status'], 'failed');
    expect(missing['message'], contains('Unknown skill'));
  });

  test('read_skill is a host tool, not a command in the registry', () async {
    final registry = CommandRegistry();
    expect(registry.find('read_skill'), isNull);
    expect(registry.findByToolName('read_skill'), isNull);

    final conversation = Conversation();
    final session = DocumentSession(id: 't', document: CadDocument());
    final agent = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(
              id: '1',
              name: 'read_skill',
              arguments: {'name': 'inspect-drawing'},
            ),
          ],
        ),
        const LlmCompletion(text: 'I will inspect first.'),
      ]),
      registry: registry,
      execute: (id, args) async =>
          CommandResult.failed('command $id should not run'),
      document: session.document,
      conversation: conversation,
      skills: bundledSkillRegistry(),
    );

    final turn = await agent.run('What is in this drawing?');
    expect(turn.isOk, isTrue);
    expect(turn.reply, contains('inspect'));
    final toolRow = conversation.visible.singleWhere(
      (item) => item.role == ChatRole.tool,
    );
    expect(toolRow.text, contains('query_entities'));
  });
}
