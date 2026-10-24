import 'package:fancad/screen/plugin/js_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plain = TextStyle(color: Color(0xFF111111));
  const keyword = TextStyle(color: Color(0xFF2255CC));
  const string = TextStyle(color: Color(0xFF228855));
  const comment = TextStyle(color: Color(0xFF888888));
  const number = TextStyle(color: Color(0xFFCC8800));

  List<TextSpan> paint(String source) => highlightJavaScript(
    source,
    plain: plain,
    keyword: keyword,
    string: string,
    comment: comment,
    number: number,
  );

  String painted(List<TextSpan> spans) =>
      spans.map((span) => span.text ?? '').join();

  String ofStyle(List<TextSpan> spans, TextStyle style) => spans
      .where((span) => span.style == style)
      .map((span) => span.text ?? '')
      .join();

  test('keywords, strings, comments and numbers keep the source intact', () {
    const source = "const n = 1; // note\nconst s = 'hi';";
    final spans = paint(source);

    expect(painted(spans), source);
    expect(ofStyle(spans, keyword), 'constconst');
    expect(ofStyle(spans, number), '1');
    expect(ofStyle(spans, comment), '// note');
    expect(ofStyle(spans, string), "'hi'");
  });

  test('a block comment and a template string stay one span each', () {
    const source = '/* description: 距离 */\nconst q = `a\nb`;';
    final spans = paint(source);

    expect(painted(spans), source);
    expect(ofStyle(spans, comment), '/* description: 距离 */');
    expect(ofStyle(spans, string), '`a\nb`');
  });
}
