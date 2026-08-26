import 'package:fancad_plugin_host/fancad_plugin_host.dart';

/// FanCAD's `fancad.*` host-call implementation.
///
/// [PluginHost] accepts this factory so the product-named bridge is wired
/// here instead of being hard-coded inside `fancad_plugin_host`.
HostCallHandler createFanCadHostCall({
  required PluginHostDelegate delegate,
  required PluginManifest? Function(String pluginId) manifests,
}) {
  return HostBridge(delegate: delegate, manifests: manifests).call;
}
