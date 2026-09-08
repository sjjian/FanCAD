import 'dart:async';
import 'dart:convert';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('fromEnvironment stays silent when the key is missing or blank', () {
    expect(
      OpenAiCompatibleProvider.fromEnvironment(environment: const {}),
      isNull,
    );
    expect(
      OpenAiCompatibleProvider.fromEnvironment(
        environment: const {'OPENAI_API_KEY': '   '},
      ),
      isNull,
    );
  });

  test('a leftover pasted key wins over the environment', () {
    final provider = OpenAiCompatibleProvider.fromEnvironment(
      apiKey: '  sk-pasted  ',
      apiKeyEnvVar: 'OPENAI_API_KEY',
      environment: const {'OPENAI_API_KEY': 'sk-env'},
    );
    expect(provider, isNotNull);
    expect(provider!.apiKey, 'sk-pasted');
  });

  test('fromEnvironment builds a provider from a custom env var', () {
    final provider = OpenAiCompatibleProvider.fromEnvironment(
      apiKeyEnvVar: 'FANCAD_LLM_KEY',
      environment: const {'FANCAD_LLM_KEY': '  test-key  '},
      model: 'local-model',
    );
    expect(provider, isNotNull);
    expect(provider!.apiKey, 'test-key');
    expect(provider.model, 'local-model');
  });

  test('a trailing slash on the base URL does not double the path', () async {
    final client = _FakeClient(
      http.Response(_choiceJson(content: 'ok'), 200),
    );
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      baseUrl: 'https://api.example.com/v1/',
      client: client,
    );

    await provider.completeOnce(_userRequest());
    expect(
      client.lastUri.toString(),
      'https://api.example.com/v1/chat/completions',
    );
  });

  test('a successful reply yields text then a stop reason', () async {
    final client = _FakeClient(
      http.Response(_choiceJson(content: 'hello', finishReason: 'length'), 200),
    );
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: client,
    );

    final events = await provider.complete(_userRequest()).toList();
    expect(events, [
      isA<LlmTextDelta>().having((e) => e.text, 'text', 'hello'),
      isA<LlmFinished>().having((e) => e.finishReason, 'reason', 'length'),
    ]);
  });

  test('tools, temperature and a per-request model go on the wire', () async {
    final client = _FakeClient(http.Response(_choiceJson(content: 'ok'), 200));
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      model: 'default-model',
      client: client,
    );

    await provider.completeOnce(
      LlmRequest(
        messages: const [
          LlmMessage.user('hi'),
          LlmMessage.assistant(
            '',
            toolCalls: [
              LlmToolCall(id: 'c1', name: 'query_summary', arguments: {}),
            ],
          ),
          LlmMessage.tool(
            toolCallId: 'c1',
            content: 'empty',
            name: 'query_summary',
          ),
        ],
        tools: const [
          LlmTool(
            name: 'query_summary',
            description: 'Summarise',
            parameters: {'type': 'object'},
          ),
        ],
        model: 'override-model',
        temperature: 0.2,
        maxTokens: 32,
      ),
    );

    final body = jsonDecode(client.lastBody) as Map<String, Object?>;
    expect(body['model'], 'override-model');
    expect(body['temperature'], 0.2);
    expect(body['max_tokens'], 32);
    expect(body['tools'], isNotEmpty);
    final messages = body['messages'] as List<Object?>;
    expect((messages[1] as Map)['content'], isNull);
    expect((messages[1] as Map)['tool_calls'], isNotEmpty);
    expect((messages[2] as Map)['tool_call_id'], 'c1');
    expect((messages[2] as Map)['name'], 'query_summary');
    expect(client.lastHeaders['authorization'], 'Bearer test-key');
  });

  test('tool calls skip junk entries and keep raw JSON that is not an object',
      () async {
    final client = _FakeClient(
      http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'tool_calls': [
                  'not-a-map',
                  {'function': 'not-a-map'},
                  {
                    'function': {'name': ''},
                  },
                  {
                    'function': {
                      'name': 'draw_line',
                      'arguments': '{not json',
                    },
                  },
                  {
                    'id': 'c2',
                    'function': {
                      'name': 'query_summary',
                      'arguments': {'ok': true},
                    },
                  },
                ],
              },
            },
          ],
        }),
        200,
      ),
    );
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: client,
    );

    final events = await provider.complete(_userRequest()).toList();
    final calls = (events.first as LlmToolCalls).calls;
    expect(calls, hasLength(2));
    expect(calls[0].id, 'call_0');
    expect(calls[0].arguments, {'raw': '{not json'});
    expect(calls[1].id, 'c2');
    expect(calls[1].arguments['ok'], true);
  });

  test('HTTP errors, broken JSON and empty choices become LlmError', () async {
    Future<LlmEvent> first(http.Response response) {
      return OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: _FakeClient(response),
      ).complete(_userRequest()).first;
    }

    final longBody = 'x' * 300;
    final httpError = await first(http.Response(longBody, 502));
    expect(httpError, isA<LlmError>());
    expect((httpError as LlmError).message, contains('HTTP 502'));
    expect(httpError.message.contains('…'), isTrue);
    expect(httpError.message.length, lessThan(longBody.length));

    expect(
      await first(http.Response('not-json', 200)),
      isA<LlmError>().having(
        (e) => e.message,
        'message',
        contains('not JSON'),
      ),
    );
    expect(
      await first(http.Response('{"choices":[]}', 200)),
      isA<LlmError>().having(
        (e) => e.message,
        'message',
        contains('no choices'),
      ),
    );
    expect(
      await first(http.Response('{"choices":["x"]}', 200)),
      isA<LlmError>().having(
        (e) => e.message,
        'message',
        contains('malformed choice'),
      ),
    );
    expect(
      await first(http.Response('{"choices":[{"message":1}]}', 200)),
      isA<LlmError>().having(
        (e) => e.message,
        'message',
        contains('malformed message'),
      ),
    );
  });

  test('a transport failure is reported instead of thrown', () async {
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: _FakeClient.error(Exception('offline')),
    );
    final event = await provider.complete(_userRequest()).first;
    expect(
      event,
      isA<LlmError>().having((e) => e.message, 'message', contains('offline')),
    );
  });

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
  _FakeClient(this._response) : _error = null;

  _FakeClient.error(this._error) : _response = null;

  final http.Response? _response;
  final Object? _error;

  Uri? lastUri;
  String lastBody = '';
  Map<String, String> lastHeaders = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    lastHeaders = request.headers;
    if (request is http.Request) lastBody = request.body;
    if (_error != null) throw _error;
    final response = _response!;
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
