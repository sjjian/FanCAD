import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';
import 'helpers.dart';

const _category = 'Extensions';

class PluginsReadCommand extends FanCadCommand {
  PluginsReadCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.read';
  @override
  String get title => 'Read Extension File';
  @override
  String get category => _category;
  @override
  String get description => 'Reads one file from an extension folder.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
    ParamSpec(name: 'path', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = plugins.host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final directory = handle.manifest.directory;
    if (directory.isEmpty) {
      return CommandResult.failed('$id has no folder on disk');
    }
    final relative = await context.resolveText('path', 'File to read:');
    final file = resolveInside(directory, relative);
    if (file == null) {
      return CommandResult.failed(
        'Refusing to read outside the extension folder: "$relative"',
      );
    }
    if (!file.existsSync()) {
      return CommandResult.failed('No such file: ${file.path}');
    }
    final content = await file.readAsString();
    return CommandResult.ok(
      message: '${content.length} characters',
      data: {'path': file.path, 'content': content},
    );
  }
}
