import 'package:fancad_ai/fancad_ai.dart';
import 'package:test/test.dart';

void main() {
  test('message and tool JSON keep role, calls and names on the wire', () {
    const system = LlmMessage.system('be brief');
    const call = LlmToolCall(
      id: 'c1',
      name: 'query_summary',
      arguments: {'limit': 2},
    );
    const assistant = LlmMessage.assistant('', toolCalls: [call]);
    const tool = LlmMessage.tool(
      toolCallId: 'c1',
      content: 'ok',
      name: 'query_summary',
    );
    const advertised = LlmTool(
      name: 'query_summary',
      description: 'Summarise',
      parameters: {'type': 'object'},
    );

    expect(system.toJson(), {'role': 'system', 'content': 'be brief'});
    expect(assistant.toJson()['tool_calls'], [call.toJson()]);
    expect(call.toJson(), {
      'id': 'c1',
      'type': 'function',
      'function': {
        'name': 'query_summary',
        'arguments': {'limit': 2},
      },
    });
    expect(tool.toJson(), {
      'role': 'tool',
      'content': 'ok',
      'tool_call_id': 'c1',
      'name': 'query_summary',
    });
    expect(advertised.toJson()['type'], 'function');
    expect((advertised.toJson()['function'] as Map)['name'], 'query_summary');
  });
}
