import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing keyword cannot invent an option', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [ParamSpec(name: 'mode', type: ParamType.choice)],
    );
    expect(
      () => input.keyword('mode', ['center', 'end']),
      throwsA(isA<CommandCancelled>()),
    );
  });
}
