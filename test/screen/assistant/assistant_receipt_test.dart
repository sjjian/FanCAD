import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover tool error uses the error field, not raw JSON', () {
    const message = ChatMessage(
      role: ChatRole.tool,
      toolName: 'draw_polyline',
      text:
          '{"status":"failed","error":"Polyline needs points as [[x, y], ...]."}',
      isError: true,
    );
    final receipt = parseAssistantReceipt(message);
    expect(receipt.headline, contains('Polyline needs points'));
    expect(receipt.headline, isNot(contains('status')));
    expect(receipt.isError, isTrue);
  });

  test('a leftover JSON blob is not dumped into the receipt headline', () {
    final message = ChatMessage(
      role: ChatRole.tool,
      toolName: 'read_skill',
      text: '{"skill":"inspect-drawing","body":"${'x' * 200}"}',
    );
    final receipt = parseAssistantReceipt(message);
    expect(receipt.verb, 'SKILL');
    expect(receipt.summary, 'result');
    expect(receipt.headline, isNot(contains('inspect-drawing')));
    expect(receipt.headline, isNot(contains('xxx')));
    expect(receipt.raw, contains('inspect-drawing'));
  });

  test('a CommandResult leftover uses summary, not the raw map', () {
    const message = ChatMessage(
      role: ChatRole.tool,
      toolName: 'draw_ellipse',
      text:
          '{"status":"ok","message":"created","change":{"summary":"Add ellipse"}}',
    );
    final receipt = parseAssistantReceipt(message);
    expect(receipt.headline, 'ELLIPSE  Add ellipse');
    expect(receipt.headline, isNot(contains('status')));
  });

  test('a leftover transcript keeps a gap above the composer', () {
    expect(assistantTranscriptTail(0), FanCadTokens.space5);
    expect(assistantTranscriptTail(400), 400);
  });

  test('a leftover waiting turn still shows a live working row', () {
    expect(
      assistantPanelShowsWorking(busy: false, messages: const []),
      isFalse,
    );
    expect(assistantPanelShowsWorking(busy: true, messages: const []), isTrue);
    expect(
      assistantPanelShowsWorking(
        busy: true,
        messages: const [
          ChatMessage(role: ChatRole.user, text: 'draw a turtle'),
        ],
      ),
      isTrue,
    );
    expect(
      assistantPanelShowsCaret(
        busy: true,
        messages: const [
          ChatMessage(role: ChatRole.assistant, text: 'Drawing'),
        ],
      ),
      isTrue,
    );
    expect(
      assistantPanelShowsCaret(
        busy: true,
        messages: const [ChatMessage(role: ChatRole.user, text: 'hi')],
      ),
      isFalse,
    );
    expect(
      assistantPanelShowsWorking(
        busy: true,
        messages: const [
          ChatMessage(role: ChatRole.reasoning, text: 'plan the tail'),
        ],
      ),
      isFalse,
    );
  });

  test('consecutive leftover successes of one tool collapse', () {
    final messages = [
      const ChatMessage(role: ChatRole.user, text: 'draw turtles'),
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'draw_ellipse',
        text: '{"status":"ok","change":{"summary":"Add ellipse"}}',
      ),
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'draw_ellipse',
        text: '{"status":"ok","change":{"summary":"Add ellipse"}}',
      ),
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'draw_line',
        text: '{"status":"ok","change":{"summary":"Add line"}}',
      ),
    ];
    final entries = groupAssistantLog(messages);
    expect(entries, hasLength(3));
    expect(
      (entries[1] as AssistantLogReceiptModel).receipt.headline,
      'ELLIPSE ×2  Add ellipse',
    );
    expect(
      (entries[2] as AssistantLogReceiptModel).receipt.headline,
      'LINE  Add line',
    );
  });

  test('leftover declined calls of one tool collapse', () {
    const declined =
        '{"status":"cancelled","message":"The user declined this change."}';
    final entries = groupAssistantLog([
      const ChatMessage(role: ChatRole.user, text: 'draw a turtle'),
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'draw_ellipse',
        text: declined,
        isError: true,
      ),
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'draw_ellipse',
        text: declined,
        isError: true,
      ),
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'draw_circle',
        text: declined,
        isError: true,
      ),
    ]);
    expect(entries, hasLength(3));
    expect(
      (entries[1] as AssistantLogReceiptModel).receipt.headline,
      'ELLIPSE ×2  The user declined this change.',
    );
    expect(
      (entries[2] as AssistantLogReceiptModel).receipt.headline,
      'CIRCLE  The user declined this change.',
    );
  });

  test('exec cards keep each snippet instead of collapsing', () {
    const first = '{"status":"ok","message":"2","source":"1 + 1"}';
    const second =
        '{"status":"ok","message":"undefined","source":"const a = 1;\\na"}';
    final entries = groupAssistantLog([
      const ChatMessage(role: ChatRole.tool, toolName: 'exec', text: first),
      const ChatMessage(role: ChatRole.tool, toolName: 'exec', text: second),
    ]);
    expect(entries, hasLength(2));
    expect(execCardSource(first), '1 + 1');
    expect(execCardSource(second), 'const a = 1;\na');
    expect(execCardSource('{"status":"ok","message":"2"}'), isNull);
    expect(execCardResult(first), '2');
    expect(
      execCardResult(
        '{"status":"ok","message":"{\\"a\\":1...","value":{"minx":1,"maxx":2}}',
      ),
      '{\n  "minx": 1,\n  "maxx": 2\n}',
    );
    expect(
      execCardResult('{"status":"failed","error":"nope","message":"nope"}'),
      'nope',
    );
    expect(execCardResult('{"status":"ok","value":null}'), 'undefined');
  });

  test('a tool card names exec by its first line and indents cli json', () {
    final exec = parseAssistantReceipt(
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'exec',
        text:
            '{"status":"ok","message":"2","value":2,"source":"const a = 1;\\na"}',
      ),
    );
    expect(assistantToolDescription(exec), 'const a = 1;');

    const raw = '{"status":"ok","message":"Nothing selected.","data":{"n":1}}';
    final cli = parseAssistantReceipt(
      const ChatMessage(
        role: ChatRole.tool,
        toolName: 'query.session',
        text: raw,
      ),
    );
    expect(assistantToolDescription(cli), 'query.session');
    expect(cli.verb, 'SESSION');
    final formatted = formatReceiptJson(raw);
    expect(formatted, contains('\n'));
    expect(formatted, contains('  "status"'));
    expect(formatted, contains('  "data"'));
    expect(formatReceiptJson('not json'), 'not json');

    const withInput =
        '{"status":"ok","message":"Nothing selected.","data":{"n":1},"input":{"action":"run","path":"query.session"}}';
    expect(cliCardInput(withInput), contains('"path"'));
    expect(cliCardInput(withInput), contains('query.session'));
    expect(cliCardInput(raw), isNull);
    final output = cliCardOutput(withInput);
    expect(output, contains('"data"'));
    expect(output, isNot(contains('"input"')));
  });
}
