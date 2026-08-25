import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

void main() {
  test('streamed leftovers paint tokens as they arrive', () async {
    final conversation = Conversation();
    final deltas = <String>[];
    final agent = AgentLoop(
      provider: _ChunkedProvider(),
      registry: CommandRegistry(),
      execute: (id, args) async => CommandResult.failed(id),
      document: CadDocument(),
      conversation: conversation,
      onDelta: deltas.add,
    );

    final turn = await agent.run('Hi');
    expect(turn.isOk, isTrue);
    expect(deltas, ['Hel', 'lo']);
    expect(conversation.visible.where((item) => item.role == ChatRole.assistant),
        hasLength(1));
    expect(
      conversation.visible.singleWhere((item) => item.role == ChatRole.assistant).text,
      'Hello',
    );
  });

  test('a leftover incomplete tool call retries without streaming', () async {
    final registry = CommandRegistry()
      ..register(
        CommandDescriptor(
          id: 'draw.line',
          title: 'Line',
          params: const [
            ParamSpec(name: 'start', type: ParamType.point),
            ParamSpec(name: 'end', type: ParamType.point),
          ],
          handler: (context) async {
            context.edit('LINE', (transaction) {
              transaction.add(
                LineEntity(
                  id: 0,
                  start: context.args.point('start') ?? const Vec2.zero(),
                  end: context.args.point('end') ?? const Vec2(1, 0),
                ),
              );
            });
            return const CommandResult.ok();
          },
        ),
      );
    final session = DocumentSession(id: 't', document: CadDocument());
    final provider = _IncompleteToolProvider();
    final agent = AgentLoop(
      provider: provider,
      registry: registry,
      execute: (id, args) => registry.run(
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
      ),
      document: session.document,
      policy: const ApprovalPolicy(autoApproveEdits: true),
    );

    final turn = await agent.run('Draw a line');
    expect(turn.isOk, isTrue);
    // Incomplete args stream once, the retry is one-shot, then the leftover
    // follow-up after the tool ran streams the closing sentence.
    expect(provider.streamed, 2);
    expect(provider.oneShot, 1);
    expect(session.document.entityCount, 1);
  });

  test('leftover reasoning tokens paint a thinking card, not the reply',
      () async {
    final conversation = Conversation();
    final agent = AgentLoop(
      provider: _ReasoningProvider(),
      registry: CommandRegistry(),
      execute: (id, args) async => CommandResult.failed(id),
      document: CadDocument(),
      conversation: conversation,
    );

    final turn = await agent.run('Hi');
    expect(turn.isOk, isTrue);
    expect(turn.reply, 'Hello');
    expect(conversation.visible.map((item) => item.role), [
      ChatRole.user,
      ChatRole.reasoning,
      ChatRole.assistant,
    ]);
    expect(conversation.visible[1].text, 'think first');
    expect(conversation.llmMessages.last.content, 'Hello');
    expect(conversation.llmMessages.last.content, isNot(contains('think')));
  });
}

class _ReasoningProvider extends LlmProvider {
  @override
  String get name => 'reasoning';

  @override
  Stream<LlmEvent> complete(LlmRequest request) async* {
    yield const LlmReasoningDelta('think first');
    yield const LlmTextDelta('Hello');
    yield const LlmFinished();
  }
}

class _ChunkedProvider extends LlmProvider {
  @override
  String get name => 'chunked';

  @override
  Stream<LlmEvent> complete(LlmRequest request) async* {
    yield const LlmTextDelta('Hel');
    yield const LlmTextDelta('lo');
    yield const LlmFinished();
  }
}

class _IncompleteToolProvider extends LlmProvider {
  @override
  String get name => 'incomplete';

  var streamed = 0;
  var oneShot = 0;

  @override
  Stream<LlmEvent> complete(LlmRequest request) async* {
    if (request.stream) {
      streamed++;
      if (oneShot > 0) {
        yield const LlmTextDelta('Drew it.');
        yield const LlmFinished();
        return;
      }
      yield const LlmToolCalls([
        LlmToolCall(id: '1', name: 'draw_line', arguments: {}),
      ]);
      yield const LlmFinished(finishReason: 'tool_calls');
      return;
    }
    oneShot++;
    yield const LlmToolCalls([
      LlmToolCall(
        id: '1',
        name: 'draw_line',
        arguments: {
          'start': [0, 0],
          'end': [4, 0],
        },
      ),
    ]);
    yield const LlmFinished();
  }
}
