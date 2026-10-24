import 'js_engine.dart';
import 'quickjs_engine.dart';

/// Runtime names a worker can construct.
///
/// [Isolate.spawn] cannot carry a factory closure, and a spawned isolate does
/// not see factories the host registered on its own copy of this library. The
/// worker therefore looks the manifest's `runtime` string up in a table that
/// is compiled into the isolate. Adding an engine is a registration here, not
/// a change to the bridge or the shell.
abstract final class EngineRuntimes {
  static const String quickjs = 'quickjs';

  /// Used when a manifest omits `runtime`.
  static const String defaultRuntime = quickjs;
}

/// Builds one [JsEngine] per plugin from a runtime name.
class EngineRegistry {
  EngineRegistry(Map<String, JsEngineFactory> factories)
    : _factories = Map.unmodifiable(factories);

  /// The engines that ship. QuickJS is one entry, not the type of the host.
  factory EngineRegistry.production() =>
      EngineRegistry({EngineRuntimes.quickjs: QuickJsEngine.create});

  final Map<String, JsEngineFactory> _factories;

  bool contains(String name) => _factories.containsKey(name);

  JsEngine create(
    String name, {
    required int memoryLimit,
    required int stackSize,
  }) {
    final factory = _factories[name];
    if (factory == null) {
      throw JsException(
        'unknown runtime "$name". '
        'This host provides: ${_factories.keys.join(', ')}',
      );
    }
    return factory(memoryLimit: memoryLimit, stackSize: stackSize);
  }
}
