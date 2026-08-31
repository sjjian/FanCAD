import 'package:fancad_core/fancad_core.dart';
import 'package:meta/meta.dart';

/// A callable capability. Not a CAD verb — commands become these via a provider.
@immutable
class Operation {
  const Operation({
    required this.id,
    required this.group,
    required this.title,
    required this.execute,
    this.groupTitle = '',
    this.description = '',
    this.params = const [],
    this.aliases = const [],
    this.risk = CommandRisk.edit,
  });

  /// Dotted id, for example `draw.line` or `skill.read`.
  final String id;

  /// First path segment, used by `list` / `help` with no further id.
  final String group;

  /// Human group label, usually the command category.
  final String groupTitle;

  final String title;
  final String description;
  final List<ParamSpec> params;
  final List<String> aliases;
  final CommandRisk risk;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args)
  execute;

  /// JSON Schema for [params], the same shape a command already advertised.
  Map<String, Object?> schema() => {
    'type': 'object',
    'properties': {
      for (final param in params) param.name: param.toJsonSchema(),
    },
    'required': [
      for (final param in params)
        if (param.required) param.name,
    ],
  };

  Map<String, Object?> summaryJson() => {
    'id': id,
    'title': title,
    if (description.isNotEmpty) 'description': _oneLine(description),
    'risk': risk.name,
  };

  Map<String, Object?> helpJson() => {
    'id': id,
    'title': title,
    'group': group,
    if (description.isNotEmpty) 'description': description,
    if (aliases.isNotEmpty) 'aliases': aliases,
    'risk': risk.name,
    'params': [
      for (final param in params)
        {
          'name': param.name,
          'type': param.type.name,
          'required': param.required,
          if (param.description.isNotEmpty) 'description': param.description,
          if (param.options.isNotEmpty) 'options': param.options,
        },
    ],
  };
}

/// The first dotted segment, so `draw.line` and `draw` share a group.
String groupOf(String id) {
  final trimmed = id.trim();
  final dot = trimmed.indexOf('.');
  return dot <= 0 ? trimmed : trimmed.substring(0, dot);
}

String _oneLine(String text) {
  final line = text.split('\n').first.trim();
  return line.length <= 140 ? line : '${line.substring(0, 137)}...';
}

/// Supplies operations that can appear and disappear (plugins, host tools).
abstract class OperationProvider {
  Iterable<Operation> operations();
}
