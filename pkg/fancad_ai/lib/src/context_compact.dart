import 'dart:convert';

import 'provider.dart';

/// Compact when prompt (or an estimate) reaches this fraction of the window.
const contextCompactFraction = 0.8;

int contextCompactThresholdTokens({
  int window = LlmUsage.contextWindowTokens,
}) => (window * contextCompactFraction).floor();

/// Rough token count: four characters per token, plus tool-call JSON.
int estimateMessageTokens(LlmMessage message) {
  var chars = message.content.length;
  chars += message.name?.length ?? 0;
  chars += message.toolCallId?.length ?? 0;
  for (final call in message.toolCalls) {
    chars += call.id.length + call.name.length;
    chars += jsonEncode(call.arguments).length;
  }
  return chars ~/ 4;
}

int estimateTranscriptTokens(Iterable<LlmMessage> messages) {
  var total = 0;
  for (final message in messages) {
    total += estimateMessageTokens(message);
  }
  return total;
}

bool contextNeedsCompact({
  required List<LlmMessage> messages,
  int? lastPromptTokens,
  int window = LlmUsage.contextWindowTokens,
}) {
  final threshold = contextCompactThresholdTokens(window: window);
  if (lastPromptTokens != null && lastPromptTokens >= threshold) return true;
  return estimateTranscriptTokens(messages) >= threshold;
}

bool isContextOverflowMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('context length') ||
      lower.contains('context_length') ||
      lower.contains('too many tokens') ||
      lower.contains('maximum context');
}

bool isToolStubContent(String content) => content.startsWith('omitted:');

/// One user message and the assistant/tool rows that follow it.
List<List<LlmMessage>> splitLlmTurns(List<LlmMessage> messages) {
  final turns = <List<LlmMessage>>[];
  var current = <LlmMessage>[];
  for (final message in messages) {
    if (message.role == LlmRole.user && current.isNotEmpty) {
      turns.add(current);
      current = [message];
      continue;
    }
    current.add(message);
  }
  if (current.isNotEmpty) turns.add(current);
  return turns;
}

LlmMessage stubToolMessage(LlmMessage message) {
  if (message.role != LlmRole.tool) return message;
  if (isToolStubContent(message.content)) return message;
  final name = (message.name ?? 'tool').trim();
  final label = name.isEmpty ? 'tool' : name;
  return LlmMessage.tool(
    toolCallId: message.toolCallId ?? '',
    content: 'omitted: $label (was ${message.content.length} chars)',
    name: message.name,
  );
}

/// Keeps the last user turn intact; stubs older tool payloads.
List<LlmMessage> stubOldToolResults(List<LlmMessage> messages) {
  final turns = splitLlmTurns(messages);
  if (turns.length <= 1) return List<LlmMessage>.of(messages);
  final prefix = [
    for (final turn in turns.take(turns.length - 1))
      for (final message in turn) stubToolMessage(message),
  ];
  return [...prefix, ...turns.last];
}

String compactSummarySource(List<LlmMessage> prefix) {
  final buffer = StringBuffer();
  for (final message in prefix) {
    switch (message.role) {
      case LlmRole.user:
        buffer.writeln('User: ${message.content}');
      case LlmRole.assistant:
        buffer.writeln('Assistant: ${message.content}');
        for (final call in message.toolCalls) {
          buffer.writeln('  tool: ${call.name}');
        }
      case LlmRole.tool:
        final name = message.name ?? 'tool';
        buffer.writeln('Tool $name: ${message.content}');
      case LlmRole.system:
        break;
    }
  }
  return buffer.toString().trim();
}

const compactSummarySystemPrompt =
    'Summarize the prior CAD chat for the next turn. Keep drawing tab ids, '
    'entity ids, and edits already made. Do not repeat tool JSON.';

/// Shrinks [messages] when the window is full. Does not touch a UI transcript.
Future<List<LlmMessage>> compactLlmMessages({
  required List<LlmMessage> messages,
  LlmMessage? system,
  int? lastPromptTokens,
  int window = LlmUsage.contextWindowTokens,
  Future<String?> Function(String source)? summarize,
  bool force = false,
}) async {
  final forTrigger = [?system, ...messages];
  if (!force &&
      !contextNeedsCompact(
        messages: forTrigger,
        lastPromptTokens: lastPromptTokens,
        window: window,
      )) {
    return messages;
  }
  final stubbed = stubOldToolResults(messages);
  final threshold = contextCompactThresholdTokens(window: window);
  if (estimateTranscriptTokens(stubbed) < threshold || summarize == null) {
    return stubbed;
  }
  final turns = splitLlmTurns(stubbed);
  if (turns.length <= 1) return stubbed;
  final prefix = [for (final turn in turns.take(turns.length - 1)) ...turn];
  final source = compactSummarySource(prefix);
  if (source.isEmpty) return stubbed;
  final summary = await summarize(source);
  final trimmed = summary?.trim() ?? '';
  if (trimmed.isEmpty) return stubbed;
  return [
    LlmMessage.user('Prior conversation summary:\n$trimmed'),
    ...turns.last,
  ];
}
