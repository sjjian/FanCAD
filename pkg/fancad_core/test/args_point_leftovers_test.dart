import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing optional point cannot invent a coordinate', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [ParamSpec.point('at')],
    );
    expect(await input.pointOrNull('Specify point:'), isNull);
  });
}
