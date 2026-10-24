// ignore_for_file: invalid_annotation_target

import 'dart:async';

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'protocol.g.dart';

/// The method names the host sends into the script worker.
abstract final class WorkerMethod {
  /// Creates an engine for one run and evaluates the prelude into it.
  static const String open = 'script/open';

  /// Evaluates source in an open run's engine.
  static const String eval = 'script/eval';

  /// Disposes one run's engine.
  static const String close = 'script/close';

  /// Rejects the next host call an open run makes. A notification.
  static const String cancel = 'script/cancel';

  /// Liveness probe. Used to tell "slow" from "wedged".
  static const String ping = 'worker/ping';

  /// Closes every run and lets the worker's port close.
  static const String shutdown = 'worker/shutdown';
}

/// The method names the script worker sends back to the host.
///
/// Each one is a `fancad.*` call in the prelude. Reads and edits are commands,
/// so this list only holds what a command cannot do.
abstract final class HostMethod {
  static const String executeCommand = 'commands/execute';
  static const String listCommands = 'commands/list';
  static const String showMessage = 'window/showMessage';
  static const String log = 'window/log';
  static const String canvasHold = 'canvas/hold';
  static const String canvasFlash = 'canvas/flash';
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

  /// The script's JavaScript threw.
  static const int scriptError = -32000;

  /// The script asked for something the host does not allow from a script.
  static const int permissionDenied = -32001;

  /// The worker died, so no answer is coming.
  static const int workerDead = -32002;
}

/// A JSON-RPC request or notification.
///
/// A null [id] marks a notification: fire and forget, no reply expected. This
/// is what lets a script log without waiting on the host.
@immutable
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  ignoreUnannotated: true,
)
class RpcRequest {
  const RpcRequest({required this.method, this.params = const {}, this.id});

  const RpcRequest.notification(this.method, [this.params = const {}])
    : id = null;

  @JsonKey()
  final String method;
  @JsonKey(toJson: _omitEmptyParams)
  final Map<String, Object?> params;
  @JsonKey()
  final int? id;

  bool get isNotification => id == null;

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    ..._$RpcRequestToJson(this),
  };

  /// Parses one request. Anything malformed is an [RpcException] with
  /// [RpcErrorCode.invalidRequest], never a cast error.
  static RpcRequest fromJson(Map<String, Object?> json) {
    final method = json['method'];
    if (method is! String) {
      throw const RpcException(RpcErrorCode.invalidRequest, 'missing "method"');
    }
    final id = json['id'];
    if (id != null && id is! num) {
      throw const RpcException(
        RpcErrorCode.invalidRequest,
        '"id" must be a number',
      );
    }
    return RpcRequest(
      method: method,
      params: _paramsOf(json['params']),
      id: (id as num?)?.toInt(),
    );
  }

  static Map<String, Object?> _paramsOf(Object? raw) {
    if (raw == null) return const {};
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map && raw.keys.every((key) => key is String)) {
      return Map<String, Object?>.from(raw);
    }
    throw const RpcException(
      RpcErrorCode.invalidRequest,
      '"params" must be an object',
    );
  }

  @override
  String toString() => 'RpcRequest($method, id: $id)';
}

Map<String, Object?>? _omitEmptyParams(Map<String, Object?> params) =>
    params.isEmpty ? null : params;

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
    final raw = json['id'];
    final id = raw is num ? raw.toInt() : -1;
    final error = json['error'];
    if (error is Map<String, Object?>) {
      return RpcResponse.failure(id, RpcError.fromJson(error));
    }
    return RpcResponse.success(id, json['result']);
  }

  @override
  String toString() => isError
      ? 'RpcResponse($id, error: ${error!.message})'
      : 'RpcResponse($id)';
}

/// The error payload of a failed response.
@immutable
@JsonSerializable(createFactory: false, includeIfNull: false)
class RpcError {
  const RpcError(this.code, this.message, {this.data});

  final int code;
  final String message;

  /// Extra context: a JavaScript stack, the offending permission, and so on.
  final Object? data;

  Map<String, Object?> toJson() => _$RpcErrorToJson(this);

  static RpcError fromJson(Map<String, Object?> json) {
    final code = json['code'];
    final message = json['message'];
    return RpcError(
      code is num ? code.toInt() : RpcErrorCode.internalError,
      message is String ? message : 'Unknown error',
      data: json['data'],
    );
  }

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
/// what allows a script's `await fancad.commands.execute(...)` to be the same
/// machinery, in the opposite direction, as the host's `script/eval`.
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
        'the script worker is not running',
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
      final id = message['id'];
      if (id is num) {
        send(RpcResponse.failure(id.toInt(), error.toError()).toJson());
      }
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
    final error =
        reason ??
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
