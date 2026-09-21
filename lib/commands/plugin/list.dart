import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsListCommand extends FanCadCommand {
  PluginsListCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.list';
  @override
  String get title => 'List Extensions';
  @override
  String get category => _category;
  @override
  String get description =>
      'Lists installed extensions with their state, version and the '
      'commands they contribute.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;

  @override
  Future<CommandResult> run(CommandContext context) async {
    final plugins = this.plugins.host.plugins;
    if (plugins.isEmpty) {
      context.input.write('No extensions are installed.');
      return const CommandResult.ok(
        message: 'No extensions installed',
        data: {'plugins': []},
      );
    }
    for (final handle in plugins) {
      context.input.write(
        '${handle.id}  ${handle.manifest.version}  ${handle.state.name}'
        '${handle.error == null ? '' : '  — ${handle.error}'}',
      );
    }
    return CommandResult.ok(
      message: '${plugins.length} extension(s)',
      data: {
        'plugins': [for (final handle in plugins) handle.toJson()],
      },
    );
  }
}
