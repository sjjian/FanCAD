import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('a cancelled input cannot invent a point pick', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [ParamSpec.point('at')],
    )..cancel();
    expect(input.isCancelled, isTrue);
    expect(input.isInteractive, isFalse);
    expect(
      () => input.point('Specify point:'),
      throwsA(isA<CommandCancelled>()),
    );
  });
}
