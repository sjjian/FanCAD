import 'dart:async';
import 'dart:convert';

import 'bootstrap.dart';
import 'engine_registry.dart';
import 'js_engine.dart';
import 'protocol.dart';

/// Runs scripts. Lives on the worker isolate; never touches Flutter.
///
/// Each run is a scope with its own engine, so two runs cannot see each
/// other's globals and closing one is dropping its engine. Everything a script
/// needs from the application it asks for over [callHost].
class ScriptRuntime {
  ScriptRuntime({
    JsEngineFactory? createEngine,
    EngineRegistry? engines,
    required this.callHost,
    this.runtime = EngineRuntimes.defaultRuntime,
    this.hostVersion = '0.1.0',
    this.memoryLimit = 64 * 1024 * 1024,
    this.stackSize = 1024 * 1024,
  }) : _createEngine = createEngine,
       _engines = engines {
    if (_createEngine == null && _engines == null) {
      throw ArgumentError('ScriptRuntime needs createEngine or engines');
    }
  }

  /// One factory standing in for [runtime]. Tests use this so they never load
  /// a native engine.
  final JsEngineFactory? _createEngine;

  /// Named engines. The production worker passes [EngineRegistry.production].
  final EngineRegistry? _engines;

  final String runtime;

  /// Forwards a script's request to the application.
  final Future<Object?> Function(
    String scope,
    String method,
    Map<String, Object?> params,
  )
  callHost;

  final String hostVersion;
  final int memoryLimit;
  final int stackSize;

  final Map<String, JsEngine> _scopes = {};

  /// Runs whose in-flight work has been cancelled.
  ///
  /// The engine cannot be interrupted mid-bytecode, so the next host call the
  /// run makes is rejected, and its `await` throws. A script spinning in pure
  /// computation is beyond reach of anything but abandoning the worker.
  final Set<String> _cancelled = {};

  Iterable<String> get openScopes => _scopes.keys;

  /// Serves one request from the host.
  Future<Object?> handle(RpcRequest request) async {
    switch (request.method) {
      case WorkerMethod.open:
        return open(_requireString(request.params, 'scope'));
      case WorkerMethod.eval:
        return evaluate(
          _requireString(request.params, 'scope'),
          _requireString(request.params, 'source'),
        );
      case WorkerMethod.close:
        return close(_requireString(request.params, 'scope'));
      case WorkerMethod.cancel:
        cancel(_requireString(request.params, 'scope'));
        return null;
      case WorkerMethod.ping:
        return {'scopes': _scopes.keys.toList()};
      default:
        throw RpcException(
          RpcErrorCode.methodNotFound,
          'the script worker does not handle "${request.method}"',
        );
    }
  }

  /// Creates an engine for [scope] and evaluates the prelude into it.
  Map<String, Object?> open(String scope) {
    if (_scopes.containsKey(scope)) {
      throw RpcException(RpcErrorCode.invalidParams, '$scope is already open');
    }
    final JsEngine engine;
    try {
      engine = _openEngine();
    } on JsException catch (error) {
      throw RpcException(RpcErrorCode.pluginError, error.message);
    }
    try {
      engine.defineFunction(
        BootstrapGlobals.rpc,
        (String method, String paramsJson) =>
            _serveFromScript(scope, method, paramsJson),
      );
      engine.evaluate(
        buildBootstrapScript(hostVersion: hostVersion),
        name: 'fancad/bootstrap.js',
      );
    } on JsException catch (error) {
      engine.dispose();
      throw RpcException(
        RpcErrorCode.pluginError,
        'the script prelude failed: ${error.message}',
        data: {'stack': error.stack},
      );
    }
    _scopes[scope] = engine;
    return {'scope': scope};
  }

  /// Evaluates [source] in [scope] and returns its completion value.
  Future<Map<String, Object?>> evaluate(String scope, String source) async {
    final engine = _require(scope);
    try {
      final value = await _maybeAwait(
        engine.evaluate(source, name: '$scope/<script>'),
      );
      return {'value': _jsonSafe(value)};
    } on JsException catch (error) {
      throw RpcException(
        RpcErrorCode.pluginError,
        error.message,
        data: {'stack': error.stack},
      );
    }
  }

  Map<String, Object?> close(String scope) {
    _cancelled.remove(scope);
    final engine = _scopes.remove(scope);
    engine?.dispose();
    return {'scope': scope, 'closed': engine != null};
  }

  /// Marks [scope]'s current work cancelled and asks the engine to interrupt.
  void cancel(String scope) {
    if (!_scopes.containsKey(scope)) return;
    _cancelled.add(scope);
    _scopes[scope]!.requestInterrupt();
  }

  /// Closes every run. Called when the worker shuts down.
  void disposeAll() {
    for (final scope in _scopes.keys.toList()) {
      close(scope);
    }
  }

  JsEngine _openEngine() {
    final engines = _engines;
    if (engines != null) {
      return engines.create(
        runtime,
        memoryLimit: memoryLimit,
        stackSize: stackSize,
      );
    }
    return _createEngine!(memoryLimit: memoryLimit, stackSize: stackSize);
  }

  /// Handles one `__fancad_rpc` call, returning the JSON envelope the prelude
  /// expects.
  ///
  /// Errors are encoded rather than thrown, so a rejected host call becomes a
  /// catchable JavaScript error instead of an unhandled Dart exception crossing
  /// the FFI boundary.
  Future<String> _serveFromScript(
    String scope,
    String method,
    String paramsJson,
  ) async {
    try {
      if (_cancelled.contains(scope)) {
        throw const RpcException(RpcErrorCode.cancelled, 'cancelled');
      }
      final decoded = paramsJson.isEmpty ? null : jsonDecode(paramsJson);
      final params = decoded is Map<String, Object?>
          ? decoded
          : const <String, Object?>{};
      final result = await callHost(scope, method, params);
      if (_cancelled.contains(scope)) {
        throw const RpcException(RpcErrorCode.cancelled, 'cancelled');
      }
      return jsonEncode({'result': _jsonSafe(result)});
    } on RpcException catch (error) {
      return jsonEncode({
        'error': {'code': error.code, 'message': error.message},
      });
    } catch (error) {
      return jsonEncode({
        'error': {'code': RpcErrorCode.internalError, 'message': '$error'},
      });
    }
  }

  JsEngine _require(String scope) {
    final engine = _scopes[scope];
    if (engine == null) {
      throw RpcException(RpcErrorCode.invalidParams, '$scope is not open');
    }
    return engine;
  }

  static Future<Object?> _maybeAwait(Object? value) async =>
      value is Future ? await value : value;

  /// Normalises engine output into something `jsonEncode` accepts.
  ///
  /// The JavaScript bridge hands back `Map<dynamic, dynamic>` and `List<dynamic>`
  /// which `jsonEncode` rejects for non-string keys, so keys are stringified
  /// here rather than at every call site.
  static Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) _jsonSafe(item)];
    }
    return '$value';
  }

  static String _requireString(Map<String, Object?> params, String key) {
    final value = params[key];
    if (value is! String) {
      throw RpcException(RpcErrorCode.invalidParams, '"$key" must be a string');
    }
    return value;
  }
}
