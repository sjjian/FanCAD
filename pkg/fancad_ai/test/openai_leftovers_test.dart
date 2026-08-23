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

  test(
    'completeOnce joins text and turns an HTTP failure into LlmException',
    () async {
      final ok = OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: _FakeClient(
          http.Response(
            _choiceJson(content: 'hello', finishReason: 'length'),
            200,
          ),
        ),
      );
      final completion = await ok.completeOnce(_userRequest());
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
      if (finishReason != null) 'finish_reason': finishReason,
      'message': {if (content != null) 'content': content},
    },
  ],
});

class _FakeClient extends http.BaseClient {
  _FakeClient(this._response);

  final http.Response _response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(_response.bodyBytes),
      _response.statusCode,
      headers: _response.headers,
    );
  }
}
