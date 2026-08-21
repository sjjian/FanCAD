/// The FanCAD extension host.
///
/// Plugins are JavaScript, run in per-plugin QuickJS runtimes on a dedicated
/// isolate, and reach the application only through a JSON-RPC surface that
/// mirrors the `fancad.*` API. Contributions are declared in a manifest and
/// registered before any plugin code runs, so the palette, the command line and
/// the AI tool list are complete from the first frame while third-party code
/// stays off the startup path.
library;

export 'src/bootstrap.dart' show BootstrapGlobals, buildBootstrapScript;
export 'src/contributions.dart';
export 'src/host_bridge.dart';
export 'src/js_engine.dart';
export 'src/manifest.dart';
export 'src/plugin_host.dart';
export 'src/plugin_runtime.dart';
export 'src/protocol.dart';
export 'src/quickjs_engine.dart';
export 'src/transport.dart';
export 'src/typings.dart';
export 'src/watcher.dart';
