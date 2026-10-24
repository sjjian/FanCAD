/// The FanCAD extension host.
///
/// Extensions run in per-extension engines on a dedicated isolate, and
/// reach the application only through a JSON-RPC surface that mirrors the
/// `fancad.*` API. QuickJS is the engine that ships; the host talks to
/// [JsEngine] and names a runtime in the manifest. Contributions are declared
/// before any plugin code runs, so the palette, the command line and the AI
/// tool list are complete from the first frame while third-party code stays
/// off the startup path.
library;

export 'src/bootstrap.dart' show BootstrapGlobals, buildBootstrapScript;
export 'src/contributions.dart';
export 'src/engine_registry.dart';
export 'src/plugin_api.dart';
export 'src/js_engine.dart';
export 'src/manifest.dart';
export 'src/modules.dart'
    show pluginModuleCallback, pluginModuleReply, pluginRequireScript;
export 'src/plugin_manager.dart';
export 'src/plugin_runtime.dart';
export 'src/protocol.dart';
export 'src/transport.dart';
export 'src/typings.dart';
export 'src/ui_tree.dart';
export 'src/watcher.dart';
export 'src/when.dart';
