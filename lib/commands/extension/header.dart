import 'package:fancad_core/fancad_core.dart';

/// What an extension says about itself. Taken from the comment at the top of the
/// file, so the sidebar and `extensions.list` can show it without a second file.
class ExtensionNote {
  const ExtensionNote({
    this.description,
    this.usage,
    this.params = const [],
    this.problem,
  });

  final String? description;
  final String? usage;
  final List<ParamSpec> params;

  /// Why a `param` line could not be read. The extension does not run until it
  /// is fixed, since its parameters would not be the ones the author wrote.
  final String? problem;
}

/// A new extension. The header is the description and usage a person edits.
const extensionTemplate = '''
/**
 * description: 
 * usage: 
 */

''';

/// Reads `description`, `usage` and `param` lines from the comment that opens
/// [source].
///
/// A block comment or a run of `//` lines counts. A comment later in the file
/// does not. Blank values are left out.
ExtensionNote extensionNote(String source) {
  final header = _leadingComment(source);
  if (header == null) return const ExtensionNote();
  String? description;
  String? usage;
  String? current;
  final params = <ParamSpec>[];
  final problems = <String>[];
  for (final raw in header.split('\n')) {
    final line = raw.trim();
    final described = _field(line, 'description');
    final used = _field(line, 'usage');
    if (described != null) {
      current = 'description';
      description = _join(description, described);
    } else if (used != null) {
      current = 'usage';
      usage = _join(usage, used);
    } else if (_paramLine.hasMatch(line)) {
      current = null;
      try {
        final param = _paramSpec(line);
        if (params.any((known) => known.name == param.name)) {
          throw FormatException('"${param.name}" is declared twice');
        }
        params.add(param);
      } on FormatException catch (error) {
        problems.add('$line: ${error.message}');
      }
    } else if (current != null && line.isNotEmpty) {
      if (current == 'description') {
        description = _join(description, line);
      } else {
        usage = _join(usage, line);
      }
    }
  }
  return ExtensionNote(
    description: _present(description),
    usage: _present(usage),
    params: params,
    problem: problems.isEmpty ? null : problems.join('; '),
  );
}

final _paramLine = RegExp(r'^param\s+\S+\s*:', caseSensitive: false);

/// `param center: point 圆心`, `param count: integer = 3 圈数` or
/// `param label: text = "Hello world" 文字`.
///
/// The name is an identifier, the type is a [ParamType] name, and a default
/// makes the parameter optional. A text default with spaces is quoted.
ParamSpec _paramSpec(String line) {
  final match = RegExp(
    r'^param\s+(\S+?)\s*:\s*(\S*)\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(line)!;
  final name = match.group(1)!;
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
    throw FormatException('"$name" is not a parameter name');
  }
  final rawType = match.group(2)!;
  final type = _paramType(rawType);
  if (type == null) {
    throw FormatException(
      rawType.isEmpty
          ? 'the type is missing'
          : '"$rawType" is not a type. Use one of '
                '${ParamType.values.map((type) => type.name).join(', ')}',
    );
  }
  var rest = match.group(3)!.trim();
  Object? fallback;
  if (rest.startsWith('=')) {
    rest = rest.substring(1).trimLeft();
    final String token;
    final quote = rest.isEmpty ? '' : rest[0];
    if (quote == '"' || quote == "'") {
      final close = rest.indexOf(quote, 1);
      if (close < 0) throw const FormatException('the default is not closed');
      token = rest.substring(1, close);
      rest = rest.substring(close + 1).trimLeft();
    } else {
      final gap = rest.indexOf(RegExp(r'\s'));
      token = gap < 0 ? rest : rest.substring(0, gap);
      rest = gap < 0 ? '' : rest.substring(gap).trimLeft();
    }
    fallback = _paramDefault(type, token);
    if (fallback == null) {
      throw FormatException('"$token" is not a default for ${type.name}');
    }
  }
  return ParamSpec(
    name: name,
    type: type,
    description: rest,
    prompt: rest.isEmpty ? null : rest,
    required: fallback == null,
    defaultValue: fallback,
  );
}

ParamType? _paramType(String raw) {
  for (final type in ParamType.values) {
    if (type.name.toLowerCase() == raw.toLowerCase()) return type;
  }
  return null;
}

Object? _paramDefault(ParamType type, String token) {
  switch (type) {
    case ParamType.integer:
    case ParamType.entity:
      return int.tryParse(token);
    case ParamType.number:
    case ParamType.distance:
    case ParamType.angle:
      return num.tryParse(token);
    case ParamType.boolean:
      if (token.toLowerCase() == 'true') return true;
      if (token.toLowerCase() == 'false') return false;
      return null;
    case ParamType.text:
    case ParamType.layer:
    case ParamType.block:
    case ParamType.choice:
      return token;
    case ParamType.point:
    case ParamType.selection:
    case ParamType.json:
    case ParamType.points:
      return null;
  }
}

String? _leadingComment(String source) {
  final trimmed = source.trimLeft();
  if (trimmed.startsWith('/*')) {
    final end = trimmed.indexOf('*/');
    if (end < 0) return null;
    final body = trimmed.substring(2, end);
    return body.split('\n').map(_stripStar).join('\n');
  }
  if (!trimmed.startsWith('//')) return null;
  final lines = <String>[];
  for (final line in trimmed.split('\n')) {
    final text = line.trim();
    if (!text.startsWith('//')) break;
    lines.add(text.substring(2).trim());
  }
  return lines.join('\n');
}

String _stripStar(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('*')) return trimmed;
  return trimmed.substring(1).trim();
}

String? _field(String line, String key) {
  final match = RegExp(
    '^$key\\s*:\\s*(.*)\$',
    caseSensitive: false,
  ).firstMatch(line);
  return match?.group(1);
}

String _join(String? soFar, String more) {
  final extra = more.trim();
  if (extra.isEmpty) return soFar ?? '';
  if (soFar == null || soFar.isEmpty) return extra;
  return '$soFar $extra';
}

String? _present(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
