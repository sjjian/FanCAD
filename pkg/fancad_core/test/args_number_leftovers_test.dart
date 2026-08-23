import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing number cannot invent a value', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [
        ParamSpec(name: 'n', type: ParamType.number),
        ParamSpec(name: 'i', type: ParamType.integer),
        ParamSpec(name: 'name', type: ParamType.text),
      ],
    );
    expect(() => input.number('n'), throwsA(isA<CommandCancelled>()));
    expect(() => input.integer('i'), throwsA(isA<CommandCancelled>()));
    expect(() => input.text('name'), throwsA(isA<CommandCancelled>()));
  });
}
