import 'dart:convert';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:meta/meta.dart';

/// A command-line style reading of one tool result.
///
/// The model still receives the raw JSON. This is only what the panel shows.
@immutable
class AssistantReceipt {
  const AssistantReceipt({
    required this.verb,
    required this.summary,
    required this.status,
    required this.raw,
    this.toolName,
    this.isError = false,
    this.count = 1,
  });

  final String verb;
  final String summary;
  final String status;
  final String raw;
  final String? toolName;
  final bool isError;
  final int count;

  bool get isOk => status == 'ok';

  AssistantReceipt merge(AssistantReceipt other) => AssistantReceipt(
    verb: verb,
    summary: summary,
    status: status,
    raw: raw,
    toolName: toolName,
    isError: isError,
    count: count + other.count,
  );

  String get headline {
    final name = count > 1 ? '$verb ×$count' : verb;
    if (summary.isEmpty) return name;
    return '$name  $summary';
  }
}

/// Last segment of `draw_ellipse` / `draw.ellipse` → `ELLIPSE`.
String assistantCommandVerb(String? toolName) {
  if (toolName == null || toolName.trim().isEmpty) return 'TOOL';
  final parts = toolName
      .split(RegExp(r'[_.]'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return toolName.toUpperCase();
  return parts.last.toUpperCase();
}

/// Parses a visible tool message leftover-safely.
///
/// A leftover that is not a [CommandResult] map must not dump JSON into the
/// main row. Expand-to-raw is the only place that string still appears.
AssistantReceipt parseAssistantReceipt(ChatMessage message) {
  final raw = message.text;
  final verb = assistantCommandVerb(message.toolName);
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    decoded = null;
  }
  if (decoded is Map) {
    final status = decoded['status'];
    final known = status == 'ok' || status == 'cancelled' || status == 'failed';
    if (known) {
      var summary = '';
      final change = decoded['change'];
      if (change is Map && change['summary'] is String) {
        summary = change['summary'] as String;
      } else if (decoded['message'] is String) {
        summary = decoded['message'] as String;
      } else if (decoded['error'] is String) {
        summary = decoded['error'] as String;
      }
      return AssistantReceipt(
        verb: verb,
        summary: summary,
        status: status as String,
        raw: raw,
        toolName: message.toolName,
        isError: message.isError || status != 'ok',
      );
    }
    return AssistantReceipt(
      verb: verb,
      summary: 'result',
      status: message.isError ? 'failed' : 'unknown',
      raw: raw,
      toolName: message.toolName,
      isError: message.isError,
    );
  }
  final trimmed = raw.trim();
  final looksLikeJson = trimmed.startsWith('{') || trimmed.startsWith('[');
  final summary = !looksLikeJson && trimmed.length <= 80 && trimmed.isNotEmpty
      ? trimmed
      : 'result';
  return AssistantReceipt(
    verb: verb,
    summary: summary,
    status: message.isError ? 'failed' : 'unknown',
    raw: raw,
    toolName: message.toolName,
    isError: message.isError,
  );
}

/// One row in the assistant history list.
@immutable
class AssistantLogEntry {
  const AssistantLogEntry._({required this.role, this.message, this.receipt});

  factory AssistantLogEntry.message(ChatMessage message) =>
      AssistantLogEntry._(role: message.role, message: message);

  factory AssistantLogEntry.receipt(AssistantReceipt receipt) =>
      AssistantLogEntry._(role: ChatRole.tool, receipt: receipt);

  final ChatRole role;
  final ChatMessage? message;
  final AssistantReceipt? receipt;

  bool canMerge(AssistantReceipt next) {
    final current = receipt;
    if (current == null || role != ChatRole.tool) return false;
    if (current.toolName == null || current.toolName != next.toolName) {
      return false;
    }
    if (current.isOk && next.isOk) return true;
    return current.status == 'cancelled' && next.status == 'cancelled';
  }
}

/// A leftover tool-only or still-waiting turn must still show life in the pane.
bool assistantPanelShowsWorking({
  required bool busy,
  required List<ChatMessage> messages,
}) {
  if (!busy) return false;
  if (messages.isEmpty) return true;
  final last = messages.last;
  if (last.text.trim().isEmpty) return true;
  return last.role != ChatRole.assistant && last.role != ChatRole.reasoning;
}

/// Streamed assistant text gets a caret only while tokens are still arriving.
bool assistantPanelShowsCaret({
  required bool busy,
  required List<ChatMessage> messages,
}) {
  if (!busy || messages.isEmpty) return false;
  final last = messages.last;
  return last.role == ChatRole.assistant && last.text.trim().isNotEmpty;
}

/// Collapses consecutive successful calls of the same tool into `VERB ×N`.
List<AssistantLogEntry> groupAssistantLog(List<ChatMessage> messages) {
  final entries = <AssistantLogEntry>[];
  for (final message in messages) {
    if (message.role != ChatRole.tool) {
      entries.add(AssistantLogEntry.message(message));
      continue;
    }
    final receipt = parseAssistantReceipt(message);
    if (entries.isNotEmpty && entries.last.canMerge(receipt)) {
      final last = entries.removeLast();
      entries.add(AssistantLogEntry.receipt(last.receipt!.merge(receipt)));
    } else {
      entries.add(AssistantLogEntry.receipt(receipt));
    }
  }
  return entries;
}
