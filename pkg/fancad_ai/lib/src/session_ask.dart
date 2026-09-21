import 'package:meta/meta.dart';

import 'provider.dart';

/// Chat-side tool id. Not a `fancad` path and not an MCP catalog entry.
const askToolId = 'ask';

/// In-thread choice card. CAD commands stay on `fancad`.
const askLlmTool = LlmTool(
  name: askToolId,
  description:
      'Ask the user a question with two to six short options. Set '
      'multiple=true when more than one answer may apply. The card always '
      'offers a custom-answer field. Do not use it to pick objects on a '
      'large drawing. This is a chat tool, not a fancad path. When a '
      'question or option refers to objects or a drawing, write '
      '`@objects[tab=<id> ids=1,2,3]` or `@drawing[tab=<id>]` instead of '
      'listing ids in prose.',
  parameters: {
    'type': 'object',
    'properties': {
      'question': {'type': 'string'},
      'options': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'label': {'type': 'string'},
          },
        },
      },
      'multiple': {'type': 'boolean'},
      'allowCustom': {'type': 'boolean'},
      'ids': {
        'type': 'array',
        'items': {'type': 'integer'},
      },
    },
    'required': ['question', 'options'],
  },
);

/// A multiple-choice question the agent needs the human to answer in-thread.
@immutable
class SessionQuestion {
  const SessionQuestion({
    required this.question,
    required this.options,
    this.multiple = false,
    this.allowCustom = true,
    this.ids = const [],
  });

  final String question;
  final List<SessionAskOption> options;
  final bool multiple;
  final bool allowCustom;
  final List<int> ids;
}

@immutable
class SessionAskOption {
  const SessionAskOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Parses an `ask` argument map. Returns null when the call is unusable.
SessionQuestion? parseSessionQuestion(Map<String, Object?> args) {
  final question = '${args['question'] ?? ''}'.trim();
  if (question.isEmpty) return null;
  final options = <SessionAskOption>[];
  final raw = args['options'];
  if (raw is List) {
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map) {
        final label = '${item['label'] ?? item['id'] ?? ''}'.trim();
        if (label.isEmpty) continue;
        final id = '${item['id'] ?? label}'.trim();
        options.add(
          SessionAskOption(id: id.isEmpty ? label : id, label: label),
        );
      } else {
        final label = '$item'.trim();
        if (label.isEmpty) continue;
        options.add(SessionAskOption(id: label, label: label));
      }
    }
  }
  if (options.length < 2 || options.length > 6) return null;
  final ids = <int>[];
  _collectIds(args['ids'], ids);
  return SessionQuestion(
    question: question,
    options: options,
    multiple: _flag(args['multiple']),
    allowCustom: args.containsKey('allowCustom')
        ? _flag(args['allowCustom'])
        : true,
    ids: ids,
  );
}

bool _flag(Object? value) => value == true || value == 'true' || value == 1;

/// Letter shown beside an option, A for the first.
String askOptionLetter(int index) {
  if (index < 0 || index > 25) return '${index + 1}';
  return String.fromCharCode(65 + index);
}

/// Packs picked options and an optional custom line into the tool result.
Map<String, Object?>? encodeAskAnswer({
  required List<SessionAskOption> selected,
  String custom = '',
}) {
  final answers = [...selected];
  final trimmed = custom.trim();
  if (trimmed.isNotEmpty) {
    answers.add(SessionAskOption(id: 'custom', label: trimmed));
  }
  if (answers.isEmpty) return null;
  final first = answers.first;
  if (answers.length == 1) {
    return {'status': 'ok', 'id': first.id, 'label': first.label};
  }
  return {
    'status': 'ok',
    'multiple': true,
    'id': first.id,
    'label': first.label,
    'ids': [for (final answer in answers) answer.id],
    'labels': [for (final answer in answers) answer.label],
  };
}

void _collectIds(Object? value, List<int> into) {
  if (value is int) {
    into.add(value);
  } else if (value is num) {
    into.add(value.toInt());
  } else if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) into.add(parsed);
  } else if (value is List) {
    for (final item in value) {
      _collectIds(item, into);
    }
  }
}

/// Asks the host to present a question card and wait.
typedef QuestionAsker =
    Future<Map<String, Object?>> Function(SessionQuestion question);

/// Feeds a value into the human's in-flight command.
typedef SessionSupplier =
    Future<Map<String, Object?>> Function(Map<String, Object?> args);
