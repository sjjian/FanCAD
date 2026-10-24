import 'package:fancad_core/fancad_core.dart';

import 'clipboard/commands.dart';
import 'draw/commands.dart';
import 'edit/commands.dart';
import 'file/commands.dart';
import 'pro/commands.dart';
import 'query/commands.dart';
import 'view/commands.dart';

/// Registers the built-in command set.
///
/// Built-ins go through the same registry, the same parameter schemas and the
/// same disposal scope as saved extensions. The AI sees `draw.line` and
/// `extension.rings` as equally callable tools, and there is no privileged
/// path a built-in could take that an extension could not.
Disposable registerBuiltinCommands(
  CommandRegistry registry, {
  required FileCommands fileCommands,
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
  ]) {
    scope.add(registry.register(descriptor));
  }
  return scope;
}
