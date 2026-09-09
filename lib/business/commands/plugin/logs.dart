import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsLogsCommand extends FanCadCommand {
  PluginsLogsCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.logs';
  @override
  String get title => 'Show Extension Log';
  @override
  String get category => _category;
  @override
  String get description =>
      'Prints what an extension logged, for diagnosing a failure.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = plugins.host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    if (handle.log.isEmpty) {
      context.input.write('$id has logged nothing.');
    }
    for (final line in handle.log) {
      context.input.write(line);
    }
    return CommandResult.ok(
      message: '${handle.log.length} line(s)',
      data: {'id': id, 'log': handle.log},
    );
  }
}
