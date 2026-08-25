import 'package:meta/meta.dart';

/// A message in an LLM conversation.
@immutable
class LlmMessage {
  const LlmMessage({
    required this.role,
    this.content = '',
    this.toolCalls = const [],
    this.toolCallId,
    this.name,
  });

  const LlmMessage.system(this.content)
    : role = LlmRole.system,
      toolCalls = const [],
      toolCallId = null,
      name = null;

  const LlmMessage.user(this.content)
    : role = LlmRole.user,
      toolCalls = const [],
      toolCallId = null,
      name = null;

  const LlmMessage.assistant(this.content, {this.toolCalls = const []})
    : role = LlmRole.assistant,
      toolCallId = null,
      name = null;

  const LlmMessage.tool({
    required this.toolCallId,
    required this.content,
    this.name,
  }) : role = LlmRole.tool,
       toolCalls = const [];

  final LlmRole role;
  final String content;
  final List<LlmToolCall> toolCalls;
  final String? toolCallId;
  final String? name;

  Map<String, Object?> toJson() => {
    'role': role.name,
    if (content.isNotEmpty) 'content': content,
    if (toolCalls.isNotEmpty)
      'tool_calls': [for (final call in toolCalls) call.toJson()],
    if (toolCallId != null) 'tool_call_id': toolCallId,
    if (name != null) 'name': name,
  };

  factory LlmMessage.fromJson(Map<dynamic, dynamic> raw) {
    final roleName = '${raw['role'] ?? 'user'}';
    final role = LlmRole.values.firstWhere(
      (item) => item.name == roleName,
      orElse: () => LlmRole.user,
    );
    final calls = <LlmToolCall>[];
    final rawCalls = raw['tool_calls'];
    if (rawCalls is List) {
      for (final item in rawCalls) {
        if (item is Map) calls.add(LlmToolCall.fromJson(item));
      }
    }
    final content = raw['content'];
    return LlmMessage(
      role: role,
      content: content is String ? content : '',
      toolCalls: calls,
      toolCallId: raw['tool_call_id'] is String
          ? raw['tool_call_id'] as String
          : null,
      name: raw['name'] is String ? raw['name'] as String : null,
    );
  }
}

enum LlmRole { system, user, assistant, tool }

/// A function the model asked to call.
@immutable
class LlmToolCall {
  const LlmToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': arguments},
  };

  factory LlmToolCall.fromJson(Map<dynamic, dynamic> raw) {
    final function = raw['function'];
    final fromFn = function is Map;
    final name = fromFn
        ? '${function['name'] ?? ''}'
        : '${raw['name'] ?? ''}';
    final args = fromFn ? function['arguments'] : raw['arguments'];
    return LlmToolCall(
      id: '${raw['id'] ?? ''}',
      name: name,
      arguments: _argumentsFromJson(args),
    );
  }
}

Map<String, Object?> _argumentsFromJson(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  if (raw is Map) {
    return {for (final entry in raw.entries) '${entry.key}': entry.value};
  }
  return {};
}

/// A tool advertised to the model, usually generated from a command.
@immutable
class LlmTool {
  const LlmTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

/// One request to a language model.
@immutable
class LlmRequest {
  const LlmRequest({
    required this.messages,
    this.tools = const [],
    this.model,
    this.temperature,
    this.maxTokens,
    this.stream = true,
  });

  final List<LlmMessage> messages;
  final List<LlmTool> tools;
  final String? model;
  final double? temperature;
  final int? maxTokens;

  /// When true the provider should push [LlmTextDelta]s as tokens arrive.
  /// [LlmProvider.completeOnce] always turns this off so a retry is one shot.
  final bool stream;

  LlmRequest copyWith({bool? stream}) => LlmRequest(
    messages: messages,
    tools: tools,
    model: model,
    temperature: temperature,
    maxTokens: maxTokens,
    stream: stream ?? this.stream,
  );
}

/// Incremental events from a completion.
sealed class LlmEvent {
  const LlmEvent();
}

final class LlmTextDelta extends LlmEvent {
  const LlmTextDelta(this.text);
  final String text;
}

/// Chain-of-thought tokens. Visible in the pane, never sent back to the model.
final class LlmReasoningDelta extends LlmEvent {
  const LlmReasoningDelta(this.text);
  final String text;
}

final class LlmToolCalls extends LlmEvent {
  const LlmToolCalls(this.calls);
  final List<LlmToolCall> calls;
}

final class LlmFinished extends LlmEvent {
  const LlmFinished({this.finishReason = 'stop', this.usage});
  final String finishReason;
  final LlmUsage? usage;
}

final class LlmError extends LlmEvent {
  const LlmError(this.message);
  final String message;
}

/// Prompt / completion counts from a leftover `usage` object.
@immutable
class LlmUsage {
  const LlmUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  /// Default context window when the endpoint does not advertise one.
  static const int contextWindowTokens = 128000;
}

/// The assembled result of one completion.
@immutable
class LlmCompletion {
  const LlmCompletion({
    this.text = '',
    this.toolCalls = const [],
    this.finishReason = 'stop',
    this.usage,
  });

  final String text;
  final List<LlmToolCall> toolCalls;
  final String finishReason;
  final LlmUsage? usage;

  bool get wantsTools => toolCalls.isNotEmpty;
}

/// Talks to a language model.
///
/// Implementations are interchangeable: OpenAI-compatible HTTP, a local
/// endpoint, or a scripted stand-in for tests. The agent loop never knows
/// which one it is talking to.
abstract class LlmProvider {
  String get name;

  /// Completes [request], yielding text deltas and then either tool calls or
  /// a finished event. A provider that cannot stream still yields one text
  /// delta with the whole reply.
  Stream<LlmEvent> complete(LlmRequest request);

  /// A single-shot helper for callers that do not want to stream.
  Future<LlmCompletion> completeOnce(LlmRequest request) async {
    final buffer = StringBuffer();
    var collected = const <LlmToolCall>[];
    var finish = 'stop';
    LlmUsage? usage;
    await for (final event in complete(request.copyWith(stream: false))) {
      switch (event) {
        case LlmTextDelta(:final text):
          buffer.write(text);
        case LlmReasoningDelta():
          break;
        case LlmToolCalls(:final calls):
          collected = calls;
        case LlmFinished(:final finishReason, usage: final seen):
          finish = finishReason;
          if (seen != null) usage = seen;
        case LlmError(:final message):
          throw LlmException(message);
      }
    }
    return LlmCompletion(
      text: buffer.toString(),
      toolCalls: collected,
      finishReason: finish,
      usage: usage,
    );
  }
}

/// A provider failed in a way the agent should report, not crash over.
class LlmException implements Exception {
  const LlmException(this.message);
  final String message;

  @override
  String toString() => 'LlmException: $message';
}
