import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing number uses the default rather than inventing a value', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [
        ParamSpec(name: 'n', type: ParamType.number, defaultValue: 4),
      ],
    );
    expect(await input.number('n', defaultValue: 4), 4);
  });
}
