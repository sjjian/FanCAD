import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
  late CommandRegistry registry;
  late OperationCatalog catalog;
  late OpsDispatcher dispatcher;
  final ran = <String>[];

  setUp(() {
    ran.clear();
    registry = CommandRegistry()
      ..register(
        CommandDescriptor(
          id: 'draw.line',
          title: 'Line',
          category: 'Draw',
          description: 'Draws a segment.',
          aliases: const ['L'],
          params: const [
            ParamSpec(name: 'start', type: ParamType.point),
            ParamSpec(name: 'end', type: ParamType.point),
          ],
          handler: (_) async => const CommandResult.ok(message: 'drew'),
        ),
      )
      ..register(
        CommandDescriptor(
          id: 'query.summary',
          title: 'Summary',
          category: 'Query',
          risk: CommandRisk.readOnly,
          handler: (_) async => const CommandResult.ok(data: {'n': 0}),
        ),
      )
      ..register(
        CommandDescriptor(
          id: 'file.open',
          title: 'Open',
          category: 'File',
          aiExposure: AiExposure.hidden,
          params: const [ParamSpec(name: 'path', type: ParamType.text)],
          handler: (_) async => const CommandResult.ok(),
        ),
      );
    catalog = OperationCatalog()
      ..addProvider(
        CommandOperationProvider(
          registry: registry,
          execute: (id, args) async {
            ran.add(id);
            return CommandResult.ok(message: id, data: args);
          },
        ),
      )
      ..register(
        Operation(
          id: 'skill.read',
          group: 'skill',
          groupTitle: 'Skill',
          title: 'Read skill',
          description: 'Load a skill body.',
          params: const [ParamSpec(name: 'name', type: ParamType.text)],
          risk: CommandRisk.readOnly,
          execute: (args) async => {'status': 'ok', 'name': args['name']},
        ),
      );
    dispatcher = OpsDispatcher(catalog);
  });

  test('list without a path returns groups, not every command schema', () async {
    final payload = await dispatcher.dispatch(const OpsRequest(action: OpsAction.list));
    expect(payload['status'], 'ok');
    final groups = payload['groups'] as List<Object?>;
    expect(
      groups.map((item) => (item as Map)['id']),
      containsAll(['draw', 'file', 'query', 'skill']),
    );
    expect(payload.toString(), isNot(contains('start')));
  });

  test('help on a group lists summaries; help on an id is full', () async {
    final group = await dispatcher.dispatch(
      const OpsRequest(action: OpsAction.help, path: 'draw'),
    );
    final ops = group['operations'] as List<Object?>;
    expect(ops, hasLength(1));
    expect((ops.single as Map)['id'], 'draw.line');
    expect(group.toString(), isNot(contains('"required"')));

    final help = await dispatcher.dispatch(
      const OpsRequest(action: OpsAction.help, path: 'draw.line'),
    );
    expect(help['id'], 'draw.line');
    expect(help['aliases'], ['L']);
    expect(help['params'], isNotEmpty);
  });

  test('schema returns the command parameter object', () async {
    final payload = await dispatcher.dispatch(
      const OpsRequest(action: OpsAction.schema, path: 'draw.line'),
    );
    final schema = payload['schema'] as Map<String, Object?>;
    expect(schema['required'], ['start', 'end']);
  });

  test('run forwards args to the injected executor', () async {
    final payload = await dispatcher.dispatch(
      const OpsRequest(
        action: OpsAction.run,
        path: 'draw.line',
        args: {
          'start': [0, 0],
          'end': [1, 0],
        },
      ),
    );
    expect(ran, ['draw.line']);
    expect(payload['status'], 'ok');
    expect(payload['message'], 'draw.line');
  });

  test('hidden file commands and host tools appear and resolve aliases', () async {
    expect(catalog.find('file.open'), isNotNull);
    expect(catalog.find('L')?.id, 'draw.line');
    expect(catalog.find('draw_line'), isNull);

    final skill = await dispatcher.dispatch(
      const OpsRequest(
        action: OpsAction.run,
        path: 'skill.read',
        args: {'name': 'annotate'},
      ),
    );
    expect(skill['name'], 'annotate');
  });

  test('unknown path lists known groups', () async {
    final payload = await dispatcher.dispatch(
      const OpsRequest(action: OpsAction.run, path: 'nope'),
    );
    expect(payload['status'], 'failed');
    expect(payload['error'], contains('Known groups'));
  });

  test('a leftover cancel becomes a failed run the caller can correct', () async {
    catalog.register(
      operationFromCommand(
        CommandDescriptor(
          id: 'draw.polyline',
          title: 'Polyline',
          description: 'Draws a connected sequence of segments.',
          params: const [
            ParamSpec(name: 'points', type: ParamType.points, required: false),
          ],
          handler: (_) async => const CommandResult.ok(),
        ),
        (id, args) async => const CommandResult.cancelled(),
      ),
    );
    final payload = await dispatcher.dispatch(
      const OpsRequest(action: OpsAction.run, path: 'draw.polyline'),
    );
    expect(payload['status'], 'failed');
    expect(payload['error'], contains('fancad({action: run, path: draw.polyline'));
    expect(payload['error'], isNot(contains('Cancelled')));
  });
}
