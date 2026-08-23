import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('quoted whitespace cannot invent a verb', () {
    final registry = CommandRegistry();
    expect(registry.parseCommandLine('""'), isNull);
    expect(registry.parseCommandLine('""   ""'), isNull);
    registry.dispose();
  });
}
