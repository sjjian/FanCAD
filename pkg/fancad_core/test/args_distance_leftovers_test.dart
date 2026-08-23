import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a missing distance or angle cannot invent a measure', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [
        ParamSpec(name: 'len', type: ParamType.distance),
        ParamSpec(name: 'rot', type: ParamType.angle),
      ],
    );
    expect(() => input.distance('len'), throwsA(isA<CommandCancelled>()));
    expect(() => input.angle('rot'), throwsA(isA<CommandCancelled>()));
  });
}
