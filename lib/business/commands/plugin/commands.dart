import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';

import 'edit.dart';
import 'enable.dart';
import 'eval.dart';
import 'list.dart';
import 'logs.dart';
import 'read.dart';
import 'reload.dart';
import 'scaffold.dart';
import 'typings.dart';
import 'write.dart';

/// Commands for managing extensions.
///
/// These are the seam the AI authoring loop needs: `plugins.scaffold`,
/// `plugins.write` and `plugins.reload` are the three steps of "write a plugin
/// and run it", exposed the same way to a person and to a model.
class PluginCommands {
  PluginCommands({required this.host, required this.pluginsDirectory});

  final PluginHost host;

  /// Where user extensions live.
  final String pluginsDirectory;

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
  ];
}
