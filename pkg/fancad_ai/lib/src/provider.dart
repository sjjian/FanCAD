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
  });

  final List<LlmMessage> messages;
  final List<LlmTool> tools;
  final String? model;
  final double? temperature;
  final int? maxTokens;
}

/// Incremental events from a completion.
sealed class LlmEvent {
  const LlmEvent();
}

final class LlmTextDelta extends LlmEvent {
  const LlmTextDelta(this.text);
  final String text;
}

final class LlmToolCalls extends LlmEvent {
  const LlmToolCalls(this.calls);
  final List<LlmToolCall> calls;
}

final class LlmFinished extends LlmEvent {
  const LlmFinished({this.finishReason = 'stop'});
  final String finishReason;
}

final class LlmError extends LlmEvent {
  const LlmError(this.message);
  final String message;
}

/// The assembled result of one completion.
@immutable
class LlmCompletion {
  const LlmCompletion({
    this.text = '',
    this.toolCalls = const [],
    this.finishReason = 'stop',
  });

  final String text;
  final List<LlmToolCall> toolCalls;
  final String finishReason;

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
    await for (final event in complete(request)) {
      switch (event) {
        case LlmTextDelta(:final text):
          buffer.write(text);
        case LlmToolCalls(:final calls):
          collected = calls;
        case LlmFinished(:final finishReason):
          finish = finishReason;
        case LlmError(:final message):
          throw LlmException(message);
      }
    }
    return LlmCompletion(
      text: buffer.toString(),
      toolCalls: collected,
      finishReason: finish,
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
