import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';

import 'provider.dart';

/// The one tool the model is given. Commands are discovered through help/run.
LlmTool get fancadLlmTool => const LlmTool(
  name: fancadToolName,
  description: fancadToolDescription,
  parameters: fancadToolParameters,
);

/// Resolves a `fancad` path back to a command and collects highlight ids.
class CommandToolCatalog {
  const CommandToolCatalog();

  List<LlmTool> toolsOf(CommandRegistry registry) => [fancadLlmTool];

  /// Resolves a dotted id or command-line alias.
  CommandDescriptor? commandFor(CommandRegistry registry, String path) =>
      registry.find(path);
}

/// The command a `fancad` run refers to. Other tool names are unknown.
CommandDescriptor? commandForCall(
  CommandRegistry registry,
  LlmToolCall call,
) {
  if (call.name != fancadToolName) return null;
  final path = '${call.arguments['path'] ?? ''}'.trim();
  if (path.isEmpty) return null;
  return const CommandToolCatalog().commandFor(registry, path);
}

/// Arguments that belong to the inner command, not the wrapper tool.
Map<String, Object?> runArgumentsOf(LlmToolCall call) {
  if (call.name != fancadToolName) return const {};
  return asObjectMap(call.arguments['args']);
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
      ? 'fancad({action: run, path: ${command.id}})'
      : 'fancad({action: run, path: ${command.id}, args: {${names.join(', ')}}})';
  final description = command.description.trim();
  return description.isEmpty
      ? 'The command did not run because its arguments were missing or invalid. Call $shape.'
      : 'The command did not run because its arguments were missing or invalid. Call $shape. $description';
}
