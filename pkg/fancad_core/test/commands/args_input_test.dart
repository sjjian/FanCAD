import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:test/test.dart';

void main() {
  eachCase(
    [
      (
        name: 'a missing keyword cannot invent an option',
        params: const [ParamSpec(name: 'mode', type: ParamType.choice)],
        invoke: (ArgsCommandInput input) =>
            input.keyword('mode', ['center', 'end']),
      ),
      (
        name: 'a missing number cannot invent a value',
        params: const [ParamSpec(name: 'n', type: ParamType.number)],
        invoke: (ArgsCommandInput input) => input.number('n'),
      ),
      (
        name: 'a missing integer cannot invent a value',
        params: const [ParamSpec(name: 'i', type: ParamType.integer)],
        invoke: (ArgsCommandInput input) => input.integer('i'),
      ),
      (
        name: 'a missing text cannot invent a value',
        params: const [ParamSpec(name: 'name', type: ParamType.text)],
        invoke: (ArgsCommandInput input) => input.text('name'),
      ),
      (
        name: 'a missing distance cannot invent a measure',
        params: const [ParamSpec(name: 'len', type: ParamType.distance)],
        invoke: (ArgsCommandInput input) => input.distance('len'),
      ),
      (
        name: 'a missing angle cannot invent a measure',
        params: const [ParamSpec(name: 'rot', type: ParamType.angle)],
        invoke: (ArgsCommandInput input) => input.angle('rot'),
      ),
      (
        name: 'an empty selection cannot invent a pick',
        params: const [ParamSpec.selection('ids')],
        invoke: (ArgsCommandInput input) => input.selection('Select objects:'),
      ),
    ],
    (c) {
      final input = ArgsCommandInput(
        args: CommandArgs.empty(),
        params: c.params,
      );
      expect(() => c.invoke(input), throwsA(isA<CommandCancelled>()));
    },
  );

  test('a blank keyword cannot invent an option', () {
    expect(ArgsCommandInput.matchKeyword('  ', ['center', 'end']), isNull);
  });

  test('an ambiguous prefix cannot invent a keyword', () {
    expect(ArgsCommandInput.matchKeyword('c', ['center', 'close']), isNull);
    expect(ArgsCommandInput.matchKeyword('ce', ['center', 'close']), 'center');
    expect(ArgsCommandInput.matchKeyword('nope', ['center', 'end']), isNull);
  });

  test('a missing optional point cannot invent a coordinate', () async {
    final input = ArgsCommandInput(
      args: CommandArgs.empty(),
      params: const [ParamSpec.point('at')],
    );
    expect(await input.pointOrNull('Specify point:'), isNull);
  });

  test(
    'a missing confirm uses the default rather than inventing yes',
    () async {
      final input = ArgsCommandInput(
        args: CommandArgs.empty(),
        params: const [ParamSpec(name: 'ok', type: ParamType.boolean)],
      );
      expect(await input.confirm('ok?'), isFalse);
      expect(input.isCancelled, isFalse);
    },
  );

  test(
    'a missing number uses the default rather than inventing a value',
    () async {
      final input = ArgsCommandInput(
        args: CommandArgs.empty(),
        params: const [
          ParamSpec(name: 'n', type: ParamType.number, defaultValue: 4),
        ],
      );
      expect(await input.number('n', defaultValue: 4), 4);
    },
  );

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
