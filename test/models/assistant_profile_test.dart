import 'package:fancad/fancad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover token count is compact, not a raw integer dump', () {
    expect(formatAssistantTokens(500), '500');
    expect(formatAssistantTokens(12400), '12.4k');
    expect(formatAssistantTokens(128000), '128k');
    expect(formatAssistantTokens(12400), isNot(contains('12400')));
  });
}
