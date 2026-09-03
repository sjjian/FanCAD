import 'dart:async';
import 'dart:convert';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('empty model content is not a text delta', () async {
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: _FakeClient(http.Response(_choiceJson(), 200)),
    );

    final events = await provider.complete(_userRequest()).toList();
    expect(events, [
      isA<LlmFinished>().having(
        (event) => event.finishReason,
        'reason',
        'stop',
      ),
    ]);
  });

  test('leftover reasoning_content is a thinking delta, not reply text',
      () async {
    final body = [
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'reasoning_content': 'plan '},
          },
        ],
      })}',
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
      })}',
      'data: [DONE]',
    ].join('\n');
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: _FakeClient(
        http.Response(
          body,
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );

    final events = await provider.complete(_userRequest()).toList();
    expect(events, [
      isA<LlmReasoningDelta>().having((event) => event.text, 'text', 'plan '),
      isA<LlmTextDelta>().having((event) => event.text, 'text', 'ok'),
      isA<LlmFinished>(),
    ]);

    final once = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: _FakeClient(
        http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'reasoning_content': 'hidden leftover',
                  'content': 'visible',
                },
              },
            ],
          }),
          200,
        ),
      ),
    );
    final completion = await once.completeOnce(_userRequest());
    expect(completion.text, 'visible');
    expect(completion.text, isNot(contains('hidden leftover')));
  });

  test('a leftover empty-choices usage chunk is not reply text', () async {
    final body = [
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
      })}',
      'data: ${jsonEncode({
        'choices': <Object?>[],
        'usage': {
          'prompt_tokens': 12400,
          'completion_tokens': 12,
          'total_tokens': 12412,
        },
      })}',
      'data: [DONE]',
    ].join('\n');
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: _FakeClient(
        http.Response(
          body,
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );

    final events = await provider.complete(_userRequest()).toList();
    expect(events, [
      isA<LlmTextDelta>().having((event) => event.text, 'text', 'ok'),
      isA<LlmFinished>()
          .having((event) => event.usage?.promptTokens, 'prompt', 12400)
          .having((event) => event.usage?.completionTokens, 'completion', 12),
    ]);
    expect(
      events.whereType<LlmTextDelta>().map((event) => event.text).join(),
      isNot(contains('12400')),
    );
  });

  test('an event-stream leftover yields one delta per data line', () async {
    final body = [
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': 'Hel'},
          },
        ],
      })}',
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': 'lo'},
            'finish_reason': 'stop',
          },
        ],
      })}',
      'data: [DONE]',
    ].join('\n');
    final client = _FakeClient(
      http.Response(
        body,
        200,
        headers: {'content-type': 'text/event-stream'},
      ),
    );
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: client,
    );

    final events = await provider.complete(_userRequest()).toList();
    expect(jsonDecode(client.lastBody)['stream'], isTrue);
    expect(events, [
      isA<LlmTextDelta>().having((event) => event.text, 'text', 'Hel'),
      isA<LlmTextDelta>().having((event) => event.text, 'text', 'lo'),
      isA<LlmFinished>().having(
        (event) => event.finishReason,
        'reason',
        'stop',
      ),
    ]);
  });

  test(
    'completeOnce joins text and turns an HTTP failure into LlmException',
    () async {
      final client = _FakeClient(
        http.Response(
          _choiceJson(content: 'hello', finishReason: 'length'),
          200,
        ),
      );
      final ok = OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: client,
      );
      final completion = await ok.completeOnce(_userRequest());
      expect(jsonDecode(client.lastBody)['stream'], isFalse);
      expect(completion.text, 'hello');
      expect(completion.finishReason, 'length');
      expect(completion.toolCalls, isEmpty);

      final failed = OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: _FakeClient(http.Response('nope', 503)),
      );
      await expectLater(
        failed.completeOnce(_userRequest()),
        throwsA(
          isA<LlmException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    },
  );
}

LlmRequest _userRequest() =>
    const LlmRequest(messages: [LlmMessage.user('hi')]);

String _choiceJson({String? content, String? finishReason}) => jsonEncode({
  'choices': [
    {
      'finish_reason': ?finishReason,
      'message': {'content': ?content},
    },
  ],
});

class _FakeClient extends http.BaseClient {
  _FakeClient(this._response);

  final http.Response _response;
  String lastBody = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) lastBody = request.body;
    return http.StreamedResponse(
      Stream<List<int>>.value(_response.bodyBytes),
      _response.statusCode,
      headers: _response.headers,
    );
  }
}
