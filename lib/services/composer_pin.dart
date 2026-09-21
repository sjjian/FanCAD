import 'package:fancad_core/fancad_core.dart';

/// A target the user pinned onto the next assistant message.
class ComposerPin {
  const ComposerPin._({
    required this.kind,
    this.ids = const [],
    this.tabId = '',
    this.tabTitle = '',
    this.path,
    this.label = '',
  });

  factory ComposerPin.entities(
    List<int> ids, {
    required String tabId,
    String tabTitle = '',
    String? path,
    String label = '',
  }) => ComposerPin._(
    kind: ComposerPinKind.entity,
    ids: List.unmodifiable(ids),
    tabId: tabId,
    tabTitle: tabTitle,
    path: path,
    label: label,
  );

  factory ComposerPin.drawing({
    required String tabId,
    String tabTitle = '',
    String? path,
  }) => ComposerPin._(
    kind: ComposerPinKind.drawing,
    tabId: tabId,
    tabTitle: tabTitle,
    path: path,
    label: tabTitle,
  );

  final ComposerPinKind kind;
  final List<int> ids;

  /// [DocumentSession.id] from `file.list`.
  final String tabId;
  final String tabTitle;
  final String? path;
  final String label;

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

enum ComposerPinKind { entity, drawing }

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

String flattenComposerPins(List<ComposerPin> pins, String text) {
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

String formatComposerPin(ComposerPin pin) {
  switch (pin.kind) {
    case ComposerPinKind.entity:
      final ids = pin.ids.take(composerPinIdCap).join(',');
      return '@objects[tab=${pin.tabId} ids=$ids]';
    case ComposerPinKind.drawing:
      return '@drawing[tab=${pin.tabId}]';
  }
}

ComposerPin? parseComposerPin(String raw) {
  final match = _composerPinTagPattern.matchAsPrefix(raw.trim());
  if (match == null || match.end != raw.trim().length) return null;
  return _pinFromMatch(match);
}

List<ComposerPin> parseComposerPins(String text) {
  final pins = <ComposerPin>[];
  for (final match in _composerPinTagPattern.allMatches(text)) {
    final pin = _pinFromMatch(match);
    if (pin != null) pins.add(pin);
  }
  return pins;
}

/// Alternating plain text and pin tags, for chip rendering.
List<ComposerPinSpan> splitComposerPinSpans(String text) {
  final spans = <ComposerPinSpan>[];
  var start = 0;
  for (final match in _composerPinTagPattern.allMatches(text)) {
    if (match.start > start) {
      spans.add(ComposerPinSpan.text(text.substring(start, match.start)));
    }
    final pin = _pinFromMatch(match);
    if (pin != null) {
      spans.add(ComposerPinSpan.pin(pin));
    } else {
      spans.add(ComposerPinSpan.text(match[0]!));
    }
    start = match.end;
  }
  if (start < text.length) {
    spans.add(ComposerPinSpan.text(text.substring(start)));
  }
  return spans;
}

bool composerPinTextHasTags(String text) =>
    _composerPinTagPattern.hasMatch(text);

ComposerPin? _pinFromMatch(Match match) {
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
    return ComposerPin.entities(ids, tabId: objectTab);
  }
  final drawingTab = match[3];
  if (drawingTab == null || drawingTab.isEmpty) return null;
  return ComposerPin.drawing(tabId: drawingTab);
}

class ComposerPinSpan {
  const ComposerPinSpan._({this.text, this.pin});

  factory ComposerPinSpan.text(String text) => ComposerPinSpan._(text: text);

  factory ComposerPinSpan.pin(ComposerPin pin) => ComposerPinSpan._(pin: pin);

  final String? text;
  final ComposerPin? pin;
}

void _writePinLines(StringBuffer buffer, List<ComposerPin> pins) {
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

void _writePinNotes(StringBuffer buffer, List<ComposerPin> pins) {
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
class ComposerAtMention {
  const ComposerAtMention({
    required this.start,
    required this.end,
    required this.query,
  });

  /// Index of the `@`.
  final int start;

  /// Cursor, exclusive end of the query.
  final int end;
  final String query;
}

/// A standalone `@` at [cursor]: line start or after whitespace.
ComposerAtMention? composerAtMentionAt(String text, int cursor) {
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
  return ComposerAtMention(
    start: i,
    end: cursor,
    query: text.substring(i + 1, cursor),
  );
}

List<Map<String, Object?>> filterDrawingMentions(
  List<Map<String, Object?>> drawings,
  String query,
) {
  final q = query.trim().toLowerCase();
  final matched = [
    for (final drawing in drawings)
      if (q.isEmpty || _drawingMentionHaystack(drawing).contains(q)) drawing,
  ];
  if (matched.length <= composerMentionLimit) return matched;
  return matched.take(composerMentionLimit).toList();
}

String _drawingMentionHaystack(Map<String, Object?> drawing) {
  final title = '${drawing['title'] ?? ''}'.toLowerCase();
  final path = '${drawing['path'] ?? ''}'.toLowerCase();
  return '$title $path';
}
