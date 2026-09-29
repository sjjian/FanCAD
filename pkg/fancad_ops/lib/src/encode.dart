import 'dart:convert';
import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import 'operation.dart';

/// PNG (or other raster) carried beside a command result, not in its text.
class CommandImage {
  const CommandImage({required this.mime, required this.bytes});

  final String mime;
  final Uint8List bytes;
}

/// Pulls `data.image` off [payload] so tool text stays a short JSON object.
///
/// [bytes] is null when the result has no picture. The returned payload is
/// the same map with that field removed.
({Map<String, Object?> payload, Uint8List? bytes, String? mime})
takeCommandImage(Map<String, Object?> payload) {
  final data = payload['data'];
  if (data is! Map) return (payload: payload, bytes: null, mime: null);
  final raw = data['image'];
  if (raw is! Map) return (payload: payload, bytes: null, mime: null);
  final encoded = raw['data'];
  if (encoded is! String || encoded.isEmpty) {
    return (payload: payload, bytes: null, mime: null);
  }
  Uint8List bytes;
  try {
    bytes = base64Decode(encoded);
  } on FormatException {
    return (payload: payload, bytes: null, mime: null);
  }
  final mime = '${raw['mime'] ?? 'image/png'}';
  final nextData = <String, Object?>{
    for (final entry in data.entries)
      if (entry.key != 'image') '${entry.key}': entry.value,
  };
  return (
    payload: {...payload, 'data': nextData},
    bytes: bytes,
    mime: mime.isEmpty ? 'image/png' : mime,
  );
}

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

Map<String, Object?> ok(Map<String, Object?> data) => {'status': 'ok', ...data};
