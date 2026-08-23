import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an empty registry cannot invent a verb from a blank search', () {
    final registry = CommandRegistry();
    expect(registry.search(''), isEmpty);
    expect(registry.search('   '), isEmpty);
    expect(registry.find(''), isNull);
    expect(registry.findByToolName(''), isNull);
  });
}
