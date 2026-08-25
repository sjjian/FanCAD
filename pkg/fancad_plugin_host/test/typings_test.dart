import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

CommandDescriptor command({
  required String id,
  String description = '',
  List<ParamSpec> params = const [],
}) => CommandDescriptor(
  id: id,
  title: id,
  description: description,
  params: params,
  handler: (context) async => const CommandResult.ok(),
);

void main() {
  test('every leftover parameter type has a TypeScript spelling', () {
    final output = buildTypeDeclarations(
      commands: [
        command(
          id: 'query.probe',
          params: const [
            ParamSpec(name: 'layer', type: ParamType.layer),
            ParamSpec(name: 'block', type: ParamType.block),
            ParamSpec(name: 'text', type: ParamType.text),
            ParamSpec(name: 'len', type: ParamType.distance),
            ParamSpec(name: 'ang', type: ParamType.angle),
            ParamSpec(name: 'count', type: ParamType.integer),
            ParamSpec(name: 'entity', type: ParamType.entity),
            ParamSpec(name: 'flag', type: ParamType.boolean),
            ParamSpec(name: 'ids', type: ParamType.selection),
            ParamSpec(name: 'extra', type: ParamType.json),
            ParamSpec(name: 'points', type: ParamType.points),
          ],
        ),
      ],
    );

    expect(output, contains('interface QueryProbe {'));
    expect(output, contains('layer: string;'));
    expect(output, contains('block: string;'));
    expect(output, contains('text: string;'));
    expect(output, contains('len: number;'));
    expect(output, contains('ang: number;'));
    expect(output, contains('count: number;'));
    expect(output, contains('entity: number;'));
    expect(output, contains('flag: boolean;'));
    expect(output, contains('ids: number[];'));
    expect(output, contains('extra: Record<string, unknown>;'));
    expect(output, contains('points: Point[];'));
  });

  test('an unsafe parameter name is quoted so the d.ts still parses', () {
    final output = buildTypeDeclarations(
      commands: [
        command(
          id: 'draw-line',
          description:
              'A long description that must wrap onto another comment line '
              'instead of overflowing the generated file.',
          params: const [ParamSpec(name: '2d-point', type: ParamType.point)],
        ),
      ],
    );

    expect(output, contains('interface DrawLine {'));
    expect(output, contains("'2d-point': Point;"));
    expect(output, contains(' * A long description that must wrap'));
    expect(output, contains(' * overflowing the generated file.'));
  });
}
