import 'package:fancad_core/fancad_core.dart';

import 'clipboard_commands.dart';
import 'draw_commands.dart';
import 'edit_commands.dart';
import 'file_commands.dart';
import 'plugin_commands.dart';
import 'pro_commands.dart';
import 'query_commands.dart';
import 'view_commands.dart';

/// Registers the built-in command set.
///
/// Built-ins go through the same registry, the same parameter schemas and the
/// same disposal scope as plugin commands. That is deliberate and load-bearing:
/// it means a plugin can shadow LINE, the AI sees `draw.line` and a plugin's
/// `acme.wall` as equally callable tools, and there is no privileged path a
/// built-in could take that a plugin could not.
Disposable registerBuiltinCommands(
  CommandRegistry registry, {
  required FileCommands fileCommands,
  PluginCommands? pluginCommands,
  DrawingClipboard? clipboard,
}) {
  final scope = DisposableBag(debugLabel: 'builtin-commands');
  for (final descriptor in [
    ...fileCommands.all(),
    ...DrawCommands.all(),
    ...EditCommands.all(),
    ...ClipboardCommands(store: clipboard ?? DrawingClipboard()).all(),
    ...ViewCommands.all(),
    ...QueryCommands.all(),
    ...ProCommands.all(),
    ...?pluginCommands?.descriptors(),
  ]) {
    scope.add(registry.register(descriptor));
  }
  return scope;
}
