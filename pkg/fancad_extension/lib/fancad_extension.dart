/// The FanCAD extension runtime.
///
/// An extension is one JavaScript file. Each run gets its own engine on a
/// dedicated worker isolate and reaches the application only through a
/// JSON-RPC surface that mirrors the `fancad.*` API. QuickJS is the engine
/// that ships; the runtime talks to [JsEngine], so another engine is a
/// registration in [EngineRegistry].
library;

export 'src/bootstrap.dart' show BootstrapGlobals, buildBootstrapScript;
export 'src/engine_registry.dart';
export 'src/js_engine.dart';
export 'src/extension_api.dart';
export 'src/programs.dart';
export 'src/protocol.dart';
export 'src/script_runner.dart';
export 'src/script_runtime.dart';
export 'src/transport.dart';
