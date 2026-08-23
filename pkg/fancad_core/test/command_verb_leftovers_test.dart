import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('an unknown verb cannot invent a command', () {
    final registry = CommandRegistry();
    final parsed = registry.parseCommandLine('nope 1,2');
    expect(parsed, isNotNull);
    expect(parsed!.descriptor, isNull);
    expect(parsed.verb, 'nope');
    expect(parsed.args, isEmpty);
    registry.dispose();
  });
}
