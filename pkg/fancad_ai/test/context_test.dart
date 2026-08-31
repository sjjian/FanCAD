import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a summary reports counts and extents without listing every entity', () {
    final document = CadDocument();
    document.editLike((transaction) {
      transaction.add(
        LineEntity(id: 0, start: const Vec2.zero(), end: const Vec2(10, 0)),
      );
      transaction.add(
        CircleEntity(id: 0, center: const Vec2(5, 5), radius: 2),
      );
    });

    final text = const DocumentContextBuilder().summarize(document);
    expect(text, contains('entities: 2'));
    expect(text, contains('line×1'));
    expect(text, contains('circle×1'));
    expect(text, contains('extents:'));
    // The whole point of the summary: it must not dump geometry.
    expect(text, isNot(contains('"start"')));
  });

  test('the system prompt tells the model to query instead of guessing', () {
    final prompt = const DocumentContextBuilder().systemPrompt(
      document: CadDocument(),
      tools: const [],
    );
    expect(prompt, contains('query.summary'));
    expect(prompt, contains('query.entities'));
    expect(prompt, contains('selection: none'));
    expect(prompt, contains('skill.read'));
  });
}

extension on CadDocument {
  void editLike(void Function(Transaction transaction) body) {
    final session = DocumentSession(id: 't', document: this);
    session.edit('setup', body);
  }
}
