import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_ui/fancad_ui.dart';
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
    expect(assistantTranscriptTail(400), greaterThan(FanCadTokens.space2));
    expect(assistantTranscriptTail(400), lessThan(400));
    expect(assistantTranscriptTail(400), 160);
  });

  test('a leftover waiting turn still shows a live working row', () {
    expect(
      assistantPanelShowsWorking(busy: false, messages: const []),
      isFalse,
    );
    expect(
      assistantPanelShowsWorking(busy: true, messages: const []),
      isTrue,
    );
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
    expect(entries[1].receipt!.headline, 'ELLIPSE ×2  Add ellipse');
    expect(entries[2].receipt!.headline, 'LINE  Add line');
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
      entries[1].receipt!.headline,
      'ELLIPSE ×2  The user declined this change.',
    );
    expect(
      entries[2].receipt!.headline,
      'CIRCLE  The user declined this change.',
    );
  });
}
