import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';

import 'provider.dart';
import 'session_exec.dart';

/// Drawing CLI. Commands are discovered through help/run.
LlmTool get fancadLlmTool => const LlmTool(
  name: fancadToolName,
  description: fancadToolDescription,
  parameters: fancadToolParameters,
);

/// Script CLI. Same action/path/args shape as [fancadLlmTool].
LlmTool get extensionsLlmTool => const LlmTool(
  name: extensionsToolName,
  description: extensionsToolDescription,
  parameters: extensionsToolParameters,
);

/// Resolves a `fancad` path back to a command and collects highlight ids.
class CommandToolCatalog {
  const CommandToolCatalog();

  List<LlmTool> toolsOf(CommandRegistry registry) => [
    fancadLlmTool,
    extensionsLlmTool,
  ];

  /// Resolves a dotted id or command-line alias.
  CommandDescriptor? commandFor(CommandRegistry registry, String path) =>
      registry.find(path);
}

/// Approval label for the chat `exec` tool. Not registered as a command.
final CommandDescriptor _execApproval = CommandDescriptor(
  id: execToolId,
  title: 'Exec',
  risk: CommandRisk.destructive,
  description: 'Evaluates one JavaScript snippet in the QuickJS sandbox.',
  handler: _execNotACommand,
);

Future<CommandResult> _execNotACommand(CommandContext context) async =>
    const CommandResult.failed('exec is not a drawing command');

/// The command a tool call will run.
///
/// The chat `exec` tool is approved as a destructive action, but it is not
/// looked up in [CommandRegistry]. The sandbox sits above that registry.
CommandDescriptor? commandForCall(CommandRegistry registry, LlmToolCall call) {
  if (call.name == execToolId) return _execApproval;
  if (call.name != fancadToolName && call.name != extensionsToolName) {
    return null;
  }
  final path = '${call.arguments['path'] ?? ''}'.trim();
  if (path.isEmpty) return null;
  return const CommandToolCatalog().commandFor(registry, path);
}

/// Arguments that belong to the inner command, not the wrapper tool.
Map<String, Object?> runArgumentsOf(LlmToolCall call) {
  if (call.name == execToolId) {
    final source = call.arguments['source'];
    return source is String ? {'source': source} : const {};
  }
  if (call.name != fancadToolName && call.name != extensionsToolName) {
    return const {};
  }
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
  final tool = isExtensionCliCommand(command.id)
      ? extensionsToolName
      : fancadToolName;
  final shape = names.isEmpty
      ? '$tool({action: run, path: ${command.id}})'
      : '$tool({action: run, path: ${command.id}, args: {${names.join(', ')}}})';
  final description = command.description.trim();
  return description.isEmpty
      ? 'The command did not run because its arguments were missing or invalid. Call $shape.'
      : 'The command did not run because its arguments were missing or invalid. Call $shape. $description';
}
