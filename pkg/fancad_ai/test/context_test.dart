import 'package:fancad_ai/fancad_ai.dart';
import 'package:test/test.dart';

void main() {
  test('the system prompt tells the model to query instead of guessing', () {
    final prompt = const DocumentContextBuilder().systemPrompt();
    expect(prompt, contains('query.summary'));
    expect(prompt, contains('query.session'));
    expect(prompt, contains('query.selection'));
    expect(prompt, isNot(contains('Active drawing:')));
    expect(prompt, isNot(contains('Session:')));
    expect(prompt, isNot(contains('Available tools:')));
    expect(prompt, isNot(contains('session.ask')));
    expect(prompt, isNot(contains('{{')));
    expect(prompt, contains('@objects[tab=<id> ids=1,2,3]'));
    expect(prompt, contains('@drawing[tab=<id>]'));
    expect(prompt, isNot(contains('fancad API')));
  });

  test('a leftover skill index lists names without dumping the body', () {
    final prompt = const DocumentContextBuilder().systemPrompt(
      skills: const [
        SkillSummary(
          name: 'inspect-drawing',
          description: 'Inspect the open drawing.',
        ),
      ],
    );
    expect(prompt, contains('inspect-drawing: Inspect the open drawing.'));
    expect(prompt, contains('Available skills:'));
    expect(prompt, isNot(contains('Never dump the whole drawing')));
  });
}
