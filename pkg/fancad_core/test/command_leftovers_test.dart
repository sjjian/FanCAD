import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  CommandDescriptor cmd(String id) => CommandDescriptor(
    id: id,
    title: id,
    handler: (_) async => const CommandResult.ok(),
  );

  test('a missing command cannot invent a lookup or an extension unload', () {
    final registry = CommandRegistry()..register(cmd('draw.line'));

    expect(registry.find('nope'), isNull);
    expect(registry.findByToolName('no_such_tool'), isNull);
    expect(registry.contains('nope'), isFalse);
    expect(registry.search('zzzz-no-such-verb'), isEmpty);
    expect(registry.unregisterExtension('ghost'), 0);
    expect(registry.find('draw.line'), isNotNull);

    registry.dispose();
  });
}
