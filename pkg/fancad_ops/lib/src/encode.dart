import 'package:fancad_core/fancad_core.dart';

import 'operation.dart';

/// JSON a model or MCP client reads after `run`.
///
/// A leftover `cancelled` from a missing prompt looks like the user stopped
/// the command, so the caller retries the same call. Those become `failed`
/// with an argument hint. A real user decline is encoded by the host, not here.
Map<String, Object?> encodeOperationResult(
  CommandResult result,
  Operation operation,
) {
  if (result.isOk) return result.toJson();
  final message = operationErrorMessage(result, operation);
  return {
    'status': 'failed',
    'error': message,
    'message': message,
    if (result.data != null) 'data': result.data,
  };
}

String operationErrorMessage(CommandResult result, Operation operation) {
  final raw = result.message.trim();
  final leftoverCancel =
      raw.isEmpty ||
      raw == 'Cancelled' ||
      raw.startsWith('No value supplied for prompt');
  if (!leftoverCancel) return raw;
  final names = [
    for (final param in operation.params)
      param.required ? param.name : '${param.name}?',
  ];
  final shape = names.isEmpty
      ? 'fancad({action: run, path: ${operation.id}})'
      : 'fancad({action: run, path: ${operation.id}, args: {${names.join(', ')}}})';
  final description = operation.description.trim();
  return description.isEmpty
      ? 'The command did not run because its arguments were missing or invalid. Call $shape.'
      : 'The command did not run because its arguments were missing or invalid. Call $shape. $description';
}

Map<String, Object?> failed(String message) => {
  'status': 'failed',
  'error': message,
  'message': message,
};

Map<String, Object?> ok(Map<String, Object?> data) => {
  'status': 'ok',
  ...data,
};
