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

  test('an edit tool asks for approval and does not run when declined',
      () async {
    var asked = 0;
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
          ],
        ),
      ]),
      registry: registry,
      execute: execute,
      document: session.document,
      askApproval: (pending) async {
        asked++;
        expect(pending.calls, hasLength(1));
        return false;
      },
    );

    final turn = await agent.run('Draw a line');
    expect(asked, 1);
    expect(turn.cancelled, isTrue);
    expect(ran, isEmpty);
    expect(session.document.entities, isEmpty);
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
}
