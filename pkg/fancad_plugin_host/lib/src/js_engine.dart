import 'dart:async';

/// A JavaScript error crossing back into Dart.
class JsException implements Exception {
  const JsException(this.message, {this.stack = ''});

  final String message;
  final String stack;

  @override
  String toString() => stack.isEmpty ? message : '$message\n$stack';
}

/// The slice of a JavaScript engine the plugin runtime actually needs.
///
/// Narrow on purpose. QuickJS is the only production implementation, but the
/// runtime is written against this interface so the load/activate/invoke logic
/// can be tested without a native library — and so replacing the engine later
/// is a one-file change rather than a rewrite.
abstract class JsEngine {
  /// Evaluates [source]. [name] appears in stack traces.
  ///
  /// Returns the completion value, converted to Dart primitives, or a [Future]
  /// when the script evaluated to a promise.
  Object? evaluate(String source, {String name});

  /// Installs [callback] as a global function.
  ///
  /// A callback returning a [Future] surfaces in JavaScript as a promise, which
  /// is what makes the whole host API awaitable from plugin code.
  void defineFunction(String name, Function callback);

  /// Calls the global function [name] with [args].
  ///
  /// Exists so the host never has to build JavaScript source out of untrusted
  /// values; arguments cross as data, not as text to be parsed.
  Object? callGlobal(String name, List<Object?> args);

  /// Runs queued microtasks and resolved promise callbacks.
  ///
  /// Must be called after anything that could settle a promise, otherwise
  /// `await` in plugin code never resumes.
  void pumpEventLoop();

  /// Bytes currently allocated, when the engine can report it.
  int get memoryUsage;

  void dispose();
}

/// Creates an engine for one plugin.
///
/// [memoryLimit] and [stackSize] are per-plugin, which is the only resource
/// ceiling the engine can actually enforce for us.
typedef JsEngineFactory = JsEngine Function({
  required int memoryLimit,
  required int stackSize,
});

/// A deliberately simple engine for tests and for hosts without the native
/// library.
///
/// It does not parse JavaScript. It recognises the small set of calls the
/// runtime makes during load and invoke, which is enough to exercise manifest
/// handling, contribution registration, RPC plumbing and error propagation
/// without shipping a JIT into the test process.
class ScriptedJsEngine implements JsEngine {
  ScriptedJsEngine({this.onEvaluate});

  /// Consulted for every [evaluate] call. Returning null means "no result".
  final Object? Function(String source, String name)? onEvaluate;

  final Map<String, Function> functions = {};
  final List<String> evaluated = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  Object? evaluate(String source, {String name = '<eval>'}) {
    if (_disposed) throw const JsException('engine disposed');
    evaluated.add(source);
    return onEvaluate?.call(source, name);
  }

  @override
  void defineFunction(String name, Function callback) {
    functions[name] = callback;
  }

  /// Functions the fake script "declared", which [callGlobal] can reach.
  ///
  /// A test populates this to stand in for what a plugin's `main.js` would have
  /// installed.
  final Map<String, Function> globals = {};

  /// Calls a function the runtime installed, the way JavaScript would.
  Object? call(String name, List<Object?> args) {
    final target = functions[name];
    if (target == null) throw JsException('$name is not defined');
    return Function.apply(target, args);
  }

  @override
  Object? callGlobal(String name, List<Object?> args) {
    final target = globals[name] ?? functions[name];
    if (target == null) throw JsException('$name is not a function');
    return Function.apply(target, args);
  }

  @override
  void pumpEventLoop() {}

  @override
  int get memoryUsage => 0;

  @override
  void dispose() => _disposed = true;
}
