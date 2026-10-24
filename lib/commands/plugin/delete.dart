import 'dart:io';

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsDeleteCommand extends FanCadCommand {
  PluginsDeleteCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.delete';
  @override
  String get title => 'Delete Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Unloads an extension, drops its contributions, and deletes its folder.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', context.l10n.prompt_extension_id);
    final handle = plugins.manager.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final directory = handle.manifest.directory;
    await plugins.manager.uninstall(id);
    if (directory.isNotEmpty) {
      final folder = Directory(directory);
      if (folder.existsSync()) await folder.delete(recursive: true);
    }
    return CommandResult.ok(message: 'Deleted $id', data: {'id': id});
  }
}
