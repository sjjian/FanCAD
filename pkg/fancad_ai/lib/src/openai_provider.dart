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
    String apiKey = '',
    String apiKeyEnvVar = 'OPENAI_API_KEY',
    Map<String, String>? environment,
  }) {
    final env = environment ?? const <String, String>{};
    final pasted = apiKey.trim();
    final fromEnv = (env[apiKeyEnvVar] ?? '').trim();
    final key = pasted.isNotEmpty ? pasted : fromEnv;
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
    final stream = request.stream;
    final body = <String, Object?>{
      'model': request.model ?? model,
      'messages': [
        for (final message in request.messages) _encodeMessage(message),
      ],
      'stream': stream,
      if (stream) 'stream_options': {'include_usage': true},
      if (request.tools.isNotEmpty)
        'tools': [for (final tool in request.tools) tool.toJson()],
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
    };

    http.StreamedResponse response;
    try {
      final httpRequest = http.Request('POST', uri)
        ..headers.addAll({
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
          if (stream) 'accept': 'text/event-stream',
        })
        ..body = jsonEncode(body);
      response = await _client.send(httpRequest);
    } catch (error) {
      yield LlmError('Could not reach the model: $error');
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final raw = await response.stream.bytesToString();
      yield LlmError(
        'The model returned HTTP ${response.statusCode}: ${_brief(raw)}',
      );
      return;
    }

    final contentType = response.headers['content-type'] ?? '';
    if (stream && contentType.contains('event-stream')) {
      yield* _readSse(response);
      return;
    }

    final raw = await response.stream.bytesToString();
    yield* _readJson(raw);
  }

  Stream<LlmEvent> _readSse(http.StreamedResponse response) async* {
    final pending = <_StreamingToolCall>[];
    var finish = 'stop';
    var sawToolDelta = false;
    LlmUsage? usage;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      Object? decoded;
      try {
        decoded = jsonDecode(data);
      } on FormatException {
        continue;
      }
      if (decoded is! Map) continue;
      final event = _asMap(decoded);
      final seen = _usageOf(event);
      if (seen != null) usage = seen;
      final choices = event['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final choiceRaw = choices.first;
      if (choiceRaw is! Map) continue;
      final choice = _asMap(choiceRaw);
      final reason = choice['finish_reason'];
      if (reason is String && reason.isNotEmpty) finish = reason;
      final delta = choice['delta'];
      if (delta is! Map) continue;
      final piece = _asMap(delta);
      for (final text in _reasoningPieces(piece)) {
        yield LlmReasoningDelta(text);
      }
      for (final text in _textPieces(piece)) {
        yield LlmTextDelta(text);
      }
      final toolCallsRaw = piece['tool_calls'];
      if (toolCallsRaw is List && toolCallsRaw.isNotEmpty) {
        sawToolDelta = true;
        for (final item in toolCallsRaw) {
          if (item is Map) _applyToolCallDelta(_asMap(item), pending);
        }
      }
    }

    final calls = [
      for (var i = 0; i < pending.length; i++)
        if (pending[i].name.isNotEmpty)
          LlmToolCall(
            id: pending[i].id.isNotEmpty ? pending[i].id : 'call_$i',
            name: pending[i].name,
            arguments: _decodeArguments(pending[i].argumentsJson),
          ),
    ];
    if (calls.isNotEmpty || (sawToolDelta && finish == 'stop')) {
      if (calls.isNotEmpty) yield LlmToolCalls(calls);
      if (sawToolDelta && calls.isEmpty) finish = 'tool_calls';
    }
    yield LlmFinished(finishReason: finish, usage: usage);
  }

  Stream<LlmEvent> _readJson(String raw) async* {
    Map<String, Object?> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, Object?>;
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

    final piece = _asMap(message);
    for (final text in _reasoningPieces(piece)) {
      yield LlmReasoningDelta(text);
    }
    for (final text in _textPieces(piece)) {
      yield LlmTextDelta(text);
    }

    final rawCalls = message['tool_calls'];
    if (rawCalls is List && rawCalls.isNotEmpty) {
      final calls = <LlmToolCall>[];
      for (final rawCall in rawCalls) {
        if (rawCall is! Map) continue;
        final function = rawCall['function'];
        if (function is! Map) continue;
        final name = function['name'] as String? ?? '';
        if (name.isEmpty) continue;
        calls.add(
          LlmToolCall(
            id: rawCall['id'] as String? ?? 'call_${calls.length}',
            name: name,
            arguments: _decodeArguments(function['arguments']),
          ),
        );
      }
      if (calls.isNotEmpty) yield LlmToolCalls(calls);
    }

    yield LlmFinished(
      finishReason: choice['finish_reason'] as String? ?? 'stop',
      usage: _usageOf(decoded),
    );
  }

  static void _applyToolCallDelta(
    Map<String, Object?> item,
    List<_StreamingToolCall> pending,
  ) {
    final index = _toolCallIndex(item['index'], pending, item);
    while (pending.length <= index) {
      pending.add(_StreamingToolCall());
    }
    final slot = pending[index];
    final id = item['id'] as String?;
    if (id != null && id.isNotEmpty) slot.id = id;
    final function = item['function'];
    if (function is! Map) return;
    final fn = _asMap(function);
    final name = fn['name'] as String?;
    if (name != null && name.isNotEmpty) slot.name = name;
    final args = fn['arguments'];
    if (args is String) {
      slot.argumentsJson += args;
    } else if (args is Map) {
      slot.argumentsJson = jsonEncode(_asMap(args));
    }
  }

  static int _toolCallIndex(
    Object? indexRaw,
    List<_StreamingToolCall> pending,
    Map<String, Object?> item,
  ) {
    if (indexRaw is int) return indexRaw;
    if (indexRaw is num) return indexRaw.toInt();
    if (indexRaw is String) {
      final parsed = int.tryParse(indexRaw.trim());
      if (parsed != null) return parsed;
    }
    if (pending.isEmpty) return 0;
    final id = item['id'] as String?;
    final function = item['function'];
    final name = function is Map ? function['name'] as String? : null;
    final last = pending.last;
    final newId = id != null && id.isNotEmpty && id != last.id;
    final newName =
        name != null &&
        name.isNotEmpty &&
        last.name.isNotEmpty &&
        name != last.name;
    if (newId || newName) return pending.length;
    return pending.length - 1;
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

  static Map<String, Object?> _asMap(Map<dynamic, dynamic> raw) => {
    for (final entry in raw.entries) '${entry.key}': entry.value,
  };

  static LlmUsage? _usageOf(Map<String, Object?> event) {
    final raw = event['usage'];
    if (raw is! Map) return null;
    final map = _asMap(raw);
    int read(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    final prompt = read('prompt_tokens');
    final completion = read('completion_tokens');
    final total = read('total_tokens');
    if (prompt == 0 && completion == 0 && total == 0) return null;
    return LlmUsage(
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: total == 0 ? prompt + completion : total,
    );
  }

  /// Leftover DeepSeek / o-series / content-part thinking fields.
  static Iterable<String> _reasoningPieces(Map<String, Object?> piece) sync* {
    for (final key in const ['reasoning_content', 'reasoning', 'thinking']) {
      final value = piece[key];
      if (value is String && value.isNotEmpty) yield value;
    }
    final content = piece['content'];
    if (content is! List) return;
    for (final part in content) {
      if (part is! Map) continue;
      final map = _asMap(part);
      final type = '${map['type'] ?? ''}';
      if (type != 'thinking' && type != 'reasoning') continue;
      final text = map['text'] ?? map['thinking'] ?? map['reasoning'];
      if (text is String && text.isNotEmpty) yield text;
    }
  }

  static Iterable<String> _textPieces(Map<String, Object?> piece) sync* {
    final content = piece['content'];
    if (content is String && content.isNotEmpty) {
      yield content;
      return;
    }
    if (content is! List) return;
    for (final part in content) {
      if (part is! Map) continue;
      final map = _asMap(part);
      final type = '${map['type'] ?? 'text'}';
      if (type != 'text' && type != 'output_text') continue;
      final text = map['text'];
      if (text is String && text.isNotEmpty) yield text;
    }
  }

  static String _brief(String body) {
    final trimmed = body.trim();
    if (trimmed.length <= 240) return trimmed;
    return '${trimmed.substring(0, 240)}…';
  }
}

class _StreamingToolCall {
  String id = '';
  String name = '';
  String argumentsJson = '';
}
