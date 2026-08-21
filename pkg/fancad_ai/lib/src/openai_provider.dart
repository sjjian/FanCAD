import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'provider.dart';

/// An OpenAI-compatible chat-completions provider.
///
/// Works against OpenAI, Azure-compatible proxies, and local servers that
/// speak the same `/v1/chat/completions` shape. The API key is read from an
/// environment variable rather than stored in settings, so a settings file
/// that is copied or committed cannot leak a credential.
class OpenAiCompatibleProvider extends LlmProvider {
  OpenAiCompatibleProvider({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.name = 'openai',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  final String name;

  final String apiKey;
  final String baseUrl;
  final String model;
  final http.Client _client;

  /// Builds a provider from environment and settings. Returns null when no
  /// key is available, so the UI can say "configure a key" instead of failing
  /// on the first message.
  static OpenAiCompatibleProvider? fromEnvironment({
    String baseUrl = 'https://api.openai.com/v1',
    String model = 'gpt-4o-mini',
    String apiKeyEnvVar = 'OPENAI_API_KEY',
    Map<String, String>? environment,
  }) {
    final env = environment ?? const <String, String>{};
    final key = (env[apiKeyEnvVar] ?? '').trim();
    if (key.isEmpty) return null;
    return OpenAiCompatibleProvider(
      apiKey: key,
      baseUrl: baseUrl,
      model: model,
    );
  }

  @override
  Stream<LlmEvent> complete(LlmRequest request) async* {
    final uri = Uri.parse(
      baseUrl.endsWith('/')
          ? '${baseUrl}chat/completions'
          : '$baseUrl/chat/completions',
    );
    final body = <String, Object?>{
      'model': request.model ?? model,
      'messages': [for (final message in request.messages) _encodeMessage(message)],
      if (request.tools.isNotEmpty)
        'tools': [for (final tool in request.tools) tool.toJson()],
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
    };

    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );
    } catch (error) {
      yield LlmError('Could not reach the model: $error');
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      yield LlmError(
        'The model returned HTTP ${response.statusCode}: ${_brief(response.body)}',
      );
      return;
    }

    Map<String, Object?> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, Object?>;
    } on FormatException {
      yield const LlmError('The model returned a response that was not JSON');
      return;
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      yield const LlmError('The model returned no choices');
      return;
    }
    final choice = choices.first;
    if (choice is! Map) {
      yield const LlmError('The model returned a malformed choice');
      return;
    }
    final message = choice['message'];
    if (message is! Map) {
      yield const LlmError('The model returned a malformed message');
      return;
    }

    final content = message['content'];
    if (content is String && content.isNotEmpty) {
      yield LlmTextDelta(content);
    }

    final rawCalls = message['tool_calls'];
    if (rawCalls is List && rawCalls.isNotEmpty) {
      final calls = <LlmToolCall>[];
      for (final raw in rawCalls) {
        if (raw is! Map) continue;
        final function = raw['function'];
        if (function is! Map) continue;
        final name = function['name'] as String? ?? '';
        if (name.isEmpty) continue;
        calls.add(
          LlmToolCall(
            id: raw['id'] as String? ?? 'call_${calls.length}',
            name: name,
            arguments: _decodeArguments(function['arguments']),
          ),
        );
      }
      if (calls.isNotEmpty) yield LlmToolCalls(calls);
    }

    yield LlmFinished(
      finishReason: choice['finish_reason'] as String? ?? 'stop',
    );
  }

  static Map<String, Object?> _encodeMessage(LlmMessage message) {
    final encoded = <String, Object?>{'role': message.role.name};
    if (message.role == LlmRole.tool) {
      encoded['tool_call_id'] = message.toolCallId;
      encoded['content'] = message.content;
      if (message.name != null) encoded['name'] = message.name;
      return encoded;
    }
    if (message.content.isNotEmpty) encoded['content'] = message.content;
    if (message.toolCalls.isNotEmpty) {
      encoded['tool_calls'] = [
        for (final call in message.toolCalls)
          {
            'id': call.id,
            'type': 'function',
            'function': {
              'name': call.name,
              'arguments': jsonEncode(call.arguments),
            },
          },
      ];
    }
    return encoded;
  }

  static Map<String, Object?> _decodeArguments(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) {
      return {for (final entry in raw.entries) '${entry.key}': entry.value};
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return {
            for (final entry in decoded.entries) '${entry.key}': entry.value,
          };
        }
      } on FormatException {
        return {'raw': raw};
      }
    }
    return {};
  }

  static String _brief(String body) {
    final trimmed = body.trim();
    if (trimmed.length <= 240) return trimmed;
    return '${trimmed.substring(0, 240)}…';
  }
}
