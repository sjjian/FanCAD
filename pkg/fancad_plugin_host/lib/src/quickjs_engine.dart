import 'dart:async';

import 'package:quickjs_engine/js_eval_result.dart';
import 'package:quickjs_engine/quickjs/quickjs_runtime2.dart';

import 'js_engine.dart';

/// A [JsEngine] backed by QuickJS-NG.
///
/// One instance per plugin. Separate runtimes cost a few tens of kilobytes each
/// and buy two things worth far more: a plugin cannot reach another plugin's
/// globals, and the memory ceiling below applies per plugin instead of to the
/// whole extension surface.
///
/// Note on runaway scripts: the engine exposes no interrupt hook, so a plugin
/// that enters `while (true) {}` cannot be stopped from Dart — an isolate
/// blocked inside a native call does not reach a safepoint, so even
/// `Isolate.kill` will not land. [memoryLimit] and [stackSize] catch the
/// allocating and recursing variants; the rest is handled a layer up, where the
/// host abandons a wedged worker and starts a fresh one.
class QuickJsEngine implements JsEngine {
  QuickJsEngine({
    int memoryLimit = defaultMemoryLimit,
    int stackSize = defaultStackSize,
  }) : _runtime = QuickJsRuntime2(
         memoryLimit: memoryLimit,
         stackSize: stackSize,
         hostPromiseRejectionHandler: _reportUnhandledRejection,
       ) {
    // The native side signals "there may be jobs to run" on this port. Draining
    // it here is what lets a plugin's `await` resume without the host having to
    // guess when to pump.
    _portSubscription = _runtime.port.listen((_) => _drain());
  }

  /// 64 MB. Generous for drawing automation, small enough that a leak surfaces
  /// as a plugin error rather than as an out-of-memory process.
  static const int defaultMemoryLimit = 64 * 1024 * 1024;

  static const int defaultStackSize = 1024 * 1024;

  static JsEngine create({
    required int memoryLimit,
    required int stackSize,
  }) => QuickJsEngine(memoryLimit: memoryLimit, stackSize: stackSize);

  final QuickJsRuntime2 _runtime;
  late final StreamSubscription<dynamic> _portSubscription;

  JSInvokable? _globalSetter;
  JSInvokable? _globalCaller;
  bool _disposed = false;

  static void _reportUnhandledRejection(dynamic reason) {
    // Swallowing this would turn a plugin bug into silence. The worker turns it
    // into a log line the extensions panel can show.
    Zone.current.handleUncaughtError(
      JsException('unhandled promise rejection: $reason'),
      StackTrace.current,
    );
  }

  @override
  Object? evaluate(String source, {String name = '<plugin>'}) {
    _assertAlive();
    final JsEvalResult result;
    try {
      result = _runtime.evaluate(source, name: name);
    } on JSError catch (error) {
      throw JsException(error.message, stack: error.stack);
    }
    if (result.isError) {
      final raw = result.rawResult;
      if (raw is JSError) {
        throw JsException(raw.message, stack: raw.stack);
      }
      throw JsException(result.stringResult);
    }
    _drain();
    return result.rawResult;
  }

  @override
  void defineFunction(String name, Function callback) {
    _assertAlive();
    // One arrow function, reused for every binding. Evaluating a fresh setter
    // per call would leak a JS function object each time.
    final setter = _globalSetter ??= _runtime
        .evaluate('(key, value) => { this[key] = value; }')
        .rawResult as JSInvokable;
    _runtime.localContext['fancad.globalSetter'] = setter;
    setter.invoke([name, callback]);
  }

  @override
  Object? callGlobal(String name, List<Object?> args) {
    _assertAlive();
    final caller = _globalCaller ??= _runtime
        .evaluate(
          '(name, args) => {\n'
          '  const fn = this[name];\n'
          '  if (typeof fn !== "function") {\n'
          '    throw new Error(name + " is not a function");\n'
          '  }\n'
          '  return fn.apply(undefined, args);\n'
          '}',
          name: '<callGlobal>',
        )
        .rawResult as JSInvokable;
    _runtime.localContext['fancad.globalCaller'] = caller;
    try {
      final result = caller.invoke([name, args]);
      _drain();
      return result;
    } on JSError catch (error) {
      throw JsException(error.message, stack: error.stack);
    }
  }

  @override
  void pumpEventLoop() {
    if (_disposed) return;
    _drain();
  }

  void _drain() {
    if (_disposed) return;
    _runtime.executePendingJob();
  }

  /// QuickJS-NG can report this, but the bundled bindings do not export the
  /// call, so there is nothing honest to return yet.
  @override
  int get memoryUsage => 0;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _portSubscription.cancel();
    _globalSetter = null;
    _globalCaller = null;
    _runtime.dispose();
  }

  void _assertAlive() {
    if (_disposed) {
      throw const JsException('the plugin runtime has been disposed');
    }
  }
}
