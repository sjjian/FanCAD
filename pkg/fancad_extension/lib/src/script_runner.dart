import 'dart:async';
import 'dart:convert';

import 'package:fancad_core/fancad_core.dart';

import 'programs.dart';
import 'protocol.dart';
import 'transport.dart';

/// Runs one extension or exec snippet at a time per call, on a worker it owns.
///
/// Each run opens its own engine, evaluates the source as an async function
/// body, and closes the engine. The worker starts on the first run. A run that
/// times out drops the worker, because QuickJS cannot interrupt a tight loop;
/// the next run starts another.
class ScriptRunner {
  ScriptRunner({
    required this.openTransport,
    required this.onCall,
    this.timeout = const Duration(seconds: 30),
  });

  /// Builds a fresh worker. Called again after a reset.
  final ExtensionTransport Function() openTransport;

  /// Serves the `fancad.*` calls a running script makes.
  final ExtensionCallHandler onCall;

  /// Deadline for one evaluation.
  final Duration timeout;

  ExtensionTransport? _transport;
  Future<ExtensionTransport>? _starting;
  final Set<String> _live = {};
  int _nextScope = 0;

  /// Whether a script is running right now.
  bool get isBusy => _live.isNotEmpty;

  /// Runs [source] with `fancad.args` set to [args].
  ///
  /// Ok carries `{value}`, the script's return value. A thrown error, a syntax
  /// error, and a timeout are failed results, not exceptions.
  Future<CommandResult> run(
    String source, {
    Map<String, Object?> args = const {},
  }) async {
    final ExtensionTransport transport;
    try {
      transport = await _ensure();
    } on RpcException catch (error) {
      return CommandResult.failed(error.message);
    }
    final scope = 'run-${++_nextScope}';
    try {
      await transport.request(WorkerMethod.open, params: {'scope': scope});
    } on RpcException catch (error) {
      return CommandResult.failed(error.message);
    }
    _live.add(scope);
    try {
      // Args stay a separate evaluation so the file's own line numbers stay
      // put.
      await _evaluate(transport, scope, 'fancad.args = ${jsonEncode(args)};');
      final programs = extensionPrograms(source);
      for (var i = 0; i < programs.length; i++) {
        final Object? value;
        try {
          value = await _evaluate(transport, scope, programs[i]);
        } on RpcException catch (error) {
          final retry =
              i + 1 < programs.length &&
              error.message.startsWith('SyntaxError');
          if (retry) continue;
          rethrow;
        }
        final failure = extensionFailure(value);
        if (failure != null) return CommandResult.failed(failure);
        return CommandResult.ok(data: {'value': extensionValue(value)});
      }
      return const CommandResult.failed('the extension did not run');
    } on RpcException catch (error) {
      if (error.code == RpcErrorCode.timeout) await reset();
      return CommandResult.failed(error.message);
    } finally {
      _live.remove(scope);
      if (identical(_transport, transport) && transport.isAlive) {
        try {
          await transport.request(WorkerMethod.close, params: {'scope': scope});
        } on RpcException {
          // The worker went away while the run was closing; nothing to free.
        }
      }
    }
  }

  Future<Object?> _evaluate(
    ExtensionTransport transport,
    String scope,
    String source,
  ) async {
    final reply = await transport.request(
      WorkerMethod.eval,
      params: {'scope': scope, 'source': source},
      timeout: timeout,
    );
    return reply is Map ? reply['value'] : reply;
  }

  /// Refuses calls from a run the host has stopped waiting for, so a script
  /// abandoned after a timeout cannot keep editing the drawing.
  Future<Object?> _serve(
    String scope,
    String method,
    Map<String, Object?> params,
  ) {
    if (!_live.contains(scope)) {
      throw const RpcException(
        RpcErrorCode.cancelled,
        'this script is no longer running',
      );
    }
    return onCall(scope, method, params);
  }

  Future<ExtensionTransport> _ensure() {
    final current = _transport;
    if (current != null && current.isAlive) return Future.value(current);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<ExtensionTransport> _start() async {
    final previous = _transport;
    _transport = null;
    if (previous != null) await previous.dispose(immediate: true);
    final transport = openTransport();
    await transport.start(_serve);
    _transport = transport;
    return transport;
  }

  /// Drops the worker and every run on it. The next [run] starts another.
  Future<void> reset() async {
    _live.clear();
    final transport = _transport;
    _transport = null;
    if (transport != null) await transport.dispose(immediate: true);
  }

  Future<void> dispose() => reset();
}
