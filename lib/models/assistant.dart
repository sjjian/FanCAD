// ignore_for_file: invalid_annotation_target

import 'dart:convert';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant.freezed.dart';
part 'assistant.g.dart';

/// Default and permitted width of the docked assistant pane.
abstract final class AssistantPaneLayout {
  static const double defaultWidth = 320;
  static const double minWidth = 180;
  static const double maxWidth = 560;
}

/// The assistant chat, docked on the right so it can stay open next to Layers.
@freezed
abstract class AssistantPaneModel with _$AssistantPaneModel {
  const factory AssistantPaneModel({
    @Default(false) bool isOpen,
    @Default(AssistantPaneLayout.defaultWidth) double width,
  }) = _AssistantPaneModel;
}

/// Application-layer store of the assistant: chats, composer pins,
/// the docked pane, and the in-flight approval / question cards.
@freezed
abstract class AssistantModel with _$AssistantModel {
  const AssistantModel._();

  const factory AssistantModel({
    @Default([]) List<AssistantChatModel> chats,
    @Default(AssistantChatModel.defaultId) String activeChatId,
    @Default([]) List<ComposerPinModel> pins,
    String? error,
    PendingChangeSet? approval,
    SessionQuestion? question,
    @Default(false) bool busy,
    @Default(0) int transcriptEpoch,
    @Default(AssistantPaneModel()) AssistantPaneModel pane,
  }) = _AssistantModel;

  AssistantChatModel get activeChat {
    for (final chat in chats) {
      if (chat.id == activeChatId) return chat;
    }
    return chats.first;
  }
}

/// One assistant thread. The pane shows [conversation]; leftover chats
/// are stored so a new session does not wipe the last one.
@Freezed(fromJson: false, toJson: false)
abstract class AssistantChatModel with _$AssistantChatModel {
  const AssistantChatModel._();

  @JsonSerializable(createFactory: false, ignoreUnannotated: true)
  const factory AssistantChatModel.raw({
    @JsonKey() required String id,
    @JsonKey() @Default('') String title,
    @JsonKey() required DateTime updatedAt,
    @JsonKey(includeToJson: false, includeFromJson: false)
    required Conversation conversation,
    @JsonKey(includeToJson: false, includeFromJson: false) LlmUsage? usage,
    @JsonKey() @Default('') String draft,
  }) = _AssistantChatModel;

  factory AssistantChatModel({
    required String id,
    String title = '',
    DateTime? updatedAt,
    Conversation? conversation,
    LlmUsage? usage,
    String draft = '',
  }) {
    return AssistantChatModel.raw(
      id: id,
      title: title,
      updatedAt: updatedAt ?? DateTime.now(),
      conversation: conversation ?? Conversation(),
      usage: usage,
      draft: draft,
    );
  }

  static const String defaultId = 'default';

  bool get isEmpty =>
      conversation.visible.isEmpty && conversation.llmMessages.isEmpty;

  String displayTitle(String emptyLabel) {
    final named = title.trim();
    if (named.isNotEmpty) return named;
    for (final item in conversation.visible) {
      if (item.role != ChatRole.user) continue;
      return titleFromUserMessage(item.text);
    }
    return emptyLabel;
  }

  Map<String, Object?> toJson() => {
    ..._$AssistantChatModelToJson(this as _AssistantChatModel),
    ...conversation.toJson(),
  };

  factory AssistantChatModel.fromJson(Map<dynamic, dynamic> raw) {
    final id = raw['id'] is String ? raw['id'] as String : defaultId;
    final updated = raw['updatedAt'] is String
        ? DateTime.tryParse(raw['updatedAt'] as String)
        : null;
    return AssistantChatModel(
      id: id.trim().isEmpty ? defaultId : id,
      title: raw['title'] is String ? raw['title'] as String : '',
      updatedAt: updated,
      conversation: Conversation.fromJson(raw),
      draft: raw['draft'] is String ? raw['draft'] as String : '',
    );
  }
}

String titleFromUserMessage(String text) {
  final first = text.trim().split('\n').first.trim();
  if (first.isEmpty) return '';
  if (first.length <= 40) return first;
  return '${first.substring(0, 39)}…';
}

/// Compact token label for the composer ring, leftover `12400` → `12.4k`.
String formatAssistantTokens(int tokens) {
  if (tokens < 1000) return '$tokens';
  final tenths = (tokens / 100).round() / 10;
  if (tenths >= 100 || tenths == tenths.roundToDouble()) {
    return '${tenths.round()}k';
  }
  return '${tenths}k';
}

/// A command-line style reading of one tool result.
///
/// The model still receives the raw JSON. This is only what the panel shows.
@freezed
abstract class AssistantReceiptModel with _$AssistantReceiptModel {
  const AssistantReceiptModel._();

  const factory AssistantReceiptModel({
    required String verb,
    required String summary,
    required String status,
    required String raw,
    String? toolName,
    @Default(false) bool isError,
    @Default(1) int count,
  }) = _AssistantReceiptModel;

  bool get isOk => status == 'ok';

  AssistantReceiptModel merge(AssistantReceiptModel other) =>
      copyWith(count: count + other.count);

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
AssistantReceiptModel parseAssistantReceipt(ChatMessage message) {
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
      return AssistantReceiptModel(
        verb: verb,
        summary: summary,
        status: status as String,
        raw: raw,
        toolName: message.toolName,
        isError: message.isError || status != 'ok',
      );
    }
    return AssistantReceiptModel(
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
  return AssistantReceiptModel(
    verb: verb,
    summary: summary,
    status: message.isError ? 'failed' : 'unknown',
    raw: raw,
    toolName: message.toolName,
    isError: message.isError,
  );
}

/// One row in the assistant history list.
@freezed
sealed class AssistantLogEntryModel with _$AssistantLogEntryModel {
  const AssistantLogEntryModel._();

  const factory AssistantLogEntryModel.message(ChatMessage message) =
      AssistantLogMessageModel;
  const factory AssistantLogEntryModel.receipt(AssistantReceiptModel receipt) =
      AssistantLogReceiptModel;

  bool canMerge(AssistantReceiptModel next) {
    return switch (this) {
      AssistantLogReceiptModel(:final receipt) =>
        receipt.toolName != null &&
            receipt.toolName == next.toolName &&
            ((receipt.isOk && next.isOk) ||
                (receipt.status == 'cancelled' && next.status == 'cancelled')),
      AssistantLogMessageModel() => false,
    };
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
List<AssistantLogEntryModel> groupAssistantLog(List<ChatMessage> messages) {
  final entries = <AssistantLogEntryModel>[];
  for (final message in messages) {
    if (message.role != ChatRole.tool) {
      entries.add(AssistantLogEntryModel.message(message));
      continue;
    }
    final receipt = parseAssistantReceipt(message);
    final last = entries.isEmpty ? null : entries.last;
    if (last is AssistantLogReceiptModel && last.canMerge(receipt)) {
      entries.removeLast();
      entries.add(AssistantLogEntryModel.receipt(last.receipt.merge(receipt)));
    } else {
      entries.add(AssistantLogEntryModel.receipt(receipt));
    }
  }
  return entries;
}

/// Entity ids a leftover receipt can flash or pin.
List<int> assistantReceiptEntityIds(AssistantReceiptModel receipt) {
  Object? decoded;
  try {
    decoded = jsonDecode(receipt.raw);
  } catch (_) {
    return const [];
  }
  if (decoded is! Map) return const [];
  final ids = <int>{};
  final change = decoded['change'];
  if (change is Map) {
    _collectReceiptIds(change['added'], ids);
    _collectReceiptIds(change['modified'], ids);
    _collectReceiptIds(change['removed'], ids);
  }
  final data = decoded['data'];
  if (data is Map) {
    _collectReceiptIds(data['ids'], ids);
  }
  _collectReceiptIds(decoded['ids'], ids);
  return ids.toList();
}

void _collectReceiptIds(Object? value, Set<int> into) {
  if (value is int) {
    into.add(value);
  } else if (value is num) {
    into.add(value.toInt());
  } else if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) into.add(parsed);
  } else if (value is List) {
    for (final item in value) {
      _collectReceiptIds(item, into);
    }
  }
}

enum ComposerPinKind { entity, drawing }

/// A target the user pinned onto the next assistant message.
@freezed
abstract class ComposerPinModel with _$ComposerPinModel {
  const ComposerPinModel._();

  const factory ComposerPinModel({
    required ComposerPinKind kind,
    @Default([]) List<int> ids,
    @Default('') String tabId,
    @Default('') String tabTitle,
    String? path,
    @Default('') String label,
  }) = _ComposerPinModel;

  factory ComposerPinModel.entities(
    List<int> ids, {
    required String tabId,
    String tabTitle = '',
    String? path,
    String label = '',
  }) => ComposerPinModel(
    kind: ComposerPinKind.entity,
    ids: List.unmodifiable(ids),
    tabId: tabId,
    tabTitle: tabTitle,
    path: path,
    label: label,
  );

  factory ComposerPinModel.drawing({
    required String tabId,
    String tabTitle = '',
    String? path,
  }) => ComposerPinModel(
    kind: ComposerPinKind.drawing,
    tabId: tabId,
    tabTitle: tabTitle,
    path: path,
    label: tabTitle,
  );

  String get drawingName {
    final titled = tabTitle.trim();
    if (titled.isNotEmpty) return titled;
    return tabId;
  }

  String describe() {
    switch (kind) {
      case ComposerPinKind.entity:
        final shown = ids.take(8).map((id) => '#$id').join(', ');
        final extra = ids.length > 8 ? ' +${ids.length - 8}' : '';
        final named = label.trim();
        final objects = named.isEmpty
            ? 'entities $shown$extra'
            : '$named $shown$extra';
        return '$objects on $drawingName (tab=$tabId)';
      case ComposerPinKind.drawing:
        return 'drawing $drawingName (tab=$tabId)';
    }
  }
}

/// Object-replacement character: one slot in the composer text per pin.
const composerMentionToken = '\uFFFC';

/// Hard cap on entity ids pinned onto one message.
const composerPinIdCap = 200;

/// How many open drawings the `@` picker lists at once.
const composerMentionLimit = 8;

int composerMentionTokenCount(String text) {
  var count = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0xFFFC) count++;
  }
  return count;
}

List<int> composerMentionTokenIndexes(String text) {
  return [
    for (var i = 0; i < text.length; i++)
      if (text.codeUnitAt(i) == 0xFFFC) i,
  ];
}

/// Pin indexes whose mention token disappeared between [before] and [after].
List<int> deletedMentionIndexes(String before, String after) {
  final oldTokens = composerMentionTokenIndexes(before);
  if (composerMentionTokenCount(after) >= oldTokens.length) {
    return const [];
  }
  var prefix = 0;
  final shared = before.length < after.length ? before.length : after.length;
  while (prefix < shared && before[prefix] == after[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < before.length - prefix &&
      suffix < after.length - prefix &&
      before[before.length - 1 - suffix] == after[after.length - 1 - suffix]) {
    suffix++;
  }
  final deletedEnd = before.length - suffix;
  return [
    for (var i = 0; i < oldTokens.length; i++)
      if (oldTokens[i] >= prefix && oldTokens[i] < deletedEnd) i,
  ];
}

String flattenComposerPins(List<ComposerPinModel> pins, String text) {
  if (pins.isEmpty) return text;
  final tokenCount = composerMentionTokenCount(text);
  if (tokenCount > 0) {
    final buffer = StringBuffer();
    var pinIndex = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0xFFFC) {
        if (pinIndex < pins.length) {
          buffer.write(formatComposerPin(pins[pinIndex]));
          pinIndex++;
        }
        continue;
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
  final buffer = StringBuffer();
  buffer.writeln('Pinned:');
  _writePinLines(buffer, pins);
  _writePinNotes(buffer, pins);
  final body = text.trim();
  if (body.isNotEmpty) {
    buffer.writeln();
    buffer.write(body);
  }
  return buffer.toString();
}

/// Wire form the model copies in replies and ask options.
///
/// `@objects[tab=<id> ids=1,2,3]` and `@drawing[tab=<id>]`.
final _composerPinTagPattern = RegExp(
  r'@objects\[tab=([^\s\]]+)\s+ids=(\d+(?:\s*,\s*\d+)*)\]'
  r'|@drawing\[tab=([^\s\]]+)\]',
);

String formatComposerPin(ComposerPinModel pin) {
  switch (pin.kind) {
    case ComposerPinKind.entity:
      final ids = pin.ids.take(composerPinIdCap).join(',');
      return '@objects[tab=${pin.tabId} ids=$ids]';
    case ComposerPinKind.drawing:
      return '@drawing[tab=${pin.tabId}]';
  }
}

ComposerPinModel? parseComposerPin(String raw) {
  final match = _composerPinTagPattern.matchAsPrefix(raw.trim());
  if (match == null || match.end != raw.trim().length) return null;
  return _pinFromMatch(match);
}

List<ComposerPinModel> parseComposerPins(String text) {
  final pins = <ComposerPinModel>[];
  for (final match in _composerPinTagPattern.allMatches(text)) {
    final pin = _pinFromMatch(match);
    if (pin != null) pins.add(pin);
  }
  return pins;
}

/// Alternating plain text and pin tags, for chip rendering.
List<ComposerPinSpanModel> splitComposerPinSpans(String text) {
  final spans = <ComposerPinSpanModel>[];
  var start = 0;
  for (final match in _composerPinTagPattern.allMatches(text)) {
    if (match.start > start) {
      spans.add(ComposerPinSpanModel.text(text.substring(start, match.start)));
    }
    final pin = _pinFromMatch(match);
    if (pin != null) {
      spans.add(ComposerPinSpanModel.pin(pin));
    } else {
      spans.add(ComposerPinSpanModel.text(match[0]!));
    }
    start = match.end;
  }
  if (start < text.length) {
    spans.add(ComposerPinSpanModel.text(text.substring(start)));
  }
  return spans;
}

bool composerPinTextHasTags(String text) =>
    _composerPinTagPattern.hasMatch(text);

ComposerPinModel? _pinFromMatch(Match match) {
  final objectTab = match[1];
  final idsRaw = match[2];
  if (objectTab != null && idsRaw != null) {
    final ids = <int>[];
    for (final part in idsRaw.split(',')) {
      final id = int.tryParse(part.trim());
      if (id == null) continue;
      ids.add(id);
      if (ids.length >= composerPinIdCap) break;
    }
    if (ids.isEmpty) return null;
    return ComposerPinModel.entities(ids, tabId: objectTab);
  }
  final drawingTab = match[3];
  if (drawingTab == null || drawingTab.isEmpty) return null;
  return ComposerPinModel.drawing(tabId: drawingTab);
}

/// One run of prose or a pin chip inside composer / transcript text.
@freezed
sealed class ComposerPinSpanModel with _$ComposerPinSpanModel {
  const factory ComposerPinSpanModel.text(String text) = ComposerPinTextModel;
  const factory ComposerPinSpanModel.pin(ComposerPinModel pin) =
      ComposerPinChipModel;
}

void _writePinLines(StringBuffer buffer, List<ComposerPinModel> pins) {
  for (final pin in pins) {
    buffer.writeln('- ${pin.describe()}');
    if (pin.kind == ComposerPinKind.entity && pin.ids.isNotEmpty) {
      buffer.writeln('  ids: ${pin.ids.join(', ')}');
      buffer.writeln('  tab: ${pin.tabId}');
      final path = pin.path?.trim() ?? '';
      if (path.isNotEmpty) buffer.writeln('  path: $path');
    }
    if (pin.kind == ComposerPinKind.drawing && pin.tabId.isNotEmpty) {
      buffer.writeln('  tab: ${pin.tabId}');
      final path = pin.path?.trim() ?? '';
      if (path.isNotEmpty) buffer.writeln('  path: $path');
    }
  }
}

void _writePinNotes(StringBuffer buffer, List<ComposerPinModel> pins) {
  final hasDrawings = pins.any((pin) => pin.kind == ComposerPinKind.drawing);
  final hasEntities = pins.any(
    (pin) => pin.kind == ComposerPinKind.entity && pin.ids.isNotEmpty,
  );
  if (hasDrawings) {
    buffer.writeln(
      'Query this drawing with tab=<id> on every fancad run. '
      'Do not dump every entity.',
    );
  }
  if (hasEntities) {
    buffer.writeln(
      'These ids belong only to that tab. Pass tab=<id> on every '
      'fancad run that uses them. Do not apply them to another drawing '
      'or the leftover selection.',
    );
  }
}

List<int> entityIdsStillInDocument(CadDocument document, Iterable<int> ids) {
  return [
    for (final id in ids)
      if (document.entity(id) != null) id,
  ];
}

/// An `@` token at [cursor] that can open the drawing-tab picker.
@freezed
abstract class ComposerAtMentionModel with _$ComposerAtMentionModel {
  const factory ComposerAtMentionModel({
    /// Index of the `@`.
    required int start,

    /// Cursor, exclusive end of the query.
    required int end,
    required String query,
  }) = _ComposerAtMentionModel;
}

/// A standalone `@` at [cursor]: line start or after whitespace.
ComposerAtMentionModel? composerAtMentionAt(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  var i = cursor - 1;
  while (i >= 0) {
    final ch = text[i];
    if (ch == '@') break;
    if (ch.trim().isEmpty) return null;
    i--;
  }
  if (i < 0 || text[i] != '@') return null;
  if (i > 0 && text[i - 1].trim().isNotEmpty) return null;
  return ComposerAtMentionModel(
    start: i,
    end: cursor,
    query: text.substring(i + 1, cursor),
  );
}

List<DocumentSession> filterDrawingMentions(
  List<DocumentSession> sessions,
  String query,
) {
  final q = query.trim().toLowerCase();
  final matched = [
    for (final session in sessions)
      if (q.isEmpty || _drawingMentionHaystack(session).contains(q)) session,
  ];
  if (matched.length <= composerMentionLimit) return matched;
  return matched.take(composerMentionLimit).toList();
}

String _drawingMentionHaystack(DocumentSession session) {
  final title = session.title.toLowerCase();
  final path = (session.filePath ?? '').toLowerCase();
  return '$title $path';
}
