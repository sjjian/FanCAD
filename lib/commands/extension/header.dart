import 'package:fancad_core/fancad_core.dart';

/// What an extension says about itself. Taken from the comment at the top of the
/// file, so the sidebar and `extensions.list` can show it without a second file.
class ExtensionNote {
  const ExtensionNote({this.description, this.usage, this.params = const []});

  final String? description;
  final String? usage;
  final List<ParamSpec> params;
}

/// A new extension. The header is the description and usage a person edits.
const extensionTemplate = '''
/**
 * description: 
 * usage: 
 */

''';

/// Reads `description` and `usage` from the comment that opens [source].
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
  final seen = <String>{};
  for (final raw in header.split('\n')) {
    final line = raw.trim();
    final described = _field(line, 'description');
    final used = _field(line, 'usage');
    final param = _paramSpec(line);
    if (described != null) {
      current = 'description';
      description = _join(description, described);
    } else if (used != null) {
      current = 'usage';
      usage = _join(usage, used);
    } else if (param != null) {
      current = null;
      if (seen.add(param.name)) params.add(param);
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
  );
}

/// `param center: point 圆心` or `param count: integer = 3 圈数`.
///
/// The name is an identifier, the type is a [ParamType] name, and a default
/// makes the parameter optional. Anything that does not match is left for the
/// description and usage lines.
ParamSpec? _paramSpec(String line) {
  final match = RegExp(
    r'^param\s+(\S+)\s*:\s*(\S+)\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (match == null) return null;
  final name = match.group(1)!;
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) return null;
  final type = _paramType(match.group(2)!);
  if (type == null) return null;
  var rest = match.group(3)!.trim();
  Object? fallback;
  if (rest.startsWith('=')) {
    rest = rest.substring(1).trimLeft();
    final gap = rest.indexOf(RegExp(r'\s'));
    final token = gap < 0 ? rest : rest.substring(0, gap);
    final parsed = _paramDefault(type, token);
    if (parsed != null) {
      fallback = parsed;
      rest = gap < 0 ? '' : rest.substring(gap).trimLeft();
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
  if (token.isEmpty) return null;
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
      return token;
    case ParamType.point:
    case ParamType.selection:
    case ParamType.layer:
    case ParamType.block:
    case ParamType.choice:
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
