import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';

import 'delete.dart';
import 'edit.dart';
import 'enable.dart';
import 'eval.dart';
import 'export.dart';
import 'import.dart';
import 'lifecycle.dart';
import 'list.dart';
import 'logs.dart';
import 'read.dart';
import 'reload.dart';
import 'sandbox.dart';
import 'scaffold.dart';
import 'typings.dart';
import 'write.dart';

/// Commands for managing extensions.
///
/// These are the seam the AI authoring loop needs: `plugins.scaffold`,
/// `plugins.write` and `plugins.reload` are the three steps of "write a plugin
/// and run it", exposed the same way to a person and to a model.
class PluginCommands {
  PluginCommands({
    required this.manager,
    required this.pluginsDirectory,
    this.scratch,
    this.openEditor,
  });

  final PluginManager manager;

  /// One-shot sandbox. Null only in tests that construct commands by hand
  /// and never call `sandbox.query` or `sandbox.run`.
  ///
  /// [write] selects `sandbox.run`. A read-only call is `sandbox.query`.
  final Future<CommandResult> Function(String source, {required bool write})?
  scratch;

  /// Where user extensions live.
  final String pluginsDirectory;

  /// Opens a file in the built-in editor. Null in headless runs that have no
  /// editor.
  final void Function(String id, String relative)? openEditor;

  List<CommandDescriptor> descriptors() => [
    PluginsListCommand(this).toDescriptor(),
    PluginsReloadCommand(this).toDescriptor(),
    PluginsEnableCommand(this).toDescriptor(),
    PluginsDisableCommand(this).toDescriptor(),
    PluginsLogsCommand(this).toDescriptor(),
    PluginsScaffoldCommand(this).toDescriptor(),
    PluginsWriteCommand(this).toDescriptor(),
    PluginsReadCommand(this).toDescriptor(),
    PluginsTypingsCommand(this).toDescriptor(),
    PluginsEditCommand(this).toDescriptor(),
    PluginsEvalCommand(this).toDescriptor(),
    PluginsImportCommand(this).toDescriptor(),
    PluginsExportCommand(this).toDescriptor(),
    PluginsDeleteCommand(this).toDescriptor(),
    PluginsStartCommand(this).toDescriptor(),
    PluginsStopCommand(this).toDescriptor(),
    SandboxQueryCommand(this).toDescriptor(),
    SandboxRunCommand(this).toDescriptor(),
  ];
}
