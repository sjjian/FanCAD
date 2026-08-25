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
    List<LlmTool> extra = const [],
  }) => [
    for (final command in registry.aiTools(
      includeApprovalRequired: includeApprovalRequired,
    ))
      LlmTool(
        name: command.toolName,
        description: _describe(command),
        parameters: command.toolSchema(),
      ),
    ...extra,
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

/// JSON the model reads after a command tool runs.
///
/// A leftover `cancelled` from a missing prompt looks like the user stopped
/// the command, so the model retries the same call. Those become `failed`
/// with an argument hint. A real user decline is encoded by the agent, not
/// here.
Map<String, Object?> encodeAssistantToolResult(
  CommandResult result,
  CommandDescriptor command,
) {
  if (result.isOk) return result.toJson();
  final message = assistantToolErrorMessage(result, command);
  return {
    'status': 'failed',
    'error': message,
    'message': message,
    if (result.data != null) 'data': result.data,
  };
}

/// Human- and model-readable reason for a non-ok tool result.
String assistantToolErrorMessage(
  CommandResult result,
  CommandDescriptor command,
) {
  final raw = result.message.trim();
  final leftoverCancel =
      raw.isEmpty ||
      raw == 'Cancelled' ||
      raw.startsWith('No value supplied for prompt');
  if (!leftoverCancel) return raw;
  final names = [
    for (final param in command.params)
      param.required ? param.name : '${param.name}?',
  ];
  final shape = names.isEmpty
      ? command.toolName
      : '${command.toolName}({${names.join(', ')}})';
  final description = command.description.trim();
  return description.isEmpty
      ? 'The command did not run because its arguments were missing or invalid. Call $shape.'
      : 'The command did not run because its arguments were missing or invalid. Call $shape. $description';
}
