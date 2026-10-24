import 'provider.dart';

/// Chat-side tool id. The sandbox sits above the command registry. MCP does
/// not offer it. A script cannot `commands.execute` it.
const execToolId = 'exec';

/// Runs one snippet in the host QuickJS sandbox, above the command registry.
/// The value comes back on this tool result, so the next round can use it.
const execLlmTool = LlmTool(
  name: execToolId,
  description:
      'Runs one unsaved JavaScript snippet in the drawing sandbox and '
      'returns its value. Use it to try a change; save with extensions '
      'action=run path=extensions.write when you want to keep it. '
      'Pass source. Top-level await and return are valid; a header comment '
      'is not code. fancad.args is {}. Inside, fancad.commands.execute(path, '
      'args) matches fancad action=run. Do not call help, schema, exec, or '
      'extension.<name> from the snippet.',
  parameters: {
    'type': 'object',
    'properties': {
      'source': {
        'type': 'string',
        'description': 'JavaScript. Its return value is the tool result.',
      },
    },
    'required': ['source'],
  },
);

/// The host runs [source] on its existing QuickJS worker.
typedef CodeExecutor = Future<Map<String, Object?>> Function(String source);

/// The snippet to evaluate, or null when the call has nothing to run.
String? parseExecSource(Map<String, Object?> args) {
  final source = args['source'];
  if (source is! String) return null;
  if (source.trim().isEmpty) return null;
  return source;
}
