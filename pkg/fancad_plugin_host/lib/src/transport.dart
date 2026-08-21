import 'dart:async';
import 'dart:isolate';

import 'js_engine.dart';
import 'plugin_runtime.dart';
import 'protocol.dart';
import 'quickjs_engine.dart';

/// Serves a request a plugin made of the application.
typedef HostCallHandler = Future<Object?> Function(
  String pluginId,
  String method,
  Map<String, Object?> params,
);

/// A channel to a place where plugins run.
///
/// Two implementations, and the difference matters. [IsolateTransport] is what
/// ships: plugin code on another thread, so a badly behaved extension cannot
/// stall a frame. [LocalTransport] runs everything inline, which is how the
/// load, invoke and error paths get tested without spawning anything.
abstract class PluginTransport {
  /// Brings the transport up and installs the handler for plugin-to-host calls.
  Future<void> start(HostCallHandler onHostCall);

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

/// Runs the plugin runtime on the calling isolate.
class LocalTransport implements PluginTransport {
  LocalTransport({
    JsEngineFactory? engineFactory,
    this.hostVersion = '0.1.0',
  }) : _engineFactory = engineFactory ??
            (({required int memoryLimit, required int stackSize}) =>
                ScriptedJsEngine());

  final JsEngineFactory _engineFactory;
  final String hostVersion;

  late final PluginRuntime runtime;
  final StreamController<String> _died = StreamController<String>.broadcast();
  bool _alive = false;

  @override
  Stream<String> get died => _died.stream;

  @override
  bool get isAlive => _alive;

  @override
  Future<void> start(HostCallHandler onHostCall) async {
    runtime = PluginRuntime(
      createEngine: _engineFactory,
      callHost: onHostCall,
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
    return timeout == null ? future : future.timeout(timeout);
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
    if (!immediate) await runtime.disposeAll();
    await _died.close();
  }
}

/// Runs plugins on a dedicated isolate.
///
/// One isolate for all plugins, following the same reasoning as an editor
/// extension host: per-plugin isolates would multiply the FFI runtime and the
/// port bookkeeping without buying isolation the per-plugin JavaScript runtimes
/// do not already provide.
class IsolateTransport implements PluginTransport {
  IsolateTransport({this.hostVersion = '0.1.0', this.debugName = 'fancad.plugins'});

  final String hostVersion;
  final String debugName;

  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  RpcPeer? _peer;
  HostCallHandler? _onHostCall;
  final StreamController<String> _died = StreamController<String>.broadcast();
  bool _alive = false;

  @override
  Stream<String> get died => _died.stream;

  @override
  bool get isAlive => _alive;

  @override
  Future<void> start(HostCallHandler onHostCall) async {
    _onHostCall = onHostCall;
    final ready = Completer<SendPort>();
    final receive = ReceivePort();
    _fromWorker = receive;

    // An exit or error on the worker has to reach the host as a message, not as
    // a silent hang: every pending request needs failing.
    final onExit = ReceivePort();
    final onError = ReceivePort();
    onExit.listen((_) => _handleDeath('the plugin worker exited'));
    onError.listen((error) => _handleDeath('the plugin worker crashed: $error'));

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
      pluginWorkerMain,
      _WorkerBootstrap(receive.sendPort, hostVersion),
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
    final handler = _onHostCall;
    if (handler == null) {
      throw const RpcException(
        RpcErrorCode.internalError,
        'no host handler installed',
      );
    }
    final params = Map<String, Object?>.from(request.params);
    final pluginId = params.remove('pluginId');
    return handler(
      pluginId is String ? pluginId : '',
      request.method,
      params,
    );
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
        'the plugin worker is not running',
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
  const _WorkerBootstrap(this.hostPort, this.hostVersion);

  final SendPort hostPort;
  final String hostVersion;
}

/// The worker isolate entry point.
///
/// Top-level and public because [Isolate.spawn] can only take a top-level or
/// static function.
void pluginWorkerMain(Object? bootstrap) {
  if (bootstrap is! _WorkerBootstrap) return;
  final fromHost = ReceivePort();
  late final RpcPeer peer;
  late final PluginRuntime runtime;

  peer = RpcPeer(
    send: bootstrap.hostPort.send,
    handle: (request) async {
      if (request.method == WorkerMethod.shutdown) {
        await runtime.disposeAll();
        Future<void>.delayed(
          const Duration(milliseconds: 10),
          fromHost.close,
        );
        return {'ok': true};
      }
      return runtime.handle(request);
    },
  );

  runtime = PluginRuntime(
    // Bound here rather than injected: a spawned isolate gets its own copy of
    // top-level state, so anything the host configured would not be visible.
    createEngine: QuickJsEngine.create,
    hostVersion: bootstrap.hostVersion,
    callHost: (pluginId, method, params) => peer.request(
      method,
      params: {...params, 'pluginId': pluginId},
    ),
  );

  fromHost.listen((message) {
    if (message is Map) peer.accept(Map<String, Object?>.from(message));
  });
  bootstrap.hostPort.send(fromHost.sendPort);
}
