import 'dart:async';

import 'package:meta/meta.dart';

/// The method names the host sends into the plugin worker.
abstract final class WorkerMethod {
  /// Creates a runtime and evaluates a plugin's entry point.
  static const String load = 'plugin/load';

  /// Tears a plugin's runtime down and frees its scope.
  static const String unload = 'plugin/unload';

  /// Calls a command handler a plugin registered.
  static const String invoke = 'plugin/invoke';

  /// Delivers an event a plugin subscribed to. A notification, not a request.
  static const String event = 'plugin/event';

  /// Evaluates arbitrary source in a plugin's scope, for the console.
  static const String eval = 'plugin/eval';

  /// Asks a plugin's in-flight work to give up. A notification.
  static const String cancel = 'plugin/cancel';

  /// Liveness probe. Used to tell "slow" from "wedged".
  static const String ping = 'worker/ping';

  /// Reports per-plugin memory use, for the extensions panel.
  static const String stats = 'worker/stats';

  /// Unloads everything and lets the worker's port close.
  static const String shutdown = 'worker/shutdown';
}

/// The method names the plugin worker sends back to the host.
///
/// These mirror the `fancad.*` JavaScript API one-to-one, so adding a host
/// capability means adding one constant, one handler and one line of prelude.
abstract final class HostMethod {
  static const String executeCommand = 'commands/execute';
  static const String listCommands = 'commands/list';
  static const String registerCommand = 'commands/register';
  static const String documentSummary = 'document/summary';
  static const String documentQuery = 'document/query';
  static const String documentEntity = 'document/entity';
  static const String documentLayers = 'document/layers';
  static const String selectionGet = 'selection/get';
  static const String selectionSet = 'selection/set';
  static const String applyEdit = 'document/edit';
  static const String showMessage = 'window/showMessage';
  static const String showPrompt = 'window/showPrompt';
  static const String log = 'window/log';
  static const String storageGet = 'storage/get';
  static const String storageSet = 'storage/set';
}

/// Standard JSON-RPC 2.0 error codes plus the ones this host adds.
abstract final class RpcErrorCode {
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  /// The request was cancelled before it produced a result.
  static const int cancelled = -32800;

  /// The request exceeded its deadline.
  static const int timeout = -32801;

  /// The plugin's JavaScript threw.
  static const int pluginError = -32000;

  /// The plugin asked for something its manifest does not permit.
  static const int permissionDenied = -32001;

  /// The worker died, so no answer is coming.
  static const int workerDead = -32002;
}

/// A JSON-RPC request or notification.
///
/// A null [id] marks a notification: fire and forget, no reply expected. This
/// is what lets events flow to plugins without the host waiting on every one.
@immutable
class RpcRequest {
  const RpcRequest({
    required this.method,
    this.params = const {},
    this.id,
  });

  const RpcRequest.notification(this.method, [this.params = const {}])
    : id = null;

  final String method;
  final Map<String, Object?> params;
  final int? id;

  bool get isNotification => id == null;

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    'method': method,
    if (params.isNotEmpty) 'params': params,
    if (id != null) 'id': id,
  };

  static RpcRequest fromJson(Map<String, Object?> json) {
    final method = json['method'];
    if (method is! String) {
      throw const RpcException(
        RpcErrorCode.invalidRequest,
        'missing "method"',
      );
    }
    final params = json['params'];
    return RpcRequest(
      method: method,
      params: params is Map<String, Object?> ? params : const {},
      id: (json['id'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => 'RpcRequest($method, id: $id)';
}

/// A JSON-RPC response: exactly one of [result] or [error] is set.
@immutable
class RpcResponse {
  const RpcResponse.success(this.id, this.result) : error = null;
  const RpcResponse.failure(this.id, RpcError failure)
    : error = failure,
      result = null;

  final int id;
  final Object? result;
  final RpcError? error;

  bool get isError => error != null;

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    'id': id,
    if (error != null) 'error': error!.toJson() else 'result': result,
  };

  static RpcResponse fromJson(Map<String, Object?> json) {
    final id = (json['id'] as num?)?.toInt() ?? -1;
    final error = json['error'];
    if (error is Map<String, Object?>) {
      return RpcResponse.failure(id, RpcError.fromJson(error));
    }
    return RpcResponse.success(id, json['result']);
  }

  @override
  String toString() =>
      isError ? 'RpcResponse($id, error: ${error!.message})' : 'RpcResponse($id)';
}

/// The error payload of a failed response.
@immutable
class RpcError {
  const RpcError(this.code, this.message, {this.data});

  final int code;
  final String message;

  /// Extra context: a JavaScript stack, the offending permission, and so on.
  final Object? data;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    if (data != null) 'data': data,
  };

  static RpcError fromJson(Map<String, Object?> json) => RpcError(
    (json['code'] as num?)?.toInt() ?? RpcErrorCode.internalError,
    json['message'] as String? ?? 'Unknown error',
    data: json['data'],
  );

  @override
  String toString() => 'RpcError($code: $message)';
}

/// Thrown by handlers to produce a specific JSON-RPC error rather than a
/// generic internal failure.
class RpcException implements Exception {
  const RpcException(this.code, this.message, {this.data});

  final int code;
  final String message;
  final Object? data;

  RpcError toError() => RpcError(code, message, data: data);

  @override
  String toString() => 'RpcException($code: $message)';
}

/// Handles one incoming request.
typedef RpcHandler = Future<Object?> Function(RpcRequest request);

/// A bidirectional JSON-RPC endpoint over an abstract message sink.
///
/// Both the host and the worker own one of these. Keeping the peer symmetric is
/// what allows a plugin's `await fancad.commands.execute(...)` to be the same
/// machinery, in the opposite direction, as the host's `plugin/invoke`.
class RpcPeer {
  RpcPeer({required this.send, required this.handle});

  /// Delivers an encoded message to the peer.
  final void Function(Map<String, Object?> message) send;

  /// Serves requests arriving from the peer.
  final RpcHandler handle;

  int _nextId = 1;
  final Map<int, Completer<Object?>> _pending = {};
  bool _closed = false;

  bool get isClosed => _closed;
  int get pendingCount => _pending.length;

  /// Sends a request and waits for its response.
  ///
  /// [timeout] is enforced here rather than at the far end, because the whole
  /// point of a deadline is to survive a peer that has stopped answering.
  Future<Object?> request(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
  }) {
    if (_closed) {
      throw const RpcException(
        RpcErrorCode.workerDead,
        'the plugin worker is not running',
      );
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    send(RpcRequest(method: method, params: params, id: id).toJson());

    if (timeout == null) return completer.future;
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        // Tell the peer to stop, in case it is merely slow rather than stuck.
        notify(r'$/cancelRequest', {'id': id});
        throw RpcException(
          RpcErrorCode.timeout,
          '$method did not answer within ${timeout.inMilliseconds}ms',
        );
      },
    );
  }

  /// Sends a notification. No reply, no waiting.
  void notify(String method, [Map<String, Object?> params = const {}]) {
    if (_closed) return;
    send(RpcRequest.notification(method, params).toJson());
  }

  /// Feeds one decoded message in. Dispatches to [handle] or completes a
  /// pending request.
  Future<void> accept(Map<String, Object?> message) async {
    if (message.containsKey('method')) {
      await _serve(message);
      return;
    }
    final response = RpcResponse.fromJson(message);
    final completer = _pending.remove(response.id);
    if (completer == null || completer.isCompleted) return;
    if (response.isError) {
      final error = response.error!;
      completer.completeError(
        RpcException(error.code, error.message, data: error.data),
      );
    } else {
      completer.complete(response.result);
    }
  }

  Future<void> _serve(Map<String, Object?> message) async {
    final RpcRequest request;
    try {
      request = RpcRequest.fromJson(message);
    } on RpcException catch (error) {
      final id = (message['id'] as num?)?.toInt();
      if (id != null) send(RpcResponse.failure(id, error.toError()).toJson());
      return;
    }
    try {
      final result = await handle(request);
      if (!request.isNotification && !_closed) {
        send(RpcResponse.success(request.id!, result).toJson());
      }
    } on RpcException catch (error) {
      if (!request.isNotification && !_closed) {
        send(RpcResponse.failure(request.id!, error.toError()).toJson());
      }
    } catch (error, stack) {
      if (!request.isNotification && !_closed) {
        send(
          RpcResponse.failure(
            request.id!,
            RpcError(
              RpcErrorCode.internalError,
              '$error',
              data: {'stack': '$stack'},
            ),
          ).toJson(),
        );
      }
    }
  }

  /// Fails every in-flight request and refuses new ones.
  void close([RpcError? reason]) {
    if (_closed) return;
    _closed = true;
    final error = reason ??
        const RpcError(RpcErrorCode.workerDead, 'the connection was closed');
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(
          RpcException(error.code, error.message, data: error.data),
        );
      }
    }
  }
}
