import 'dart:convert';

import 'json.dart';

/// One JSON-RPC 2.0 message, encoded as a single line.
class JsonRpcMessage {
  const JsonRpcMessage({this.id, this.method, this.params, this.result, this.error});

  final Object? id;
  final String? method;
  final Map<String, Object?>? params;
  final Object? result;
  final Map<String, Object?>? error;

  bool get isNotification => id == null && method != null;
  bool get isRequest => id != null && method != null;
  bool get isResponse => method == null && (result != null || error != null);

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    if (id != null) 'id': id,
    if (method != null) 'method': method,
    if (params != null) 'params': params,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
  };

  String encode() => jsonEncode(toJson());

  static JsonRpcMessage? parse(Object? raw) {
    final map = asObjectMap(raw);
    if (map.isEmpty) return null;
    return JsonRpcMessage(
      id: map['id'],
      method: map['method'] is String ? map['method'] as String : null,
      params: map['params'] == null ? null : asObjectMap(map['params']),
      result: map['result'],
      error: map['error'] == null ? null : asObjectMap(map['error']),
    );
  }

  static JsonRpcMessage resultOf(Object? id, Object? result) =>
      JsonRpcMessage(id: id, result: result ?? const {});

  static JsonRpcMessage errorOf(
    Object? id, {
    required int code,
    required String message,
    Object? data,
  }) => JsonRpcMessage(
    id: id,
    error: {
      'code': code,
      'message': message,
      'data': ?data,
    },
  );
}
