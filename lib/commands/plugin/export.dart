import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'commands.dart';
import 'package_io.dart';

const _category = 'Extensions';

class PluginsExportCommand extends FanCadCommand {
  PluginsExportCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.export';
  @override
  String get title => 'Export Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Writes an extension folder to a .fancadplugin package.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      required: false,
      description: 'Destination .fancadplugin path. Defaults to next to the folder.',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', context.l10n.prompt_extension_id);
    final handle = plugins.manager.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final directory = handle.manifest.directory;
    if (directory.isEmpty || !Directory(directory).existsSync()) {
      return CommandResult.failed('$id has no folder to export');
    }
    final requested = context.args['path'];
    final destination = requested is String && requested.trim().isNotEmpty
        ? requested.trim()
        : p.join(p.dirname(directory), '$id.fancadplugin');
    try {
      await zipPlugin(Directory(directory), File(destination));
    } on Object catch (error) {
      return CommandResult.failed('$error');
    }
    return CommandResult.ok(
      message: 'Exported $id',
      data: {'id': id, 'path': destination},
    );
  }
}
