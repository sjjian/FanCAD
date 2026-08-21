import 'provider.dart';

/// A scripted provider for tests and for running the agent without a network.
///
/// Each [complete] call consumes the next scripted [LlmCompletion]. Exhausting
/// the script is an error: a test that did not say what the model should do
/// next is a test that is not testing the agent.
class ScriptedLlmProvider extends LlmProvider {
  ScriptedLlmProvider(this.script, {this.name = 'scripted'});

  @override
  final String name;

  /// Completions to return, in order.
  final List<LlmCompletion> script;

  int _index = 0;
  final List<LlmRequest> requests = [];

  int get remaining => script.length - _index;

  @override
  Stream<LlmEvent> complete(LlmRequest request) async* {
    requests.add(request);
    if (_index >= script.length) {
      yield const LlmError('scripted provider has no more replies');
      return;
    }
    final next = script[_index++];
    if (next.text.isNotEmpty) yield LlmTextDelta(next.text);
    if (next.toolCalls.isNotEmpty) yield LlmToolCalls(next.toolCalls);
    yield LlmFinished(finishReason: next.finishReason);
  }
}
