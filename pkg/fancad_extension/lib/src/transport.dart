import 'dart:async';
import 'dart:isolate';

import 'engine_registry.dart';
import 'js_engine.dart';
import 'protocol.dart';
import 'script_runtime.dart';

/// Serves a request a running script made of the application.
///
/// [scope] names the run that asked.
typedef ExtensionCallHandler =
    Future<Object?> Function(
      String scope,
      String method,
      Map<String, Object?> params,
    );

/// A channel to the worker scripts run on.
///
/// Two implementations, and the difference matters. [IsolateTransport] is what
/// ships: script code on another thread, so a badly behaved extension cannot
/// stall a frame. [LocalTransport] runs everything inline, which is how the
/// open, eval and error paths get tested without spawning anything.
abstract class ExtensionTransport {
  /// Brings the transport up and installs the handler for `fancad.*` calls.
  Future<void> start(ExtensionCallHandler onExtensionCall);

  Future<Object?> request(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
  });

  void notify(String method, [Map<String, Object?> params = const {}]);

  /// Whether the far end can still be expected to answer.
  bool get isAlive;

  /// Fires when the transport dies unexpectedly, so the host can rebuild it.
  Stream<String> get died;

  /// Shuts down. [immediate] abandons the far end instead of asking politely,
  /// which is the only option when it has stopped responding.
  Future<void> dispose({bool immediate = false});
}

/// Runs the script runtime on the calling isolate.
class LocalTransport implements ExtensionTransport {
  LocalTransport({JsEngineFactory? engineFactory, this.hostVersion = '0.1.0'})
    : engineFactory =
          engineFactory ??
          (({required int memoryLimit, required int stackSize}) =>
              ScriptedJsEngine());

  /// The factory this in-process transport builds engines with.
  final JsEngineFactory engineFactory;
  final String hostVersion;

  late final ScriptRuntime runtime;
  final StreamController<String> _died = StreamController<String>.broadcast();
  bool _alive = false;

  @override
  Stream<String> get died => _died.stream;

  @override
  bool get isAlive => _alive;

  @override
  Future<void> start(ExtensionCallHandler onExtensionCall) async {
    runtime = ScriptRuntime(
      createEngine: engineFactory,
      callHost: onExtensionCall,
      hostVersion: hostVersion,
    );
    _alive = true;
  }

  @override
  Future<Object?> request(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
  }) async {
    if (!_alive) {
      throw const RpcException(RpcErrorCode.workerDead, 'transport is closed');
    }
    final future = runtime.handle(
      RpcRequest(method: method, params: params, id: 0),
    );
    if (timeout == null) return future;
    return future.timeout(
      timeout,
      onTimeout: () => throw RpcException(
        RpcErrorCode.timeout,
        '$method did not answer within ${timeout.inMilliseconds}ms',
      ),
    );
  }

  @override
  void notify(String method, [Map<String, Object?> params = const {}]) {
    if (!_alive) return;
    runtime.handle(RpcRequest(method: method, params: params));
  }

  @override
  Future<void> dispose({bool immediate = false}) async {
    if (!_alive) return;
    _alive = false;
    if (!immediate) runtime.disposeAll();
    await _died.close();
  }
}

/// Runs scripts on a dedicated isolate.
///
/// One isolate for every run, following the same reasoning as an editor
/// extension host: per-run isolates would multiply the FFI runtime and the
/// port bookkeeping without buying isolation the per-run JavaScript engines
/// do not already provide.
class IsolateTransport implements ExtensionTransport {
  IsolateTransport({
    this.hostVersion = '0.1.0',
    this.runtime = EngineRuntimes.defaultRuntime,
    this.debugName = 'fancad.extensions',
  });

  final String hostVersion;

  /// Runtime name handed to the worker, looked up in its [EngineRegistry].
  final String runtime;
  final String debugName;

  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  RpcPeer? _peer;
  ExtensionCallHandler? _onExtensionCall;
  final StreamController<String> _died = StreamController<String>.broadcast();
  bool _alive = false;

  @override
  Stream<String> get died => _died.stream;

  @override
  bool get isAlive => _alive;

  @override
  Future<void> start(ExtensionCallHandler onExtensionCall) async {
    _onExtensionCall = onExtensionCall;
    final ready = Completer<SendPort>();
    final receive = ReceivePort();
    _fromWorker = receive;

    // An exit or error on the worker has to reach the host as a message, not as
    // a silent hang: every pending request needs failing.
    final onExit = ReceivePort();
    final onError = ReceivePort();
    onExit.listen((_) => _handleDeath('the script worker exited'));
    onError.listen(
      (error) => _handleDeath('the script worker crashed: $error'),
    );

    receive.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is Map) {
        _peer?.accept(Map<String, Object?>.from(message));
      }
    });

    _isolate = await Isolate.spawn(
      extensionWorkerMain,
      _WorkerBootstrap(receive.sendPort, hostVersion, runtime),
      debugName: debugName,
      onExit: onExit.sendPort,
      onError: onError.sendPort,
      errorsAreFatal: false,
    );

    _toWorker = await ready.future;
    _peer = RpcPeer(
      send: (message) => _toWorker?.send(message),
      handle: _serveWorkerRequest,
    );
    _alive = true;
  }

  Future<Object?> _serveWorkerRequest(RpcRequest request) async {
    final handler = _onExtensionCall;
    if (handler == null) {
      throw const RpcException(
        RpcErrorCode.internalError,
        'no host handler installed',
      );
    }
    final params = Map<String, Object?>.from(request.params);
    final scope = params.remove('scope');
    return handler(scope is String ? scope : '', request.method, params);
  }

  void _handleDeath(String reason) {
    if (!_alive) return;
    _alive = false;
    _peer?.close(const RpcError(RpcErrorCode.workerDead, 'worker died'));
    if (!_died.isClosed) _died.add(reason);
  }

  @override
  Future<Object?> request(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
  }) {
    final peer = _peer;
    if (!_alive || peer == null) {
      throw const RpcException(
        RpcErrorCode.workerDead,
        'the script worker is not running',
      );
    }
    return peer.request(method, params: params, timeout: timeout);
  }

  @override
  void notify(String method, [Map<String, Object?> params = const {}]) {
    if (!_alive) return;
    _peer?.notify(method, params);
  }

  @override
  Future<void> dispose({bool immediate = false}) async {
    if (_isolate == null) return;
    _alive = false;
    if (!immediate) {
      // Best effort: a wedged worker will not get this far, which is exactly
      // why the kill below is unconditional.
      try {
        await request(
          WorkerMethod.shutdown,
          timeout: const Duration(milliseconds: 500),
        );
      } catch (_) {
        // Nothing to do; we are killing it either way.
      }
    }
    _peer?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _fromWorker?.close();
    _fromWorker = null;
    _toWorker = null;
    if (!_died.isClosed) await _died.close();
  }
}

/// What the host hands the worker isolate at spawn.
class _WorkerBootstrap {
  const _WorkerBootstrap(this.hostPort, this.hostVersion, this.runtime);

  final SendPort hostPort;
  final String hostVersion;

  /// Engine name. The worker resolves it through [EngineRegistry] inside the
  /// isolate.
  final String runtime;
}

/// The worker isolate entry point.
///
/// Top-level and public because [Isolate.spawn] can only take a top-level or
/// static function.
void extensionWorkerMain(Object? bootstrap) {
  if (bootstrap is! _WorkerBootstrap) return;
  final fromHost = ReceivePort();
  late final RpcPeer peer;
  late final ScriptRuntime runtime;

  peer = RpcPeer(
    send: bootstrap.hostPort.send,
    handle: (request) async {
      if (request.method == WorkerMethod.shutdown) {
        runtime.disposeAll();
        Future<void>.delayed(const Duration(milliseconds: 10), fromHost.close);
        return {'ok': true};
      }
      return runtime.handle(request);
    },
  );

  runtime = ScriptRuntime(
    // Bound here rather than injected: a spawned isolate gets its own copy of
    // top-level state, so a factory the host closed over would not be visible.
    // The registry is a table compiled into this library.
    engines: EngineRegistry.production(),
    runtime: bootstrap.runtime,
    hostVersion: bootstrap.hostVersion,
    // The run id goes last so a script's own params cannot name another run.
    callHost: (scope, method, params) =>
        peer.request(method, params: {...params, 'scope': scope}),
  );

  fromHost.listen((message) {
    if (message is Map) peer.accept(Map<String, Object?>.from(message));
  });
  bootstrap.hostPort.send(fromHost.sendPort);
}
