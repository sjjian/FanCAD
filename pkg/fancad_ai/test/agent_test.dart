import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  late CommandRegistry registry;
  late DocumentSession session;
  late List<String> ran;

  setUp(() {
    registry = CommandRegistry();
    session = DocumentSession(id: 't', document: CadDocument());
    ran = [];
    registry.register(
      CommandDescriptor(
        id: 'query.summary',
        title: 'Summary',
        risk: CommandRisk.readOnly,
        description: 'Summarises the drawing.',
        handler: (context) async {
          ran.add('query.summary');
          return CommandResult.ok(
            data: {'entityCount': context.document.entityCount},
          );
        },
      ),
    );
    registry.register(
      CommandDescriptor(
        id: 'draw.line',
        title: 'Line',
        description: 'Draws a line.',
        params: const [
          ParamSpec(name: 'start', type: ParamType.point),
          ParamSpec(name: 'end', type: ParamType.point),
        ],
        handler: (context) async {
          ran.add('draw.line');
          context.edit('LINE', (transaction) {
            transaction.add(
              LineEntity(
                id: 0,
                start: context.args.point('start') ?? const Vec2.zero(),
                end: context.args.point('end') ?? const Vec2(1, 0),
              ),
            );
          });
          return const CommandResult.ok(message: 'drew a line');
        },
      ),
    );
    registry.register(
      CommandDescriptor(
        id: 'edit.erase',
        title: 'Erase',
        risk: CommandRisk.destructive,
        handler: (context) async {
          ran.add('edit.erase');
          return const CommandResult.ok();
        },
      ),
    );
  });

  Future<CommandResult> execute(String id, Map<String, Object?> args) {
    return registry.run(
      id,
      args: args,
      source: ChangeSource.ai,
      contextBuilder: (descriptor) => CommandContext(
        session: session,
        args: CommandArgs(args),
        input: ArgsCommandInput(
          args: CommandArgs(args),
          params: descriptor.params,
          selection: session.selection,
        ),
        source: ChangeSource.ai,
        commandId: id,
      ),
    );
  }

  test('a text-only reply does not touch the drawing', () async {
    final agent = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(text: 'The drawing is empty.'),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
    );

    final turn = await agent.run('What is in this drawing?');
    expect(turn.reply, contains('empty'));
    expect(turn.toolCalls, isEmpty);
    expect(session.document.entities, isEmpty);
  });

  test('an empty message does not call the model', () async {
    final provider = ScriptedLlmProvider([
      const LlmCompletion(text: 'should not run'),
    ]);
    final conversation = Conversation();
    final agent = AgentLoop(
      provider: provider,
      registry: registry,
      execute: execute,
      document: session.document,
      conversation: conversation,
    );

    final turn = await agent.run('   ');
    expect(turn.isOk, isFalse);
    expect(turn.error, contains('empty'));
    expect(provider.remaining, 1);
    expect(conversation.visible, isEmpty);
    expect(conversation.llmMessages, isEmpty);
  });

  test('a read-only tool runs without asking', () async {
    final agent = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(id: '1', name: 'query_summary', arguments: {}),
          ],
        ),
        const LlmCompletion(text: 'Nothing is drawn yet.'),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
    );

    final turn = await agent.run('Summarise this.');
    expect(ran, ['query.summary']);
    expect(turn.reply, contains('Nothing'));
    expect(turn.cancelled, isFalse);
  });

  test('a leftover draw runs without asking; a declined delete does not',
      () async {
    var asked = 0;
    final draw = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(
              id: '1',
              name: 'draw_line',
              arguments: {
                'start': [0, 0],
                'end': [10, 0],
              },
            ),
          ],
        ),
        const LlmCompletion(text: 'Drew a line.'),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
      askApproval: (_) async {
        asked++;
        return false;
      },
    );

    final drawn = await draw.run('Draw a line');
    expect(asked, 0);
    expect(drawn.cancelled, isFalse);
    expect(ran, ['draw.line']);
    expect(session.document.entities, hasLength(1));

    final erase = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(
              id: '2',
              name: 'edit_erase',
              arguments: {
                'ids': [1],
              },
            ),
          ],
        ),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
      conversation: Conversation(),
      askApproval: (pending) async {
        asked++;
        expect(pending.calls, hasLength(1));
        expect(pending.calls.single.name, 'edit_erase');
        return false;
      },
    );

    final turned = await erase.run('Erase it');
    expect(asked, 1);
    expect(turned.cancelled, isTrue);
    expect(ran, ['draw.line']);
  });

  test('an approved edit applies and one turn is one undo entry', () async {
    final agent = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(
              id: '1',
              name: 'draw_line',
              arguments: {
                'start': [0, 0],
                'end': [10, 0],
              },
            ),
            LlmToolCall(
              id: '2',
              name: 'draw_line',
              arguments: {
                'start': [0, 1],
                'end': [10, 1],
              },
            ),
          ],
        ),
        const LlmCompletion(text: 'Drew two lines.'),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
      history: session.history,
      policy: const ApprovalPolicy(autoApproveEdits: true),
    );

    final turn = await agent.run('Draw two lines');
    expect(turn.isOk, isTrue);
    expect(session.document.entities, hasLength(2));
    expect(session.history.depth, 1);
    expect(session.history.undoEntries.single.label, 'Assistant turn');

    session.undo();
    expect(session.document.entities, isEmpty);
  });

  test('a missing provider reply is reported rather than thrown', () async {
    final agent = AgentLoop(
      provider: ScriptedLlmProvider(const []),
      registry: registry,
      execute: execute,
      document: session.document,
    );
    final turn = await agent.run('Hello');
    expect(turn.error, isNotNull);
  });

  test('declining a delete still runs the read-only remainder', () async {
    final deltas = <String>[];
    final agent = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(id: '1', name: 'query_summary', arguments: {}),
            LlmToolCall(
              id: '2',
              name: 'edit_erase',
              arguments: {
                'ids': [1],
              },
            ),
          ],
        ),
        const LlmCompletion(text: 'Counted, did not erase.'),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
      onDelta: deltas.add,
      askApproval: (_) async => false,
    );

    final turn = await agent.run('Summarise then erase');
    expect(ran, ['query.summary']);
    expect(turn.cancelled, isFalse);
    expect(turn.reply, contains('Counted'));
    expect(deltas, ['Counted, did not erase.']);
  });

  test('unknown, hidden and thrown tools become failed rows, not crashes',
      () async {
    registry.register(
      CommandDescriptor(
        id: 'view.zoomIn',
        title: 'Zoom In',
        aiExposure: AiExposure.hidden,
        handler: (_) async => const CommandResult.ok(),
      ),
    );
    final conversation = Conversation();
    final agent = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(id: '1', name: 'no_such_tool', arguments: {}),
            LlmToolCall(id: '2', name: 'view_zoomIn', arguments: {}),
            LlmToolCall(id: '3', name: 'query_summary', arguments: {}),
          ],
        ),
        const LlmCompletion(text: 'Done.'),
      ]),
      registry: registry,
      conversation: conversation,
      execute: (id, args) async {
        if (id == 'query.summary') throw StateError('offline');
        return execute(id, args);
      },
      document: session.document,
      policy: const ApprovalPolicy(autoApproveEdits: true),
      askApproval: (_) async => true,
    );

    final turn = await agent.run('Zoom and summarise');
    expect(turn.isOk, isTrue);
    expect(ran, isEmpty);
    final texts = conversation.visible
        .where((item) => item.role == ChatRole.tool)
        .map((item) => item.text)
        .toList();
    expect(texts, hasLength(3));
    expect(texts[0], contains('Unknown tool'));
    expect(texts[1], contains('not available'));
    expect(texts[2], contains('offline'));
  });

  test('a failed plugin activate ships a repair hint and max rounds stop',
      () async {
    registry.register(
      CommandDescriptor(
        id: 'plugins.reload',
        title: 'Reload',
        risk: CommandRisk.edit,
        handler: (_) async =>
            const CommandResult.failed('could not activate: SyntaxError'),
      ),
    );
    final conversation = Conversation();
    final reload = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(
              id: '1',
              name: 'plugins_reload',
              arguments: {'id': 'demo.wall'},
            ),
          ],
        ),
        const LlmCompletion(text: 'I will fix it.'),
      ]),
      registry: registry,
      conversation: conversation,
      execute: execute,
      document: session.document,
      typings: 'declare const fancad: FanCadApi;',
      policy: const ApprovalPolicy(autoApproveEdits: true),
    );

    await reload.run('Reload the plugin');
    expect(
      conversation.visible.singleWhere((item) => item.role == ChatRole.tool).text,
      contains('repairHint'),
    );
    expect(
      conversation.visible.singleWhere((item) => item.role == ChatRole.tool).text,
      contains('plugins.write'),
    );

    final looping = AgentLoop(
      provider: ScriptedLlmProvider([
        const LlmCompletion(
          toolCalls: [
            LlmToolCall(id: '1', name: 'query_summary', arguments: {}),
          ],
        ),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
      maxRounds: 1,
    );
    final stopped = await looping.run('Keep going');
    expect(stopped.error, contains('Stopped after 1'));
    expect(ran, ['query.summary']);
  });
}
