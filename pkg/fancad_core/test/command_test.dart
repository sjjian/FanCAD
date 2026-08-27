import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Disposable', () {
    test('a callback runs once and a bag tears children down in reverse', () {
      final order = <String>[];
      final bag = DisposableBag(debugLabel: 't');
      bag.addCallback(() => order.add('first'));
      bag.add(Disposable.callback(() => order.add('second')));
      expect(bag.length, 2);
      bag.dispose();
      expect(order, ['second', 'first']);
      expect(bag.isDisposed, isTrue);
      bag.dispose();
      expect(order, ['second', 'first']);
    });

    test('adding to a disposed bag disposes the child immediately', () {
      var ran = false;
      final bag = DisposableBag()..dispose();
      bag.add(Disposable.callback(() => ran = true));
      expect(ran, isTrue);
      Disposable.noop.dispose();
    });
  });

  group('CommandArgs', () {
    test('decodes the wire shapes commands actually receive', () {
      final args = CommandArgs({
        'label': 'WORK',
        'count': '3',
        'scale': 2.5,
        'flag': 'yes',
        'off': '0',
        'at': '1,2',
        'ids': '4, 5 6',
        'one': 9,
        'list': [1, '2'],
        'payload': <String, Object?>{'k': 1},
      });
      expect(args.text('label'), 'WORK');
      expect(args.integer('count'), 3);
      expect(args.number('scale'), 2.5);
      expect(args.boolean('flag'), isTrue);
      expect(args.boolean('off'), isFalse);
      expect(args.point('at'), const Vec2(1, 2));
      expect(args.ids('ids'), [4, 5, 6]);
      expect(args.ids('one'), [9]);
      expect(args.ids('list'), [1, 2]);
      expect(args.object('payload'), {'k': 1});
      expect(args.has('label'), isTrue);
      expect(CommandArgs.empty().isEmpty, isTrue);
    });

    test('parsePoint accepts lists, maps and Vec2', () {
      expect(CommandArgs.parsePoint(const Vec2(1, 2)), const Vec2(1, 2));
      expect(CommandArgs.parsePoint([3, 4]), const Vec2(3, 4));
      expect(CommandArgs.parsePoint(['5', '6']), const Vec2(5, 6));
      expect(CommandArgs.parsePoint({'x': 7, 'y': 8}), const Vec2(7, 8));
      expect(CommandArgs.parsePoint('nope'), isNull);
    });
  });

  group('ParamSpec', () {
    test('JSON schema matches the parameter kind', () {
      expect(const ParamSpec.point('at').toJsonSchema()['type'], 'array');
      expect(
        const ParamSpec.selection('ids').toJsonSchema()['type'],
        'array',
      );
      expect(
        const ParamSpec(
          name: 'kind',
          type: ParamType.choice,
          options: ['A', 'B'],
        ).toJsonSchema()['enum'],
        ['A', 'B'],
      );
      expect(
        const ParamSpec(
          name: 'n',
          type: ParamType.number,
          min: 0,
          max: 10,
        ).toJsonSchema()['minimum'],
        0,
      );
      expect(
        const ParamSpec(name: 'layer', type: ParamType.layer).effectivePrompt,
        'Specify layer:',
      );
    });
  });

  group('CommandResult', () {
    test('status helpers and JSON stay in sync', () {
      expect(const CommandResult.ok(message: 'done').isOk, isTrue);
      expect(const CommandResult.cancelled().isCancelled, isTrue);
      expect(const CommandResult.failed('nope').isFailed, isTrue);
      expect(const CommandResult.ok(data: {'n': 1}).toJson()['data'], {'n': 1});
      expect(const CommandCancelled('stop').toString(), contains('stop'));
    });
  });

  group('CommandRegistry', () {
    CommandDescriptor cmd({
      required String id,
      String title = '',
      List<String> aliases = const [],
      List<ParamSpec> params = const [],
      String category = 'Draw',
      String extensionId = '',
      AiExposure ai = AiExposure.tool,
      CommandHandler? handler,
    }) => CommandDescriptor(
      id: id,
      title: title.isEmpty ? id : title,
      aliases: aliases,
      params: params,
      category: category,
      extensionId: extensionId,
      aiExposure: ai,
      handler: handler ?? (_) async => const CommandResult.ok(),
    );

    test('finds by id, alias, title and tool name', () {
      final registry = CommandRegistry()
        ..register(
          cmd(id: 'draw.line', title: 'Line', aliases: ['l', 'LINE']),
        );
      expect(registry.find('draw.line')?.id, 'draw.line');
      expect(registry.find('L')?.id, 'draw.line');
      expect(registry.find('DRAW.LINE')?.id, 'draw.line');
      expect(registry.find('line')?.id, 'draw.line');
      expect(registry.findByToolName('draw_line')?.id, 'draw.line');
      expect(registry.contains('draw.line'), isTrue);
      expect(registry.length, 1);
    });

    test('refuses a duplicate id and unregisters an extension', () {
      final registry = CommandRegistry();
      registry.register(cmd(id: 'draw.line', extensionId: 'plug'));
      expect(
        () => registry.register(cmd(id: 'draw.line', extensionId: 'other')),
        throwsA(isA<DuplicateCommandException>()),
      );
      expect(registry.unregisterExtension('plug'), 1);
      expect(registry.find('draw.line'), isNull);
    });

    test('search ranks an exact title above a subsequence', () {
      final registry = CommandRegistry()
        ..registerAll([
          cmd(id: 'draw.line', title: 'Line'),
          cmd(id: 'draw.pline', title: 'Polyline'),
          cmd(id: 'edit.lengthen', title: 'Lengthen', category: 'Modify'),
        ]);
      expect(registry.search('line').first.id, 'draw.line');
      expect(registry.search('mod').single.id, 'edit.lengthen');
      expect(registry.search('').length, 3);
      expect(registry.byCategory()['Draw']!.map((c) => c.id), [
        'draw.line',
        'draw.pline',
      ]);
      expect(registry.aiTools(), hasLength(3));
    });

    test('parseCommandLine binds positional tokens to declared params', () {
      final registry = CommandRegistry()
        ..register(
          cmd(
            id: 'draw.line',
            aliases: ['line'],
            params: [
              const ParamSpec.point('start'),
              const ParamSpec.point('end'),
            ],
          ),
        );
      final parsed = registry.parseCommandLine('line 0,0 10,10 leftover')!;
      expect(parsed.isResolved, isTrue);
      expect(parsed.args['start'], '0,0');
      expect(parsed.args['end'], '10,10');
      expect(parsed.extra, ['leftover']);
      expect(parsed.toCommandArgs().point('start'), const Vec2.zero());
      expect(registry.parseCommandLine('nope')!.isResolved, isFalse);
      expect(registry.parseCommandLine(''), isNull);
      expect(
        registry.parseCommandLine('line start=1,1 end=2,2')!.args['start'],
        '1,1',
      );
    });

    test('run records history and swallows a throwing handler', () async {
      final session = DocumentSession(id: 't', document: CadDocument());
      final registry = CommandRegistry()
        ..register(
          cmd(
            id: 'draw.ok',
            handler: (context) async =>
                CommandResult.ok(message: context.commandId),
          ),
        )
        ..register(
          cmd(
            id: 'draw.boom',
            handler: (_) => throw StateError('broken'),
          ),
        )
        ..register(
          cmd(
            id: 'draw.stop',
            handler: (_) => throw const CommandCancelled('stop'),
          ),
        );

      CommandContext contextOf(CommandDescriptor descriptor) => CommandContext(
        session: session,
        args: CommandArgs.empty(),
        input: ArgsCommandInput(args: CommandArgs.empty(), params: const []),
        commandId: descriptor.id,
      );

      final ok = await registry.run('draw.ok', contextBuilder: contextOf);
      expect(ok.isOk, isTrue);
      expect(registry.lastCommandId, 'draw.ok');

      final boom = await registry.run('draw.boom', contextBuilder: contextOf);
      expect(boom.isFailed, isTrue);
      expect(boom.message, contains('broken'));

      final stop = await registry.run('draw.stop', contextBuilder: contextOf);
      expect(stop.isCancelled, isTrue);

      expect(
        await registry.run('missing', contextBuilder: contextOf),
        isA<CommandResult>().having((r) => r.isFailed, 'failed', isTrue),
      );
      expect(registry.history, hasLength(3));
      expect(registry.history.first.toJson()['command'], 'draw.ok');
      registry.dispose();
    });
  });

  group('ArgsCommandInput', () {
    test('answers prompts from the argument map in declaration order', () async {
      final input = ArgsCommandInput(
        args: CommandArgs({
          'start': [0, 0],
          'end': {'x': 4, 'y': 0},
          'len': 4,
          'rot': 90,
          'n': 2.5,
          'i': 3,
          'name': 'A',
          'mode': 'ce',
          'ok': true,
          'ids': [1, 2],
        }),
        params: const [
          ParamSpec.point('start'),
          ParamSpec.point('end'),
          ParamSpec(name: 'len', type: ParamType.distance),
          ParamSpec(name: 'rot', type: ParamType.angle),
          ParamSpec(name: 'n', type: ParamType.number),
          ParamSpec(name: 'i', type: ParamType.integer),
          ParamSpec(name: 'name', type: ParamType.text),
          ParamSpec(
            name: 'mode',
            type: ParamType.choice,
            options: ['center', 'end'],
          ),
          ParamSpec(name: 'ok', type: ParamType.boolean),
          ParamSpec.selection('ids'),
        ],
      );

      expect(input.isInteractive, isFalse);
      expect(await input.point('s'), const Vec2.zero());
      expect(await input.pointOrNull('e'), const Vec2(4, 0));
      expect(await input.distance('d'), 4);
      expect(await input.angle('a'), closeTo(math.pi / 2, 1e-12));
      expect(await input.number('n'), 2.5);
      expect(await input.integer('i'), 3);
      expect(await input.text('t'), 'A');
      expect(await input.keyword('m', ['center', 'end']), 'center');
      expect(await input.confirm('c'), isTrue);
      expect(await input.selection('sel'), [1, 2]);
      input.write('hello');
      expect(input.transcript, ['hello']);
    });

    test('window uses two points and cancel stops a later prompt', () async {
      final input = ArgsCommandInput(
        args: CommandArgs({
          'a': [0, 0],
          'b': [4, 2],
        }),
        params: const [
          ParamSpec.point('a'),
          ParamSpec.point('b'),
        ],
      );
      expect(await input.window('w'), const Bounds2(0, 0, 4, 2));
      input.cancel();
      expect(input.isCancelled, isTrue);
      expect(
        () => ArgsCommandInput(
          args: CommandArgs.empty(),
          params: const [ParamSpec.point('at')],
        ).point('at'),
        throwsA(isA<CommandCancelled>()),
      );
    });

    test('pointOrKeyword returns a point, a keyword, or null', () async {
      final input = ArgsCommandInput(
        args: CommandArgs({
          'start': [0, 0],
          'end': [4, 0],
          'action': 'u',
        }),
        params: const [
          ParamSpec.point('start'),
          ParamSpec.point('end'),
          ParamSpec(name: 'action', type: ParamType.text),
        ],
      );
      final first = await input.pointOrKeyword('first');
      expect(first!.point, const Vec2.zero());
      expect(input.lastPick, const Vec2.zero());
      final second = await input.pointOrKeyword(
        'next',
        keywords: const ['Undo', 'Close'],
      );
      expect(second!.point, const Vec2(4, 0));
      final undo = await input.pointOrKeyword(
        'next',
        keywords: const ['Undo', 'Close'],
      );
      expect(undo!.keyword, 'Undo');
      expect(await input.pointOrKeyword('done'), isNull);
    });

    test('matchKeyword requires a unique prefix', () {
      expect(
        ArgsCommandInput.matchKeyword('ce', ['center', 'end']),
        'center',
      );
      expect(ArgsCommandInput.matchKeyword('e', ['end', 'edge']), isNull);
      expect(ArgsCommandInput.matchKeyword('END', ['end']), 'end');
    });
  });

  group('CommandContext', () {
    test('resolve helpers prefer explicit args over a prompt', () async {
      final session = DocumentSession(id: 't', document: CadDocument());
      session.selection.addAll([7]);
      final context = CommandContext(
        session: session,
        args: CommandArgs({
          'at': [1, 2],
          'n': 3,
          'name': 'X',
          'ids': [9],
        }),
        input: ArgsCommandInput(
          args: CommandArgs.empty(),
          params: const [],
        ),
      );
      expect(await context.resolvePoint('at', 'p'), const Vec2(1, 2));
      expect(await context.resolveNumber('n', 'n'), 3);
      expect(await context.resolveText('name', 't'), 'X');
      expect(await context.resolveSelection('ids', 's'), [9]);
      expect(
        await CommandContext(
          session: session,
          args: CommandArgs.empty(),
          input: ArgsCommandInput(
            args: CommandArgs.empty(),
            params: const [],
          ),
        ).resolveSelection('ids', 's'),
        [7],
      );
    });
  });

  group('CommandDescriptor', () {
    test('tool schema lists required parameters', () {
      final descriptor = CommandDescriptor(
        id: 'draw.line',
        title: 'Line',
        description: 'Draw a segment',
        params: const [
          ParamSpec.point('start'),
          ParamSpec(
            name: 'layer',
            type: ParamType.layer,
            required: false,
          ),
        ],
        handler: (_) async => const CommandResult.ok(),
      );
      expect(descriptor.toolName, 'draw_line');
      expect(descriptor.isBuiltIn, isTrue);
      expect(descriptor.toolSchema()['required'], ['start']);
      expect(descriptor.toToolDefinition()['name'], 'draw_line');
      expect(descriptor.toJson()['id'], 'draw.line');
    });
  });
}
