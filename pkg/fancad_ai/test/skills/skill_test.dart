import 'package:fancad_ai/fancad_ai.dart';
import 'package:test/test.dart';

void main() {
  test('a leftover skill file without a name is dropped', () {
    expect(parseSkillMarkdown('just markdown'), isNull);
    expect(parseSkillMarkdown('---\ndescription: x\n---\nbody'), isNull);
    expect(
      parseSkillMarkdown('---\nname: ok\ndescription: d\n---\nHello')?.name,
      'ok',
    );
  });
}
