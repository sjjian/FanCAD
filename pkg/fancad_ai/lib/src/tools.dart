import 'package:fancad_core/fancad_core.dart';

import 'provider.dart';

/// Maps the command registry onto LLM tool definitions.
///
/// There is no second catalogue. A command that is registered — built-in or
/// contributed by a plugin — is a tool the moment [AiExposure] allows it.
/// That is what "command registry as AI toolset" means in practice.
class CommandToolCatalog {
  const CommandToolCatalog();

  /// Tools the model may call, generated from [registry].
  List<LlmTool> toolsOf(
    CommandRegistry registry, {
    bool includeApprovalRequired = true,
  }) => [
    for (final command in registry.aiTools(
      includeApprovalRequired: includeApprovalRequired,
    ))
      LlmTool(
        name: command.toolName,
        description: _describe(command),
        parameters: command.toolSchema(),
      ),
  ];

  /// Resolves a tool name back to the command that produced it.
  CommandDescriptor? commandFor(CommandRegistry registry, String toolName) =>
      registry.findByToolName(toolName);

  /// Entity ids a tool call is about to touch, used to highlight a preview.
  static List<int> highlightIdsOf(Map<String, Object?> arguments) {
    final ids = <int>{};
    for (final key in const ['ids', 'id', 'target', 'selection']) {
      _collectIds(arguments[key], ids);
    }
    return ids.toList();
  }

  static void _collectIds(Object? value, Set<int> into) {
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
    } else if (value is Map) {
      final id = value['id'];
      if (id != null) _collectIds(id, into);
    }
  }

  static String _describe(CommandDescriptor command) {
    final buffer = StringBuffer();
    buffer.write(command.description.isEmpty ? command.title : command.description);
    if (command.aliases.isNotEmpty) {
      buffer.write(' Aliases: ${command.aliases.join(', ')}.');
    }
    if (command.risk == CommandRisk.destructive) {
      buffer.write(' Destructive: requires approval.');
    }
    return buffer.toString();
  }
}
