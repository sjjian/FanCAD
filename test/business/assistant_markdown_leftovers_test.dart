import 'package:fancad/fancad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('assistant leftovers render markdown, users stay plain', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        home: const Scaffold(
          body: AssistantMarkdown(
            text: 'Use **query.selection**, then `draw.line`.',
          ),
        ),
      ),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.selectable, isTrue);
    expect(find.textContaining('query.selection'), findsWidgets);
    expect(find.textContaining('draw.line'), findsWidgets);
  });
}
