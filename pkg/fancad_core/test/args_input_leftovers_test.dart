import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing confirm uses the default rather than inventing yes', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [ParamSpec(name: 'ok', type: ParamType.boolean)],
    );
    expect(await input.confirm('ok?'), isFalse);
    expect(input.isCancelled, isFalse);
  });

  test('an empty selection or blank keyword cannot invent a pick', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [ParamSpec.selection('ids')],
    );
    expect(
      () => input.selection('Select objects:'),
      throwsA(isA<CommandCancelled>()),
    );
    expect(ArgsCommandInput.matchKeyword('  ', ['center', 'end']), isNull);
  });
}
